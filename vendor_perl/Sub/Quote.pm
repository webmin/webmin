package Sub::Quote;

sub _clean_eval { eval $_[0] }

use strict;
use warnings;

use Sub::Defer qw(defer_sub);
use Scalar::Util qw(weaken);
use Exporter qw(import);
use Carp qw(croak);
BEGIN { our @CARP_NOT = qw(Sub::Defer) }
use B ();
BEGIN {
  *_HAVE_IS_UTF8 = defined &utf8::is_utf8 ? sub(){1} : sub(){0};
  *_HAVE_PERLSTRING = defined &B::perlstring ? sub(){1} : sub(){0};
  *_BAD_BACKSLASH_ESCAPE = _HAVE_PERLSTRING() && "$]" == 5.010_000 ? sub(){1} : sub(){0};
  *_HAVE_HEX_FLOAT = !$ENV{SUB_QUOTE_NO_HEX_FLOAT} && "$]" >= 5.022 ? sub(){1} : sub(){0};

  # This may not be perfect, as we can't tell the format purely from the size
  # but it should cover the common cases, and other formats are more likely to
  # be less precise.
  my $nvsize = 8 * length pack 'F', 0;
  my $nvmantbits
    = $nvsize == 16   ? 11
    : $nvsize == 32   ? 24
    : $nvsize == 64   ? 53
    : $nvsize == 80   ? 64
    : $nvsize == 128  ? 113
    : $nvsize == 256  ? 237
                      : 237 # unknown float format
    ;
  my $precision = int( log(2)/log(10)*$nvmantbits );

  *_NVSIZE = sub(){$nvsize};
  *_NVMANTBITS = sub(){$nvmantbits};
  *_FLOAT_PRECISION = sub(){$precision};
}

our $VERSION = '2.006006';
$VERSION =~ tr/_//d;

our @EXPORT = qw(quote_sub unquote_sub quoted_from_sub qsub);
our @EXPORT_OK = qw(quotify capture_unroll inlinify sanitize_identifier);

our %QUOTED;

