package Exporter::Tiny;

use 5.006001;
use strict;
use warnings; no warnings qw(void once uninitialized numeric redefine);

our $AUTHORITY = 'cpan:TOBYINK';
our $VERSION   = '1.006002';
our @EXPORT_OK = qw< mkopt mkopt_hash _croak _carp >;

BEGIN {
	*_HAS_NATIVE_LEXICAL_SUB = ( $] ge '5.037002' )
		? sub () { !!1 }
		: sub () { !!0 };
	*_HAS_MODULE_LEXICAL_SUB = ( $] ge '5.011002' and eval('require Lexical::Sub') )
		? sub () { !!1 }
		: sub () { !!0 };
};

sub _croak ($;@) { require Carp; my $fmt = shift; @_ = sprintf($fmt, @_); goto \&Carp::croak }
sub _carp  ($;@) { require Carp; my $fmt = shift; @_ = sprintf($fmt, @_); goto \&Carp::carp }

my $_process_optlist = sub
{
	my $class = shift;
	my ($global_opts, $opts, $want, $not_want) = @_;
	
	while (@$opts)
	{
		my $opt = shift @{$opts};
		my ($name, $value) = @$opt;
		
		($name =~ m{\A\!(/.+/[msixpodual]*)\z}) ?
			do {
				my @not = $class->_exporter_expand_regexp("$1", $value, $global_opts);
				++$not_want->{$_->[0]} for @not;
			} :
		($name =~ m{\A\![:-](.+)\z}) ?
			do {
				my @not = $class->_exporter_expand_tag("$1", $value, $global_opts);
				++$not_want->{$_->[0]} for @not;
			} :
		($name =~ m{\A\!(.+)\z}) ?
			(++$not_want->{$1}) :
		($name =~ m{\A[:-](.+)\z}) ?
			push(@$opts, $class->_exporter_expand_tag("$1", $value, $global_opts)) :
		($name =~ m{\A/.+/[msixpodual]*\z}) ?
			push(@$opts, $class->_exporter_expand_regexp($name, $value, $global_opts)) :
		# else ?
			push(@$want, $opt);
	}
};

sub import
{
	my $class = shift;
	my $global_opts = +{ @_ && ref($_[0]) eq q(HASH) ? %{+shift} : () };
	
	if ( defined $global_opts->{into} and $global_opts->{into} eq '-lexical' ) {
		$global_opts->{lexical} = 1;
		delete $global_opts->{into};
	}
	if ( not defined $global_opts->{into} ) {
		$global_opts->{into} = caller;
	}
	
	my @want;
	my %not_want; $global_opts->{not} = \%not_want;
	my @args = do { no strict qw(refs); @_ ? @_ : @{"$class\::EXPORT"} };
	my $opts = mkopt(\@args);
	$class->$_process_optlist($global_opts, $opts, \@want, \%not_want);
	
	$global_opts->{installer} ||= $class->_exporter_lexical_installer( $global_opts )
		if $global_opts->{lexical};
	
	my $permitted = $class->_exporter_permitted_regexp($global_opts);
	$class->_exporter_validate_opts($global_opts);
	
	for my $wanted (@want) {
		next if $not_want{$wanted->[0]};
		
		my %symbols = $class->_exporter_expand_sub(@$wanted, $global_opts, $permitted);
		$class->_exporter_install_sub($_, $wanted->[1], $global_opts, $symbols{$_})
			for keys %symbols;
	}
}

sub unimport
{
	my $class = shift;
	my $global_opts = +{ @_ && ref($_[0]) eq q(HASH) ? %{+shift} : () };
	$global_opts->{is_unimport} = 1;
	
	if ( defined $global_opts->{into} and $global_opts->{into} eq '-lexical' ) {
		$global_opts->{lexical} = 1;
		delete $global_opts->{into};
	}
	if ( not defined $global_opts->{into} ) {
		$global_opts->{into} = caller;
	}
	
	my @want;
	my %not_want; $global_opts->{not} = \%not_want;
	my @args = do { our %TRACKED; @_ ? @_ : keys(%{$TRACKED{$class}{$global_opts->{into}}}) };
	my $opts = mkopt(\@args);
	$class->$_process_optlist($global_opts, $opts, \@want, \%not_want);
	
	my $permitted = $class->_exporter_permitted_regexp($global_opts);
	$class->_exporter_validate_unimport_opts($global_opts);
	
	my $expando = $class->can('_exporter_expand_sub');
	$expando = undef if $expando == \&_exporter_expand_sub;
	
	for my $wanted (@want)
	{
		next if $not_want{$wanted->[0]};
		
		if ($wanted->[1])
		{
			_carp("Passing options to unimport '%s' makes no sense", $wanted->[0])
				unless (ref($wanted->[1]) eq 'HASH' and not keys %{$wanted->[1]});
		}
		
		my %symbols = defined($expando)
			? $class->$expando(@$wanted, $global_opts, $permitted)
			: ($wanted->[0] => sub { "dummy" });
		$class->_exporter_uninstall_sub($_, $wanted->[1], $global_opts)
			for keys %symbols;
	}
}

