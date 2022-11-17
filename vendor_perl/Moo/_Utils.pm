package Moo::_Utils;
use strict;
use warnings;

{
  no strict 'refs';
  no warnings 'once';
  sub _getglob { \*{$_[0]} }
  sub _getstash { \%{"$_[0]::"} }
}

BEGIN {
  my ($su, $sn);
  $su = $INC{'Sub/Util.pm'} && defined &Sub::Util::set_subname
    or $sn = $INC{'Sub/Name.pm'}
    or $su = eval { require Sub::Util; } && defined &Sub::Util::set_subname
    or $sn = eval { require Sub::Name; };

  *_subname = $su ? \&Sub::Util::set_subname
            : $sn ? \&Sub::Name::subname
            : sub { $_[1] };
  *_CAN_SUBNAME = ($su || $sn) ? sub(){1} : sub(){0};

  *_WORK_AROUND_BROKEN_MODULE_STATE = "$]" < 5.009 ? sub(){1} : sub(){0};
  *_WORK_AROUND_HINT_LEAKAGE
    = "$]" < 5.011 && !("$]" >= 5.009004 && "$]" < 5.010001)
      ? sub(){1} : sub(){0};

  my $module_name_rx = qr/\A(?!\d)\w+(?:::\w+)*\z/;
  *_module_name_rx = sub(){$module_name_rx};
}

use Exporter ();
BEGIN { *import = \&Exporter::import }
use Config ();
use Scalar::Util qw(weaken);
use Carp qw(croak);

# this should be empty, but some CPAN modules expect these
our @EXPORT = qw(
  _install_coderef
  _load_module
);

our @EXPORT_OK = qw(
  _check_tracked
  _getglob
  _getstash
  _install_coderef
  _install_modifier
  _install_tracked
  _load_module
  _maybe_load_module
  _module_name_rx
  _name_coderef
  _set_loaded
  _unimport_coderefs
  _linear_isa
  _in_global_destruction
  _in_global_destruction_code
);

my %EXPORTS;