my %escape;
if (_BAD_BACKSLASH_ESCAPE) {
  %escape = (
    (map +(chr($_) => sprintf '\x%02x', $_), 0 .. 0x31, 0x7f),
    "\t" => "\\t",
    "\n" => "\\n",
    "\r" => "\\r",
    "\f" => "\\f",
    "\b" => "\\b",
    "\a" => "\\a",
    "\e" => "\\e",
    (map +($_ => "\\$_"), qw(" \ $ @)),
  );
}

sub quotify {
  my $value = $_[0];
  no warnings 'numeric';
  ! defined $value     ? 'undef()'
  # numeric detection
  : (!(_HAVE_IS_UTF8 && utf8::is_utf8($value))
    && length( (my $dummy = '') & $value )
    && 0 + $value eq $value
  ) ? (
    $value != $value ? (
      $value eq (9**9**9*0)
        ? '(9**9**9*0)'    # nan
        : '(-(9**9**9*0))' # -nan
    )
    : $value == 9**9**9  ? '(9**9**9)'     # inf
    : $value == -9**9**9 ? '(-9**9**9)'    # -inf
    : $value == 0 ? (
      sprintf('%g', $value) eq '-0' ? '-0.0' : '0',
    )
    : $value !~ /[e.]/i ? (
      $value > 0 ? (sprintf '%u', $value)
                 : (sprintf '%d', $value)
    )
    : do {
      my $float = $value;
      my $max_factor = int( log( abs($value) ) / log(2) ) - _NVMANTBITS;
      my $ex_sign = $max_factor > 0 ? 1 : -1;
      FACTOR: for my $ex (0 .. abs($max_factor)) {
        my $num = $value / 2**($ex_sign * $ex);
        for my $precision (_FLOAT_PRECISION .. _FLOAT_PRECISION+2) {
          my $formatted = sprintf '%.'.$precision.'g', $num;
          $float = $formatted
            if $ex == 0;
          if ($formatted == $num) {
            if ($ex) {
              $float
                = $formatted
                . ($ex_sign == 1 ? '*' : '/')
                . (
                  $ex > _NVMANTBITS
                    ? "2**$ex"
                    : sprintf('%u', 2**$ex)
                );
            }
            last FACTOR;
          }
        }
        if (_HAVE_HEX_FLOAT) {
          $float = sprintf '%a', $value;
          last FACTOR;
        }
      }
      "$float";
    }
  )
  : !length($value) && length( (my $dummy2 = '') & $value ) ? '(!1)' # false
  : _BAD_BACKSLASH_ESCAPE && _HAVE_IS_UTF8 && utf8::is_utf8($value) ? do {
    $value =~ s/(["\$\@\\[:cntrl:]]|[^\x00-\x7f])/
      $escape{$1} || sprintf('\x{%x}', ord($1))
    /ge;
    qq["$value"];
  }
  : _HAVE_PERLSTRING ? B::perlstring($value)
  : qq["\Q$value\E"];
}

sub sanitize_identifier {
  my $name = shift;
  $name =~ s/([_\W])/sprintf('_%x', ord($1))/ge;
  $name;
}

sub capture_unroll {
  my ($from, $captures, $indent) = @_;
  join(
    '',
    map {
      /^([\@\%\$])/
        or croak "capture key should start with \@, \% or \$: $_";
      (' ' x $indent).qq{my ${_} = ${1}{${from}->{${\quotify $_}}};\n};
    } keys %$captures
  );
}

sub inlinify {
  my ($code, $args, $extra, $local) = @_;
  $args = '()'
    if !defined $args;
  my $do = 'do { '.($extra||'');
  if ($code =~ s/^(\s*package\s+([a-zA-Z0-9:]+);)//) {
    $do .= $1;
  }
  if ($code =~ s{
    \A((?:\#\ BEGIN\ quote_sub\ PRELUDE\n.*?\#\ END\ quote_sub\ PRELUDE\n)?\s*)
    (^\s*) my \s* \(([^)]+)\) \s* = \s* \@_;
  }{}xms) {
    my ($pre, $indent, $code_args) = ($1, $2, $3);
    $do .= $pre;
    if ($code_args ne $args) {
      $do .= $indent . 'my ('.$code_args.') = ('.$args.'); ';
    }
  }
  elsif ($local || $args ne '@_') {
    $do .= ($local ? 'local ' : '').'@_ = ('.$args.'); ';
  }
  $do.$code.' }';
}

sub quote_sub {
  # HOLY DWIMMERY, BATMAN!
  # $name => $code => \%captures => \%options
  # $name => $code => \%captures
  # $name => $code
  # $code => \%captures => \%options
  # $code
  my $options =
    (ref($_[-1]) eq 'HASH' and ref($_[-2]) eq 'HASH')
      ? pop
      : {};
  my $captures = ref($_[-1]) eq 'HASH' ? pop : undef;
  undef($captures) if $captures && !keys %$captures;
  my $code = pop;
  my $name = $_[0];
  if ($name) {
    my $subname = $name;
    my $package = $subname =~ s/(.*)::// ? $1 : caller;
    $name = join '::', $package, $subname;
    croak qq{package name "$package" too long!}
      if length $package > 252;
    croak qq{package name "$package" is not valid!}
      unless $package =~ /^[^\d\W]\w*(?:::\w+)*$/;
    croak qq{sub name "$subname" too long!}
      if length $subname > 252;
    croak qq{sub name "$subname" is not valid!}
      unless $subname =~ /^[^\d\W]\w*$/;
  }
  my @caller = caller(0);
  my ($attributes, $file, $line) = @{$options}{qw(attributes file line)};
  if ($attributes) {
    /\A\w+(?:\(.*\))?\z/s || croak "invalid attribute $_"
      for @$attributes;
  }
  my $quoted_info = {
    name     => $name,
    code     => $code,
    captures => $captures,
    package      => (exists $options->{package}      ? $options->{package}      : $caller[0]),
    hints        => (exists $options->{hints}        ? $options->{hints}        : $caller[8]),
    warning_bits => (exists $options->{warning_bits} ? $options->{warning_bits} : $caller[9]),
    hintshash    => (exists $options->{hintshash}    ? $options->{hintshash}    : $caller[10]),
    ($attributes ? (attributes => $attributes) : ()),
    ($file       ? (file => $file) : ()),
    ($line       ? (line => $line) : ()),
  };
  my $unquoted;
  weaken($quoted_info->{unquoted} = \$unquoted);
  if ($options->{no_defer}) {
    my $fake = \my $var;
    local $QUOTED{$fake} = $quoted_info;
    my $sub = unquote_sub($fake);
    Sub::Defer::_install_coderef($name, $sub) if $name && !$options->{no_install};
    return $sub;
  }
  else {
    my $deferred = defer_sub(
      ($options->{no_install} ? undef : $name),
      sub {
        $unquoted if 0;
        unquote_sub($quoted_info->{deferred});
      },
      {
        ($attributes ? ( attributes => $attributes ) : ()),
        ($name ? () : ( package => $quoted_info->{package} )),
      },
    );
    weaken($quoted_info->{deferred} = $deferred);
    weaken($QUOTED{$deferred} = $quoted_info);
    return $deferred;
  }
}

sub _context {
  my $info = shift;
  $info->{context} ||= do {
    my ($package, $hints, $warning_bits, $hintshash, $file, $line)
      = @{$info}{qw(package hints warning_bits hintshash file line)};

    $line ||= 1
      if $file;

    my $line_mark = '';
    if ($line) {
      $line_mark = "#line ".($line-1);
      if ($file) {
        $line_mark .= qq{ "$file"};
      }
      $line_mark .= "\n";
    }

    $info->{context}
      ="# BEGIN quote_sub PRELUDE\n"
      ."package $package;\n"
      ."BEGIN {\n"
      ."  \$^H = ".quotify($hints).";\n"
      ."  \${^WARNING_BITS} = ".quotify($warning_bits).";\n"
      ."  \%^H = (\n"
      . join('', map
      "    ".quotify($_)." => ".quotify($hintshash->{$_}).",\n",
        grep !(ref $hintshash->{$_} && $hintshash->{$_} =~ /\A(?:\w+(?:::\w+)*=)?[A-Z]+\(0x[[0-9a-fA-F]+\)\z/),
        keys %$hintshash)
      ."  );\n"
      ."}\n"
      .$line_mark
      ."# END quote_sub PRELUDE\n";
  };
}

sub quoted_from_sub {
  my ($sub) = @_;
  my $quoted_info = $QUOTED{$sub||''} or return undef;
  my ($name, $code, $captures, $unquoted, $deferred)
    = @{$quoted_info}{qw(name code captures unquoted deferred)};
  $code = _context($quoted_info) . $code;
  $unquoted &&= $$unquoted;
  if (($deferred && $deferred eq $sub)
      || ($unquoted && $unquoted eq $sub)) {
    return [ $name, $code, $captures, $unquoted, $deferred ];
  }
  return undef;
}

sub unquote_sub {
  my ($sub) = @_;
  my $quoted_info = $QUOTED{$sub} or return undef;
  my $unquoted = $quoted_info->{unquoted};
  unless ($unquoted && $$unquoted) {
    my ($name, $code, $captures, $package, $attributes)
      = @{$quoted_info}{qw(name code captures package attributes)};

    ($package, $name) = $name =~ /(.*)::(.*)/
      if $name;

    my %captures = $captures ? %$captures : ();
    $captures{'$_UNQUOTED'} = \$unquoted;
    $captures{'$_QUOTED'} = \$quoted_info;

    my $make_sub
      = "{\n"
      . capture_unroll("\$_[1]", \%captures, 2)
      . "  package ${package};\n"
      . (
        $name
          # disable the 'variable $x will not stay shared' warning since
          # we're not letting it escape from this scope anyway so there's
          # nothing trying to share it
          ? "  no warnings 'closure';\n  sub ${name} "
          : "  \$\$_UNQUOTED = sub "
      )
      . ($attributes ? join('', map ":$_ ", @$attributes) : '') . "{\n"
      . "  (\$_QUOTED,\$_UNQUOTED) if 0;\n"
      . _context($quoted_info)
      . $code
      . "  }".($name ? "\n  \$\$_UNQUOTED = \\&${name}" : '') . ";\n"
      . "}\n"
      . "1;\n";
    if (my $debug = $ENV{SUB_QUOTE_DEBUG}) {
      if ($debug =~ m{^([^\W\d]\w*(?:::\w+)*(?:::)?)$}) {
        my $filter = $1;
        my $match
          = $filter =~ /::$/ ? $package.'::'
          : $filter =~ /::/  ? $package.'::'.($name||'__ANON__')
          : ($name||'__ANON__');
        warn $make_sub
          if $match eq $filter;
      }
      elsif ($debug =~ m{\A/(.*)/\z}s) {
        my $filter = $1;
        warn $make_sub
          if $code =~ $filter;
      }
      else {
        warn $make_sub;
      }
    }
    {
      no strict 'refs';
      local *{"${package}::${name}"} if $name;
      my ($success, $e);
      {
        local $@;
        $success = _clean_eval($make_sub, \%captures);
        $e = $@;
      }
      unless ($success) {
        my $space = length($make_sub =~ tr/\n//);
        my $line = 0;
        $make_sub =~ s/^/sprintf "%${space}d: ", ++$line/emg;
        croak "Eval went very, very wrong:\n\n${make_sub}\n\n$e";
      }
      weaken($QUOTED{$$unquoted} = $quoted_info);
    }
  }
  $$unquoted;
}

sub qsub ($) {
  goto &quote_sub;
}

sub CLONE {
  my @quoted = map { defined $_ ? (
    $_->{unquoted} && ${$_->{unquoted}} ? (${ $_->{unquoted} } => $_) : (),
    $_->{deferred} ? ($_->{deferred} => $_) : (),
  ) : () } values %QUOTED;
  %QUOTED = @quoted;
  weaken($_) for values %QUOTED;
}

1;
__END__

=encoding utf-8

=head1 NAME

Sub::Quote - Efficient generation of subroutines via string eval

=head1 SYNOPSIS

 package Silly;

 use Sub::Quote qw(quote_sub unquote_sub quoted_from_sub);

 quote_sub 'Silly::kitty', q{ print "meow" };

 quote_sub 'Silly::doggy', q{ print "woof" };

 my $sound = 0;

 quote_sub 'Silly::dagron',
   q{ print ++$sound % 2 ? 'burninate' : 'roar' },
   { '$sound' => \$sound };

And elsewhere:

 Silly->kitty;  # meow
 Silly->doggy;  # woof
 Silly->dagron; # burninate
 Silly->dagron; # roar
 Silly->dagron; # burninate

=head1 DESCRIPTION

This package provides performant ways to generate subroutines from strings.

=head1 SUBROUTINES

=head2 quote_sub

 my $coderef = quote_sub 'Foo::bar', q{ print $x++ . "\n" }, { '$x' => \0 };

Arguments: ?$name, $code, ?\%captures, ?\%options

C<$name> is the subroutine where the coderef will be installed.

C<$code> is a string that will be turned into code.

C<\%captures> is a hashref of variables that will be made available to the
code.  The keys should be the full name of the variable to be made available,
including the sigil.  The values should be references to the values.  The
variables will contain copies of the values.  See the L</SYNOPSIS>'s
C<Silly::dagron> for an example using captures.

Exported by default.

=head3 options

=over 2

=item C<no_install>

B<Boolean>.  Set this option to not install the generated coderef into the
passed subroutine name on undefer.

=item C<no_defer>

B<Boolean>.  Prevents a Sub::Defer wrapper from being generated for the quoted
sub.  If the sub will most likely be called at some point, setting this is a
good idea.  For a sub that will most likely be inlined, it is not recommended.

=item C<package>

The package that the quoted sub will be evaluated in.  If not specified, the
package from sub calling C<quote_sub> will be used.

=item C<hints>

The value of L<< C<$^H> | perlvar/$^H >> to use for the code being evaluated.
This captures the settings of the L<strict> pragma.  If not specified, the value
from the calling code will be used.

=item C<warning_bits>

The value of L<< C<${^WARNING_BITS}> | perlvar/${^WARNING_BITS} >> to use for
the code being evaluated.  This captures the L<warnings> set.  If not specified,
the warnings from the calling code will be used.

=item C<%^H>

The value of L<< C<%^H> | perlvar/%^H >> to use for the code being evaluated.
This captures additional pragma settings.  If not specified, the value from the
calling code will be used if possible (on perl 5.10+).

=item C<attributes>

The L<perlsub/Subroutine Attributes> to apply to the sub generated.  Should be
specified as an array reference.  The attributes will be applied to both the
generated sub and the deferred wrapper, if one is used.

=item C<file>

The apparent filename to use for the code being evaluated.

=item C<line>

The apparent line number
to use for the code being evaluated.

=back

=head2 unquote_sub

 my $coderef = unquote_sub $sub;

Forcibly replace subroutine with actual code.

If $sub is not a quoted sub, this is a no-op.

Exported by default.

=head2 quoted_from_sub

 my $data = quoted_from_sub $sub;

 my ($name, $code, $captures, $compiled_sub) = @$data;

Returns original arguments to quote_sub, plus the compiled version if this
sub has already been unquoted.

Note that $sub can be either the original quoted version or the compiled
version for convenience.

Exported by default.

=head2 inlinify

 my $prelude = capture_unroll '$captures', {
   '$x' => 1,
   '$y' => 2,
 }, 4;

 my $inlined_code = inlinify q{
   my ($x, $y) = @_;

   print $x + $y . "\n";
 }, '$x, $y', $prelude;

Takes a string of code, a string of arguments, a string of code which acts as a
"prelude", and a B<Boolean> representing whether or not to localize the
arguments.

=head2 quotify

 my $quoted_value = quotify $value;

Quotes a single (non-reference) scalar value for use in a code string.  The
result should reproduce the original value, including strings, undef, integers,
and floating point numbers.  The resulting floating point numbers (including
infinites and not a number) should be precisely equal to the original, if
possible.  The exact format of the resulting number should not be relied on, as
it may include hex floats or math expressions.

=head2 capture_unroll

 my $prelude = capture_unroll '$captures', {
   '$x' => 1,
   '$y' => 2,
 }, 4;

Arguments: $from, \%captures, $indent

Generates a snippet of code which is suitable to be used as a prelude for
L</inlinify>.  C<$from> is a string will be used as a hashref in the resulting
code.  The keys of C<%captures> are the names of the variables and the values
are ignored.  C<$indent> is the number of spaces to indent the result by.

=head2 qsub

 my $hash = {
  coderef => qsub q{ print "hello"; },
  other   => 5,
 };

Arguments: $code

Works exactly like L</quote_sub>, but includes a prototype to only accept a
single parameter.  This makes it easier to include in hash structures or lists.

Exported by default.

=head2 sanitize_identifier

 my $var_name = '$variable_for_' . sanitize_identifier('@name');
 quote_sub qq{ print \$${var_name} }, { $var_name => \$value };

Arguments: $identifier

Sanitizes a value so that it can be used in an identifier.

=head1 ENVIRONMENT

=head2 SUB_QUOTE_DEBUG

Causes code to be output to C<STDERR> before being evaled.  Several forms are
supported:

=over 4

=item C<1>

All subs will be output.

=item C</foo/>

Subs will be output if their code matches the given regular expression.

=item C<simple_identifier>

Any sub with the given name will be output.

=item C<Full::identifier>

A sub matching the full name will be output.

=item C<Package::Name::>

Any sub in the given package (including anonymous subs) will be output.

=back

=head1 CAVEATS

Much of this is just string-based code-generation, and as a result, a few
caveats apply.

=head2 return

Calling C<return> from a quote_sub'ed sub will not likely do what you intend.
Instead of returning from the code you defined in C<quote_sub>, it will return
from the overall function it is composited into.

So when you pass in:

   quote_sub q{  return 1 if $condition; $morecode }

It might turn up in the intended context as follows:

  sub foo {

    <important code a>
    do {
      return 1 if $condition;
      $morecode
    };
    <important code b>

  }

Which will obviously return from foo, when all you meant to do was return from
the code context in quote_sub and proceed with running important code b.

=head2 pragmas

C<Sub::Quote> preserves the environment of the code creating the
quoted subs.  This includes the package, strict, warnings, and any
other lexical pragmas.  This is done by prefixing the code with a
block that sets up a matching environment.  When inlining C<Sub::Quote>
subs, care should be taken that user pragmas won't effect the rest
of the code.

=head1 SUPPORT

Users' IRC: #moose on irc.perl.org

=for :html
L<(click for instant chatroom login)|http://chat.mibbit.com/#moose@irc.perl.org>

Development and contribution IRC: #web-simple on irc.perl.org

=for :html
L<(click for instant chatroom login)|http://chat.mibbit.com/#web-simple@irc.perl.org>

Bugtracker: L<https://rt.cpan.org/Public/Dist/Display.html?Name=Sub-Quote>

Git repository: L<git://github.com/moose/Sub-Quote.git>

Git browser: L<https://github.com/moose/Sub-Quote>

=head1 AUTHOR

mst - Matt S. Trout (cpan:MSTROUT) <mst@shadowcat.co.uk>

=head1 CONTRIBUTORS

frew - Arthur Axel "fREW" Schmidt (cpan:FREW) <frioux@gmail.com>

ribasushi - Peter Rabbitson (cpan:RIBASUSHI) <ribasushi@cpan.org>

Mithaldu - Christian Walde (cpan:MITHALDU) <walde.christian@googlemail.com>

tobyink - Toby Inkster (cpan:TOBYINK) <tobyink@cpan.org>

haarg - Graham Knop (cpan:HAARG) <haarg@cpan.org>

bluefeet - Aran Deltac (cpan:BLUEFEET) <bluefeet@gmail.com>

ether - Karen Etheridge (cpan:ETHER) <ether@cpan.org>

dolmen - Olivier Mengué (cpan:DOLMEN) <dolmen@cpan.org>

alexbio - Alessandro Ghedini (cpan:ALEXBIO) <alexbio@cpan.org>

getty - Torsten Raudssus (cpan:GETTY) <torsten@raudss.us>

arcanez - Justin Hunter (cpan:ARCANEZ) <justin.d.hunter@gmail.com>

kanashiro - Lucas Kanashiro (cpan:KANASHIRO) <kanashiro.duarte@gmail.com>

djerius - Diab Jerius (cpan:DJERIUS) <djerius@cfa.harvard.edu>

=head1 COPYRIGHT

Copyright (c) 2010-2016 the Sub::Quote L</AUTHOR> and L</CONTRIBUTORS>
as listed above.

=head1 LICENSE

This library is free software and may be distributed under the same terms
as perl itself. See L<http://dev.perl.org/licenses/>.

=cut