# Returns a coderef suitable to be used as a sub installer for lexical imports.
#
sub _exporter_lexical_installer {
	_HAS_NATIVE_LEXICAL_SUB and return sub {
		my ( $sigilname, $sym ) = @{ $_[1] };
		no warnings ( $] ge '5.037002' ? 'experimental::builtin' : () );
		builtin::export_lexically( $sigilname, $sym );
	};
	_HAS_MODULE_LEXICAL_SUB and return sub {
		my ( $sigilname, $sym ) = @{ $_[1] };
		( $sigilname =~ /^\w/ )
			? 'Lexical::Sub'->import( $sigilname, $sym )
			: 'Lexical::Var'->import( $sigilname, $sym );
	};
	_croak( 'Lexical export requires Perl 5.37.2+ for native support, or Perl 5.11.2+ with the Lexical::Sub module' );
}

# Called once per import/unimport, passed the "global" import options.
# Expected to validate the options and carp or croak if there are problems.
# Can also take the opportunity to do other stuff if needed.
#
sub _exporter_validate_opts          { 1 }
sub _exporter_validate_unimport_opts { 1 }

# Called after expanding a tag or regexp to merge the tag's options with
# any sub-specific options.
#
sub _exporter_merge_opts
{
	my $class = shift;
	my ($tag_opts, $global_opts, @stuff) = @_;
	
	$tag_opts = {} unless ref($tag_opts) eq q(HASH);
	_croak('Cannot provide an -as option for tags')
		if exists $tag_opts->{-as} && ref $tag_opts->{-as} ne 'CODE';
	
	my $optlist = mkopt(\@stuff);
	for my $export (@$optlist)
	{
		next if defined($export->[1]) && ref($export->[1]) ne q(HASH);
		
		my %sub_opts = ( %{ $export->[1] or {} }, %$tag_opts );
		$sub_opts{-prefix} = sprintf('%s%s', $tag_opts->{-prefix}, $export->[1]{-prefix})
			if exists($export->[1]{-prefix}) && exists($tag_opts->{-prefix});
		$sub_opts{-suffix} = sprintf('%s%s', $export->[1]{-suffix}, $tag_opts->{-suffix})
			if exists($export->[1]{-suffix}) && exists($tag_opts->{-suffix});
		$export->[1] = \%sub_opts;
	}
	return @$optlist;
}

# Given a tag name, looks it up in %EXPORT_TAGS and returns the list of
# associated functions. The default implementation magically handles tags
# "all" and "default". The default implementation interprets any undefined
# tags as being global options.
# 
sub _exporter_expand_tag
{
	no strict qw(refs);
	
	my $class = shift;
	my ($name, $value, $globals) = @_;
	my $tags  = \%{"$class\::EXPORT_TAGS"};
	
	return $class->_exporter_merge_opts($value, $globals, $tags->{$name}->($class, @_))
		if ref($tags->{$name}) eq q(CODE);
	
	return $class->_exporter_merge_opts($value, $globals, @{$tags->{$name}})
		if exists $tags->{$name};
	
	return $class->_exporter_merge_opts($value, $globals, @{"$class\::EXPORT"}, @{"$class\::EXPORT_OK"})
		if $name eq 'all';
	
	return $class->_exporter_merge_opts($value, $globals, @{"$class\::EXPORT"})
		if $name eq 'default';
	
	$globals->{$name} = $value || 1;
	return;
}

# Given a regexp-like string, looks it up in @EXPORT_OK and returns the
# list of matching functions.
# 
sub _exporter_expand_regexp
{
	no strict qw(refs);
	our %TRACKED;
	
	my $class = shift;
	my ($name, $value, $globals) = @_;
	my $compiled = eval("qr$name");
	
	my @possible = $globals->{is_unimport}
		? keys( %{$TRACKED{$class}{$globals->{into}}} )
		: @{"$class\::EXPORT_OK"};
	
	$class->_exporter_merge_opts($value, $globals, grep /$compiled/, @possible);
}

# Helper for _exporter_expand_sub. Returns a regexp matching all subs in
# the exporter package which are available for export.
#
sub _exporter_permitted_regexp
{
	no strict qw(refs);
	my $class = shift;
	my $re = join "|", map quotemeta, sort {
		length($b) <=> length($a) or $a cmp $b
	} @{"$class\::EXPORT"}, @{"$class\::EXPORT_OK"};
	qr{^(?:$re)$}ms;
}