sub _install_modifier {
  my $target = $_[0];
  my $type = $_[1];
  my $code = $_[-1];
  my @names = @_[2 .. $#_ - 1];

  @names = @{ $names[0] }
    if ref($names[0]) eq 'ARRAY';

  my @tracked = _check_tracked($target, \@names);

  if ($INC{'Sub/Defer.pm'}) {
    for my $name (@names) {
      # CMM will throw for us if it doesn't exist
      if (my $to_modify = $target->can($name)) {
        Sub::Defer::undefer_sub($to_modify);
      }
    }
  }

  require Class::Method::Modifiers;
  Class::Method::Modifiers::install_modifier(@_);

  if (@tracked) {
    my $exports = $EXPORTS{$target};
    weaken($exports->{$_} = $target->can($_))
      for @tracked;
  }

  return;
}

sub _install_tracked {
  my ($target, $name, $code) = @_;
  my $from = caller;
  weaken($EXPORTS{$target}{$name} = $code);
  _install_coderef("${target}::${name}", "${from}::${name}", $code);
}

sub Moo::_Util::__GUARD__::DESTROY {
  delete $INC{$_[0]->[0]} if @{$_[0]};
}

sub _require {
  my ($file) = @_;
  my $guard = _WORK_AROUND_BROKEN_MODULE_STATE
    && bless([ $file ], 'Moo::_Util::__GUARD__');
  local %^H if _WORK_AROUND_HINT_LEAKAGE;
  if (!eval { require $file; 1 }) {
    my $e = $@ || "Can't locate $file";
    my $me = __FILE__;
    $e =~ s{ at \Q$me\E line \d+\.\n\z}{};
    return $e;
  }
  pop @$guard if _WORK_AROUND_BROKEN_MODULE_STATE;
  return undef;
}

sub _load_module {
  my ($module) = @_;
  croak qq{"$module" is not a module name!}
    unless $module =~ _module_name_rx;
  (my $file = "$module.pm") =~ s{::}{/}g;
  return 1
    if $INC{$file};

  my $e = _require $file;
  return 1
    if !defined $e;

  croak $e
    if $e !~ /\ACan't locate \Q$file\E /;

  # can't just ->can('can') because a sub-package Foo::Bar::Baz
  # creates a 'Baz::' key in Foo::Bar's symbol table
  my $stash = _getstash($module)||{};
  no strict 'refs';
  return 1 if grep +exists &{"${module}::$_"}, grep !/::\z/, keys %$stash;
  return 1
    if $INC{"Moose.pm"} && Class::MOP::class_of($module)
    or Mouse::Util->can('find_meta') && Mouse::Util::find_meta($module);

  croak $e;
}

our %MAYBE_LOADED;
sub _maybe_load_module {
  my $module = $_[0];
  return $MAYBE_LOADED{$module}
    if exists $MAYBE_LOADED{$module};
  (my $file = "$module.pm") =~ s{::}{/}g;

  my $e = _require $file;
  if (!defined $e) {
    return $MAYBE_LOADED{$module} = 1;
  }
  elsif ($e !~ /\ACan't locate \Q$file\E /) {
    warn "$module exists but failed to load with error: $e";
  }
  return $MAYBE_LOADED{$module} = 0;
}

BEGIN {
  # optimize for newer perls
  require mro
    if "$]" >= 5.009_005;

  if (defined &mro::get_linear_isa) {
    *_linear_isa = \&mro::get_linear_isa;
  }
  else {
    my $e;
    {
      local $@;
      eval <<'END_CODE' or $e = $@;
sub _linear_isa($;$) {
  my $class = shift;
  my $type = shift || exists $Class::C3::MRO{$class} ? 'c3' : 'dfs';

  if ($type eq 'c3') {
    require Class::C3;
    return [Class::C3::calculateMRO($class)];
  }

  my @check = ($class);
  my @lin;

  my %found;
  while (defined(my $check = shift @check)) {
    push @lin, $check;
    no strict 'refs';
    unshift @check, grep !$found{$_}++, @{"$check\::ISA"};
  }

  return \@lin;
}

1;
END_CODE
    }
    die $e if defined $e;
  }
}

BEGIN {
  my $gd_code
    = "$]" >= 5.014
      ? q[${^GLOBAL_PHASE} eq 'DESTRUCT']
    : _maybe_load_module('Devel::GlobalDestruction::XS')
      ? 'Devel::GlobalDestruction::XS::in_global_destruction()'
      : 'do { use B (); ${B::main_cv()} == 0 }';
  *_in_global_destruction_code = sub () { $gd_code };
  eval "sub _in_global_destruction () { $gd_code }; 1"
    or die $@;
}

sub _set_loaded {
  (my $file = "$_[0].pm") =~ s{::}{/}g;
  $INC{$file} ||= $_[1];
}

sub _install_coderef {
  my ($glob, $code) = (_getglob($_[0]), _name_coderef(@_));
  no warnings 'redefine';
  if (*{$glob}{CODE}) {
    *{$glob} = $code;
  }
  # perl will sometimes warn about mismatched prototypes coming from the
  # inheritance cache, so disable them if we aren't redefining a sub
  else {
    no warnings 'prototype';
    *{$glob} = $code;
  }
}

sub _name_coderef {
  shift if @_ > 2; # three args is (target, name, sub)
  _CAN_SUBNAME ? _subname(@_) : $_[1];
}

sub _check_tracked {
  my ($target, $names) = @_;
  my $stash = _getstash($target);
  my $exports = $EXPORTS{$target}
    or return;

  $names = [keys %$exports]
    if !$names;
  my %rev =
    map +($exports->{$_} => $_),
    grep defined $exports->{$_},
    keys %$exports;

  return
    grep {
      my $g = $stash->{$_};
      $g && defined &$g && exists $rev{\&$g};
    }
    @$names;
}

sub _unimport_coderefs {
  my ($target) = @_;

  my $stash = _getstash($target);
  my @exports = _check_tracked($target);

  foreach my $name (@exports) {
    my $old = delete $stash->{$name};
    my $full_name = join('::',$target,$name);
    # Copy everything except the code slot back into place (e.g. $has)
    foreach my $type (qw(SCALAR HASH ARRAY IO)) {
      next unless defined(*{$old}{$type});
      no strict 'refs';
      *$full_name = *{$old}{$type};
    }
  }
}

if ($Config::Config{useithreads}) {
  require Moo::HandleMoose::_TypeMap;
}

1;