# Given a sub name, returns a hash of subs to install (usually just one sub).
# Keys are sub names, values are coderefs.
#
sub _exporter_expand_sub
{
	my $class = shift;
	my ($name, $value, $globals, $permitted) = @_;
	$permitted ||= $class->_exporter_permitted_regexp($globals);
	
	no strict qw(refs);
	
	my $sigil = "&";
	if ($name =~ /\A([&\$\%\@\*])(.+)\z/) {
		$sigil = $1;
		$name  = $2;
		if ($sigil eq '*') {
			_croak("Cannot export symbols with a * sigil");
		}
	}
	my $sigilname = $sigil eq '&' ? $name : "$sigil$name";
	
	if ($sigilname =~ $permitted)
	{
		my $generatorprefix = {
			'&' => "_generate_",
			'$' => "_generateScalar_",
			'@' => "_generateArray_",
			'%' => "_generateHash_",
		}->{$sigil};
		
		my $generator = $class->can("$generatorprefix$name");
		return $sigilname => $class->$generator($sigilname, $value, $globals) if $generator;
		
		if ($sigil eq '&') {
			my $sub = $class->can($name);
			return $sigilname => $sub if $sub;
		}
		else {
			# Could do this more cleverly, but this works.
			my $evalled = eval "\\${sigil}${class}::${name}";
			return $sigilname => $evalled if $evalled;
		}
	}
	
	$class->_exporter_fail(@_);
}

# Called by _exporter_expand_sub if it is unable to generate a key-value
# pair for a sub.
#
sub _exporter_fail
{
	my $class = shift;
	my ($name, $value, $globals) = @_;
	return if $globals->{is_unimport};
	_croak("Could not find sub '%s' exported by %s", $name, $class);
}

# Actually performs the installation of the sub into the target package. This
# also handles renaming the sub.
#
sub _exporter_install_sub
{
	my $class = shift;
	my ($name, $value, $globals, $sym) = @_;
	my $value_hash = ( ref($value) eq 'HASH' ) ? $value : {};
	
	my $into      = $globals->{into};
	my $installer = $globals->{installer} || $globals->{exporter};
	
	$name =
		ref    $globals->{as}      ? $globals->{as}->($name) :
		ref    $value_hash->{-as}  ? $value_hash->{-as}->($name) :
		exists $value_hash->{-as}  ? $value_hash->{-as} :
		$name;
	
	return unless defined $name;
	
	my $sigil = "&";
	unless (ref($name)) {
		if ($name =~ /\A([&\$\%\@\*])(.+)\z/) {
			$sigil = $1;
			$name  = $2;
			if ($sigil eq '*') {
				_croak("Cannot export symbols with a * sigil");
			}
		}
		my ($prefix) = grep defined, $value_hash->{-prefix}, $globals->{prefix}, q();
		my ($suffix) = grep defined, $value_hash->{-suffix}, $globals->{suffix}, q();
		$name = "$prefix$name$suffix";
	}
	
	my $sigilname = $sigil eq '&' ? $name : ( $sigil . $name );
	
#	if ({qw/$ SCALAR @ ARRAY % HASH & CODE/}->{$sigil} ne ref($sym)) {
#		warn $sym;
#		warn $sigilname;
#		_croak("Reference type %s does not match sigil %s", ref($sym), $sigil);
#	}
	
	return ($$name = $sym)              if ref($name) eq q(SCALAR);
	return ($into->{$sigilname} = $sym) if ref($into) eq q(HASH);
	
	no strict qw(refs);
	our %TRACKED;
	
	if ( ref($sym) eq 'CODE'
	and ref($into) ? exists($into->{$name}) : exists(&{"$into\::$name"})
	and $sym != ( ref($into) ? $into->{$name} : \&{"$into\::$name"} ) )
	{
		my ($level) = grep defined, $value_hash->{-replace}, $globals->{replace}, q(0);
		my $action = {
			carp     => \&_carp,
			0        => \&_carp,
			''       => \&_carp,
			warn     => \&_carp,
			nonfatal => \&_carp,
			croak    => \&_croak,
			fatal    => \&_croak,
			die      => \&_croak,
		}->{$level} || sub {};
		
		# Don't complain about double-installing the same sub. This isn't ideal
		# because the same named sub might be generated in two different ways.
		$action = sub {} if $TRACKED{$class}{$into}{$sigilname};
		
		$action->(
			$action == \&_croak
				? "Refusing to overwrite existing sub '%s' with sub '%s' exported by %s"
				: "Overwriting existing sub '%s' with sub '%s' exported by %s",
			ref($into) ? $name : "$into\::$name",
			$_[0],
			$class,
		);
	}
	
	$TRACKED{$class}{$into}{$sigilname} = $sym;
	
	no warnings qw(prototype);
	$installer
		? $installer->($globals, [$sigilname, $sym])
		: (*{"$into\::$name"} = $sym);
}

sub _exporter_uninstall_sub
{
	our %TRACKED;
	my $class = shift;
	my ($name, $value, $globals, $sym) = @_;
	my $into = $globals->{into};
	ref $into and return;
	
	no strict qw(refs);

	my $sigil = "&";
	if ($name =~ /\A([&\$\%\@\*])(.+)\z/) {
		$sigil = $1;
		$name  = $2;
		if ($sigil eq '*') {
			_croak("Cannot export symbols with a * sigil");
		}
	}
	my $sigilname = $sigil eq '&' ? $name : "$sigil$name";
	
	if ($sigil ne '&') {
		_croak("Unimporting non-code symbols not supported yet");
	}

	# Cowardly refuse to uninstall a sub that differs from the one
	# we installed!
	my $our_coderef = $TRACKED{$class}{$into}{$name};
	my $cur_coderef = exists(&{"$into\::$name"}) ? \&{"$into\::$name"} : -1;
	return unless $our_coderef == $cur_coderef;
	
	my $stash     = \%{"$into\::"};
	my $old       = delete $stash->{$name};
	my $full_name = join('::', $into, $name);
	foreach my $type (qw(SCALAR HASH ARRAY IO)) # everything but the CODE
	{
		next unless defined(*{$old}{$type});
		*$full_name = *{$old}{$type};
	}
	
	delete $TRACKED{$class}{$into}{$name};
}

sub mkopt
{
	my $in = shift or return [];
	my @out;
	
	$in = [map(($_ => ref($in->{$_}) ? $in->{$_} : ()), sort keys %$in)]
		if ref($in) eq q(HASH);
	
	for (my $i = 0; $i < @$in; $i++)
	{
		my $k = $in->[$i];
		my $v;
		
		($i == $#$in)         ? ($v = undef) :
		!defined($in->[$i+1]) ? (++$i, ($v = undef)) :
		!ref($in->[$i+1])     ? ($v = undef) :
		($v = $in->[++$i]);
		
		push @out, [ $k => $v ];
	}
	
	\@out;
}

sub mkopt_hash
{
	my $in  = shift or return;
	my %out = map +($_->[0] => $_->[1]), @{ mkopt($in) };
	\%out;
}

1;

__END__

=pod

=encoding utf-8

=for stopwords frobnicate greps regexps

=head1 NAME

Exporter::Tiny - an exporter with the features of Sub::Exporter but only core dependencies

=head1 SYNOPSIS

   package MyUtils;
   use base "Exporter::Tiny";
   our @EXPORT = qw(frobnicate);
   sub frobnicate { ... }
   1;

   package MyScript;
   use MyUtils "frobnicate" => { -as => "frob" };
   print frob(42);
   exit;

=head1 DESCRIPTION

Exporter::Tiny supports many of Sub::Exporter's external-facing features
including renaming imported functions with the C<< -as >>, C<< -prefix >> and
C<< -suffix >> options; explicit destinations with the C<< into >> option;
and alternative installers with the C<< installer >> option. But it's written
in only about 40% as many lines of code and with zero non-core dependencies.

Its internal-facing interface is closer to Exporter.pm, with configuration
done through the C<< @EXPORT >>, C<< @EXPORT_OK >> and C<< %EXPORT_TAGS >>
package variables.

If you are trying to B<write> a module that inherits from Exporter::Tiny,
then look at:

=over

=item *

L<Exporter::Tiny::Manual::QuickStart>

=item *

L<Exporter::Tiny::Manual::Exporting>

=back

If you are trying to B<use> a module that inherits from Exporter::Tiny,
then look at:

=over

=item *

L<Exporter::Tiny::Manual::Importing>

=back

=head1 BUGS

Please report any bugs to
L<https://github.com/tobyink/p5-exporter-tiny/issues>.

=head1 SEE ALSO

L<https://exportertiny.github.io/>.

Simplified interface to this module: L<Exporter::Shiny>.

Less tiny version, with more features: L<Exporter::Almighty>.

Other interesting exporters: L<Sub::Exporter>, L<Exporter>.

=head1 AUTHOR

Toby Inkster E<lt>tobyink@cpan.orgE<gt>.

=head1 COPYRIGHT AND LICENCE

This software is copyright (c) 2013-2014, 2017, 2022-2023 by Toby Inkster.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=head1 DISCLAIMER OF WARRANTIES

THIS PACKAGE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.

