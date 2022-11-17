package Type::Tiny;

use 5.008001;
use strict;
use warnings;

BEGIN {
	if ( $] < 5.010 ) { require Devel::TypeTiny::Perl58Compat }
}

BEGIN {
	$Type::Tiny::AUTHORITY  = 'cpan:TOBYINK';
	$Type::Tiny::VERSION    = '2.000001';
	$Type::Tiny::XS_VERSION = '0.016';
}

$Type::Tiny::VERSION    =~ tr/_//d;
$Type::Tiny::XS_VERSION =~ tr/_//d;

use Scalar::Util qw( blessed );
use Types::TypeTiny ();

our $SafePackage = sprintf 'package %s;', __PACKAGE__;

sub _croak ($;@) { require Error::TypeTiny; goto \&Error::TypeTiny::croak }

sub _swap { $_[2] ? @_[ 1, 0 ] : @_[ 0, 1 ] }

BEGIN {
	my $support_smartmatch = 0+ !!( $] >= 5.010001 );
	eval qq{ sub SUPPORT_SMARTMATCH () { !! $support_smartmatch } };
	
	my $fixed_precedence = 0+ !!( $] >= 5.014 );
	eval qq{ sub _FIXED_PRECEDENCE () { !! $fixed_precedence } };
	
	my $try_xs =
		exists( $ENV{PERL_TYPE_TINY_XS} ) ? !!$ENV{PERL_TYPE_TINY_XS}
		: exists( $ENV{PERL_ONLY} )       ? !$ENV{PERL_ONLY}
		:                                   1;
		
	my $use_xs = 0;
	$try_xs and eval {
		require Type::Tiny::XS;
		'Type::Tiny::XS'->VERSION( $Type::Tiny::XS_VERSION );
		$use_xs++;
	};
	
	*_USE_XS =
		$use_xs
		? sub () { !!1 }
		: sub () { !!0 };
		
	*_USE_MOUSE =
		$try_xs
		? sub () { $INC{'Mouse/Util.pm'} and Mouse::Util::MOUSE_XS() }
		: sub () { !!0 };
	
	my $strict_mode = 0;
	$ENV{$_} && ++$strict_mode for qw(
		EXTENDED_TESTING
		AUTHOR_TESTING
		RELEASE_TESTING
		PERL_STRICT
	);
	*_STRICT_MODE = $strict_mode ? sub () { !!1 } : sub () { !!0 };
} #/ BEGIN

{

	sub _install_overloads {
		no strict 'refs';
		no warnings 'redefine', 'once';
		
		# Coverage is checked on Perl 5.26
		if ( $] < 5.010 ) {    # uncoverable statement
			require overload;             # uncoverable statement
			push @_, fallback => 1;       # uncoverable statement
			goto \&overload::OVERLOAD;    # uncoverable statement
		}
		
		my $class = shift;
		*{ $class . '::((' } = sub { };
		*{ $class . '::()' } = sub { };
		*{ $class . '::()' } = do { my $x = 1; \$x };
		while ( @_ ) {
			my $f = shift;
			*{ $class . '::(' . $f } = ref $_[0] ? shift : do {
				my $m = shift;
				sub { shift->$m( @_ ) }
			};
		}
	} #/ sub _install_overloads
}

__PACKAGE__->_install_overloads(
	q("") => sub {
		caller =~ m{^(Moo::HandleMoose|Sub::Quote)}
			? $_[0]->_stringify_no_magic
			: $_[0]->display_name;
	},
	q(bool) => sub { 1 },
	q(&{})  => "_overload_coderef",
	q(|)    => sub {
		my @tc = _swap @_;
		if ( !_FIXED_PRECEDENCE && $_[2] ) {
			if ( blessed $tc[0] ) {
				if ( blessed $tc[0] eq "Type::Tiny::_HalfOp" ) {
					my $type  = $tc[0]->{type};
					my $param = $tc[0]->{param};
					my $op    = $tc[0]->{op};
					require Type::Tiny::Union;
					return "Type::Tiny::_HalfOp"->new(
						$op,
						$param,
						"Type::Tiny::Union"->new_by_overload( type_constraints => [ $type, $tc[1] ] ),
					);
				} #/ if ( blessed $tc[0] eq...)
			} #/ if ( blessed $tc[0] )
			elsif ( ref $tc[0] eq 'ARRAY' ) {
				require Type::Tiny::_HalfOp;
				return "Type::Tiny::_HalfOp"->new( '|', @tc );
			}
		} #/ if ( !_FIXED_PRECEDENCE...)
		require Type::Tiny::Union;
		return "Type::Tiny::Union"->new_by_overload( type_constraints => \@tc );
	},
	q(&) => sub {
		my @tc = _swap @_;
		if ( !_FIXED_PRECEDENCE && $_[2] ) {
			if ( blessed $tc[0] ) {
				if ( blessed $tc[0] eq "Type::Tiny::_HalfOp" ) {
					my $type  = $tc[0]->{type};
					my $param = $tc[0]->{param};
					my $op    = $tc[0]->{op};
					require Type::Tiny::Intersection;
					return "Type::Tiny::_HalfOp"->new(
						$op,
						$param,
						"Type::Tiny::Intersection"->new_by_overload( type_constraints => [ $type, $tc[1] ] ),
					);
				} #/ if ( blessed $tc[0] eq...)
			} #/ if ( blessed $tc[0] )
			elsif ( ref $tc[0] eq 'ARRAY' ) {
				require Type::Tiny::_HalfOp;
				return "Type::Tiny::_HalfOp"->new( '&', @tc );
			}
		} #/ if ( !_FIXED_PRECEDENCE...)
		require Type::Tiny::Intersection;
		"Type::Tiny::Intersection"->new_by_overload( type_constraints => \@tc );
	},
	q(~)  => sub { shift->complementary_type },
	q(==) => sub { $_[0]->equals( $_[1] ) },
	q(!=) => sub { not $_[0]->equals( $_[1] ) },
	q(<)  => sub { my $m = $_[0]->can( 'is_subtype_of' ); $m->( _swap @_ ) },
	q(>)  => sub {
		my $m = $_[0]->can( 'is_subtype_of' );
		$m->( reverse _swap @_ );
	},
	q(<=) => sub { my $m = $_[0]->can( 'is_a_type_of' ); $m->( _swap @_ ) },
	q(>=) => sub {
		my $m = $_[0]->can( 'is_a_type_of' );
		$m->( reverse _swap @_ );
	},
	q(eq)  => sub { "$_[0]" eq "$_[1]" },
	q(cmp) => sub { $_[2] ? ( "$_[1]" cmp "$_[0]" ) : ( "$_[0]" cmp "$_[1]" ) },
	q(0+)  => sub { $_[0]{uniq} },
	q(/)   => sub { ( _STRICT_MODE xor $_[2] ) ? $_[0] : $_[1] },
);

__PACKAGE__->_install_overloads(
	q(~~) => sub { $_[0]->check( $_[1] ) },
) if Type::Tiny::SUPPORT_SMARTMATCH;

# Would be easy to just return sub { $self->assert_return(@_) }
# but try to build a more efficient coderef whenever possible.
#
sub _overload_coderef {
	my $self = shift;
	
	# Bypass generating a coderef if we've already got the best possible one.
	#
	return $self->{_overload_coderef} if $self->{_overload_coderef_no_rebuild};
	
	# Subclasses of Type::Tiny might override assert_return to do some kind
	# of interesting thing. In that case, we can't rely on it having identical
	# behaviour to Type::Tiny::inline_assert.
	#
	$self->{_overrides_assert_return} =
		( $self->can( 'assert_return' ) != \&assert_return )
		unless exists $self->{_overrides_assert_return};
		
	if ( $self->{_overrides_assert_return} ) {
		$self->{_overload_coderef} ||= do {
			Scalar::Util::weaken( my $weak = $self );
			sub { $weak->assert_return( @_ ) };
		};
		++$self->{_overload_coderef_no_rebuild};
	}
	elsif ( exists( &Sub::Quote::quote_sub ) ) {
	
		# Use `=` instead of `||=` because we want to overwrite non-Sub::Quote
		# coderef if possible.
		$self->{_overload_coderef} = $self->can_be_inlined
			? Sub::Quote::quote_sub(
			$self->inline_assert( '$_[0]' ),
			)
			: Sub::Quote::quote_sub(
			$self->inline_assert( '$_[0]', '$type' ),
			{ '$type' => \$self },
			);
		++$self->{_overload_coderef_no_rebuild};
	} #/ elsif ( exists( &Sub::Quote::quote_sub...))
	else {
		require Eval::TypeTiny;
		$self->{_overload_coderef} ||= $self->can_be_inlined
			? Eval::TypeTiny::eval_closure(
			source => sprintf(
				'sub { %s }', $self->inline_assert( '$_[0]', undef, no_wrapper => 1 )
			),
			description => sprintf( "compiled assertion 'assert_%s'", $self ),
			)
			: Eval::TypeTiny::eval_closure(
			source => sprintf(
				'sub { %s }', $self->inline_assert( '$_[0]', '$type', no_wrapper => 1 )
			),
			description => sprintf( "compiled assertion 'assert_%s'", $self ),
			environment => { '$type' => \$self },
			);
	} #/ else [ if ( $self->{_overrides_assert_return...})]
	
	$self->{_overload_coderef};
} #/ sub _overload_coderef

our %ALL_TYPES;

my $QFS;
my $uniq = 1;

sub new {
	my $class  = shift;
	my %params = ( @_ == 1 ) ? %{ $_[0] } : @_;
	
	for ( qw/ name display_name library / ) {
		$params{$_} = $params{$_} . '' if defined $params{$_};
	}
	
	if ( exists $params{parent} ) {
		$params{parent} =
			ref( $params{parent} ) =~ /^Type::Tiny\b/
			? $params{parent}
			: Types::TypeTiny::to_TypeTiny( $params{parent} );
			
		_croak "Parent must be an instance of %s", __PACKAGE__
			unless blessed( $params{parent} )
			&& $params{parent}->isa( __PACKAGE__ );
			
		if ( $params{parent}->deprecated and not exists $params{deprecated} ) {
			$params{deprecated} = 1;
		}
	} #/ if ( exists $params{parent...})
	
	if ( exists $params{constraint}
		and defined $params{constraint}
		and not ref $params{constraint} )
	{
		require Eval::TypeTiny;
		my $code = $params{constraint};
		$params{constraint} = Eval::TypeTiny::eval_closure(
			source      => sprintf( 'sub ($) { %s }', $code ),
			description => "anonymous check",
		);
		$params{inlined} ||= sub {
			my ( $type ) = @_;
			my $inlined  = $_ eq '$_' ? "do { $code }" : "do { local \$_ = $_; $code }";
			$type->has_parent ? ( undef, $inlined ) : $inlined;
			}
			if ( !exists $params{parent} or $params{parent}->can_be_inlined );
	} #/ if ( exists $params{constraint...})
	
	# canonicalize to a boolean
	$params{deprecated} = !!$params{deprecated};
	
	$params{name} = "__ANON__" unless exists $params{name};
	$params{uniq} = $uniq++;
	
	if ( $params{name} ne "__ANON__" ) {
	
		# First try a fast ASCII-only expression, but fall back to Unicode
		$params{name} =~ /^_{0,2}[A-Z][A-Za-z0-9_]+$/sm
			or eval q( use 5.008; $params{name} =~ /^_{0,2}\p{Lu}[\p{L}0-9_]+$/sm )
			or _croak '"%s" is not a valid type name', $params{name};
	}
	
	if ( exists $params{coercion} and !ref $params{coercion} and $params{coercion} )
	{
		$params{parent}->has_coercion
			or _croak
			"coercion => 1 requires type to have a direct parent with a coercion";
			
		$params{coercion} = $params{parent}->coercion->type_coercion_map;
	}
	
	if ( !exists $params{inlined}
		and exists $params{constraint}
		and ( !exists $params{parent} or $params{parent}->can_be_inlined )
		and $QFS ||= "Sub::Quote"->can( "quoted_from_sub" ) )
	{
		my ( undef, $perlstring, $captures ) = @{ $QFS->( $params{constraint} ) || [] };
		
		$params{inlined} = sub {
			my ( $self, $var ) = @_;
			my $code = Sub::Quote::inlinify(
				$perlstring,
				$var,
				$var eq q($_) ? '' : "local \$_ = $var;",
				1,
			);
			$code = sprintf( '%s and %s', $self->parent->inline_check( $var ), $code )
				if $self->has_parent;
			return $code;
			}
			if $perlstring && !$captures;
	} #/ if ( !exists $params{inlined...})
	
	my $self = bless \%params, $class;
	
	unless ( $params{tmp} ) {
		my $uniq = $self->{uniq};
		
		$ALL_TYPES{$uniq} = $self;
		Scalar::Util::weaken( $ALL_TYPES{$uniq} );
		
		my $tmp = $self;
		Scalar::Util::weaken( $tmp );
		$Moo::HandleMoose::TYPE_MAP{ $self->_stringify_no_magic } = sub { $tmp };
	} #/ unless ( $params{tmp} )
	
	if ( ref( $params{coercion} ) eq q(CODE) ) {
		require Types::Standard;
		my $code = delete( $params{coercion} );
		$self->{coercion} = $self->_build_coercion;
		$self->coercion->add_type_coercions( Types::Standard::Any(), $code );
	}
	elsif ( ref( $params{coercion} ) eq q(ARRAY) ) {
		my $arr = delete( $params{coercion} );
		$self->{coercion} = $self->_build_coercion;
		$self->coercion->add_type_coercions( @$arr );
	}
	
	# Documenting this here because it's too weird to be in the pod.
	# There's a secret attribute called "_build_coercion" which takes a
	# coderef. If present, then when $type->coercion is lazy built,
	# the blank Type::Coercion object gets passed to the coderef,
	# allowing the coderef to manipulate it a little. This is used by
	# Types::TypeTiny to allow it to build a coercion for the TypeTiny
	# type constraint without needing to load Type::Coercion yet.
	
	if ( $params{my_methods} ) {
		require Eval::TypeTiny;
		Scalar::Util::reftype( $params{my_methods}{$_} ) eq 'CODE'
			and Eval::TypeTiny::set_subname(
				sprintf( "%s::my_%s", $self->qualified_name, $_ ),
				$params{my_methods}{$_},
			) for keys %{ $params{my_methods} };
	} #/ if ( $params{my_methods...})
	
	return $self;
} #/ sub new

sub DESTROY {
	my $self = shift;
	delete( $ALL_TYPES{ $self->{uniq} } );
	delete( $Moo::HandleMoose::TYPE_MAP{ $self->_stringify_no_magic } );
	return;
}

sub _clone {
	my $self = shift;
	my %opts;
	$opts{$_} = $self->{$_} for qw< name display_name message >;
	$self->create_child_type( %opts );
}

sub _stringify_no_magic {
	sprintf(
		'%s=%s(0x%08x)', blessed( $_[0] ), Scalar::Util::reftype( $_[0] ),
		Scalar::Util::refaddr( $_[0] )
	);
}

our $DD;

sub _dd {
	@_ = $_ unless @_;
	my ( $value ) = @_;
	
	goto $DD if ref( $DD ) eq q(CODE);
	
	require B;
	
	!defined $value  ? 'Undef'
		: !ref $value ? sprintf( 'Value %s', B::perlstring( $value ) )
		: do {
		my $N = 0+ ( defined( $DD ) ? $DD : 72 );
		require Data::Dumper;
		local $Data::Dumper::Indent   = 0;
		local $Data::Dumper::Useqq    = 1;
		local $Data::Dumper::Terse    = 1;
		local $Data::Dumper::Sortkeys = 1;
		local $Data::Dumper::Maxdepth = 2;
		my $str;
		eval {
			$str = Data::Dumper::Dumper( $value );
			$str = substr( $str, 0, $N - 12 ) . '...' . substr( $str, -1, 1 )
				if length( $str ) >= $N;
			1;
		} or do { $str = 'which cannot be dumped' };
		"Reference $str";
	} #/ do
} #/ sub _dd

sub _loose_to_TypeTiny {
	my $caller = caller( 1 ); # assumption
	map +(
		ref( $_ )
		? Types::TypeTiny::to_TypeTiny( $_ )
		: do { require Type::Utils; Type::Utils::dwim_type( $_, for => $caller ) }
	), @_;
}

sub name         { $_[0]{name} }
sub display_name { $_[0]{display_name} ||= $_[0]->_build_display_name }
sub parent       { $_[0]{parent} }
sub constraint   { $_[0]{constraint} ||= $_[0]->_build_constraint }

sub compiled_check {
	$_[0]{compiled_type_constraint} ||= $_[0]->_build_compiled_check;
}
sub coercion             { $_[0]{coercion} ||= $_[0]->_build_coercion }
sub message              { $_[0]{message} }
sub library              { $_[0]{library} }
sub inlined              { $_[0]{inlined} }
sub deprecated           { $_[0]{deprecated} }
sub constraint_generator { $_[0]{constraint_generator} }
sub inline_generator     { $_[0]{inline_generator} }
sub name_generator       { $_[0]{name_generator} ||= $_[0]->_build_name_generator }
sub coercion_generator   { $_[0]{coercion_generator} }
sub parameters           { $_[0]{parameters} }
sub moose_type           { $_[0]{moose_type} ||= $_[0]->_build_moose_type }
sub mouse_type           { $_[0]{mouse_type} ||= $_[0]->_build_mouse_type }
sub deep_explanation     { $_[0]{deep_explanation} }
sub my_methods           { $_[0]{my_methods} ||= $_[0]->_build_my_methods }
sub sorter               { $_[0]{sorter} }

sub has_parent               { exists $_[0]{parent} }
sub has_library              { exists $_[0]{library} }
sub has_inlined              { exists $_[0]{inlined} }
sub has_constraint_generator { exists $_[0]{constraint_generator} }
sub has_inline_generator     { exists $_[0]{inline_generator} }
sub has_coercion_generator   { exists $_[0]{coercion_generator} }
sub has_parameters           { exists $_[0]{parameters} }
sub has_message              { defined $_[0]{message} }
sub has_deep_explanation     { exists $_[0]{deep_explanation} }
sub has_sorter               { exists $_[0]{sorter} }

sub _default_message {
	$_[0]{_default_message} ||= $_[0]->_build_default_message;
}

sub has_coercion {
	$_[0]->coercion if $_[0]{_build_coercion};    # trigger auto build thing
	$_[0]{coercion} and !!@{ $_[0]{coercion}->type_coercion_map };
}

sub _assert_coercion {
	my $self = shift;
	return $self->coercion if $self->{_build_coercion};    # trigger auto build thing
	_croak "No coercion for this type constraint"
		unless $self->has_coercion
		&& @{ $self->coercion->type_coercion_map };
	$self->coercion;
}

my $null_constraint = sub { !!1 };

sub _build_display_name {
	shift->name;
}

sub _build_constraint {
	return $null_constraint;
}

sub _is_null_constraint {
	shift->constraint == $null_constraint;
}

sub _build_coercion {
	require Type::Coercion;
	my $self = shift;
	my %opts = ( type_constraint => $self );
	$opts{display_name} = "to_$self" unless $self->is_anon;
	my $coercion = "Type::Coercion"->new( %opts );
	$self->{_build_coercion}->( $coercion ) if ref $self->{_build_coercion};
	$coercion;
}

sub _build_default_message {
	my $self = shift;
	$self->{is_using_default_message} = 1;
	return sub { sprintf '%s did not pass type constraint', _dd( $_[0] ) }
		if "$self" eq "__ANON__";
	my $name = "$self";
	return sub {
		sprintf '%s did not pass type constraint "%s"', _dd( $_[0] ), $name;
	};
} #/ sub _build_default_message

sub _build_name_generator {
	my $self = shift;
	return sub {
		defined && s/[\x00-\x1F]//smg for ( my ( $s, @a ) = @_ );
		sprintf( '%s[%s]', $s, join q[,], map !defined() ? 'undef' : !ref() && /\W/ ? B::perlstring($_) : $_, @a );
	};
}

sub _build_compiled_check {
	my $self = shift;
	
	local our $AvoidCallbacks = 0;
	
	if ( $self->_is_null_constraint and $self->has_parent ) {
		return $self->parent->compiled_check;
	}
	
	require Eval::TypeTiny;
	return Eval::TypeTiny::eval_closure(
		source      => sprintf( 'sub ($) { %s }',      $self->inline_check( '$_[0]' ) ),
		description => sprintf( "compiled check '%s'", $self ),
	) if $self->can_be_inlined;
	
	my @constraints;
	push @constraints, $self->parent->compiled_check if $self->has_parent;
	push @constraints, $self->constraint             if !$self->_is_null_constraint;
	return $null_constraint unless @constraints;
	
	return sub ($) {
		local $_ = $_[0];
		for my $c ( @constraints ) {
			return unless $c->( @_ );
		}
		return !!1;
	};
} #/ sub _build_compiled_check

sub find_constraining_type {
	my $self = shift;
	if ( $self->_is_null_constraint and $self->has_parent ) {
		return $self->parent->find_constraining_type;
	}
	$self;
}

sub type_default {
	my ( $self, @args ) = @_;
	if ( exists $self->{type_default} ) {
		if ( @args ) {
			my $td = $self->{type_default};
			return sub { local $_ = \@args; &$td; };
		}
		return $self->{type_default};
	}
	if ( my $parent = $self->parent ) {
		return $parent->type_default( @args ) if $self->_is_null_constraint;
	}
	return undef;
}

our @CMP;

sub CMP_SUPERTYPE ()  { -1 }
sub CMP_EQUAL ()      { 0 }
sub CMP_EQUIVALENT () { '0E0' }
sub CMP_SUBTYPE ()    { 1 }
sub CMP_UNKNOWN ()    { ''; }

# avoid getting mixed up with cmp operator at compile time
*cmp = sub {
	my ( $A, $B ) = _loose_to_TypeTiny( $_[0], $_[1] );
	return unless blessed( $A ) && $A->isa( "Type::Tiny" );
	return unless blessed( $B ) && $B->isa( "Type::Tiny" );
	for my $comparator ( @CMP ) {
		my $result = $comparator->( $A, $B );
		next if $result eq CMP_UNKNOWN;
		if ( $result eq CMP_EQUIVALENT ) {
			my $prefer = @_ == 3 ? $_[2] : CMP_EQUAL;
			return $prefer;
		}
		return $result;
	}
	return CMP_UNKNOWN;
};

push @CMP, sub {
	my ( $A, $B ) = @_;
	return CMP_EQUAL
		if Scalar::Util::refaddr( $A ) == Scalar::Util::refaddr( $B );
		
	return CMP_EQUIVALENT
		if Scalar::Util::refaddr( $A->compiled_check ) ==
		Scalar::Util::refaddr( $B->compiled_check );
		
	my $A_stem = $A->find_constraining_type;
	my $B_stem = $B->find_constraining_type;
	return CMP_EQUIVALENT
		if Scalar::Util::refaddr( $A_stem ) == Scalar::Util::refaddr( $B_stem );
	return CMP_EQUIVALENT
		if Scalar::Util::refaddr( $A_stem->compiled_check ) ==
		Scalar::Util::refaddr( $B_stem->compiled_check );
		
	if ( $A_stem->can_be_inlined and $B_stem->can_be_inlined ) {
		return CMP_EQUIVALENT
			if $A_stem->inline_check( '$WOLFIE' ) eq $B_stem->inline_check( '$WOLFIE' );
	}
	
	A_IS_SUBTYPE: {
		my $A_prime = $A_stem;
		while ( $A_prime->has_parent ) {
			$A_prime = $A_prime->parent;
			return CMP_SUBTYPE
				if Scalar::Util::refaddr( $A_prime ) == Scalar::Util::refaddr( $B_stem );
			return CMP_SUBTYPE
				if Scalar::Util::refaddr( $A_prime->compiled_check ) ==
				Scalar::Util::refaddr( $B_stem->compiled_check );
			if ( $A_prime->can_be_inlined and $B_stem->can_be_inlined ) {
				return CMP_SUBTYPE
					if $A_prime->inline_check( '$WOLFIE' ) eq $B_stem->inline_check( '$WOLFIE' );
			}
		} #/ while ( $A_prime->has_parent)
	} #/ A_IS_SUBTYPE:
	
	B_IS_SUBTYPE: {
		my $B_prime = $B_stem;
		while ( $B_prime->has_parent ) {
			$B_prime = $B_prime->parent;
			return CMP_SUPERTYPE
				if Scalar::Util::refaddr( $B_prime ) == Scalar::Util::refaddr( $A_stem );
			return CMP_SUPERTYPE
				if Scalar::Util::refaddr( $B_prime->compiled_check ) ==
				Scalar::Util::refaddr( $A_stem->compiled_check );
			if ( $A_stem->can_be_inlined and $B_prime->can_be_inlined ) {
				return CMP_SUPERTYPE
					if $B_prime->inline_check( '$WOLFIE' ) eq $A_stem->inline_check( '$WOLFIE' );
			}
		} #/ while ( $B_prime->has_parent)
	} #/ B_IS_SUBTYPE:
	
	return CMP_UNKNOWN;
};

sub equals {
	my $result = Type::Tiny::cmp( $_[0], $_[1] );
	return unless defined $result;
	$result eq CMP_EQUAL;
}

sub is_subtype_of {
	my $result = Type::Tiny::cmp( $_[0], $_[1], CMP_SUBTYPE );
	return unless defined $result;
	$result eq CMP_SUBTYPE;
}

sub is_supertype_of {
	my $result = Type::Tiny::cmp( $_[0], $_[1], CMP_SUBTYPE );
	return unless defined $result;
	$result eq CMP_SUPERTYPE;
}

sub is_a_type_of {
	my $result = Type::Tiny::cmp( $_[0], $_[1] );
	return unless defined $result;
	$result eq CMP_SUBTYPE or $result eq CMP_EQUAL or $result eq CMP_EQUIVALENT;
}

sub strictly_equals {
	my ( $self, $other ) = _loose_to_TypeTiny( @_ );
	return unless blessed( $self )  && $self->isa( "Type::Tiny" );
	return unless blessed( $other ) && $other->isa( "Type::Tiny" );
	$self->{uniq} == $other->{uniq};
}

sub is_strictly_subtype_of {
	my ( $self, $other ) = _loose_to_TypeTiny( @_ );
	return unless blessed( $self )  && $self->isa( "Type::Tiny" );
	return unless blessed( $other ) && $other->isa( "Type::Tiny" );
	
	return unless $self->has_parent;
	$self->parent->strictly_equals( $other )
		or $self->parent->is_strictly_subtype_of( $other );
}

sub is_strictly_supertype_of {
	my ( $self, $other ) = _loose_to_TypeTiny( @_ );
	return unless blessed( $self )  && $self->isa( "Type::Tiny" );
	return unless blessed( $other ) && $other->isa( "Type::Tiny" );
	
	$other->is_strictly_subtype_of( $self );
}

sub is_strictly_a_type_of {
	my ( $self, $other ) = _loose_to_TypeTiny( @_ );
	return unless blessed( $self )  && $self->isa( "Type::Tiny" );
	return unless blessed( $other ) && $other->isa( "Type::Tiny" );
	
	$self->strictly_equals( $other ) or $self->is_strictly_subtype_of( $other );
}

sub qualified_name {
	my $self = shift;
	( exists $self->{library} and $self->name ne "__ANON__" )
		? "$self->{library}::$self->{name}"
		: $self->{name};
}

sub is_anon {
	my $self = shift;
	$self->name eq "__ANON__";
}

sub parents {
	my $self = shift;
	return unless $self->has_parent;
	return ( $self->parent, $self->parent->parents );
}

sub find_parent {
	my $self = shift;
	my ( $test ) = @_;
	
	local ( $_, $. );
	my $type  = $self;
	my $count = 0;
	while ( $type ) {
		if ( $test->( $_ = $type, $. = $count ) ) {
			return wantarray ? ( $type, $count ) : $type;
		}
		else {
			$type = $type->parent;
			$count++;
		}
	}
	
	return;
} #/ sub find_parent

sub check {
	my $self = shift;
	( $self->{compiled_type_constraint} ||= $self->_build_compiled_check )->( @_ );
}

sub _strict_check {
	my $self = shift;
	local $_ = $_[0];
	
	my @constraints =
		reverse
		map { $_->constraint }
		grep { not $_->_is_null_constraint } ( $self, $self->parents );
		
	for my $c ( @constraints ) {
		return unless $c->( @_ );
	}
	
	return !!1;
} #/ sub _strict_check

sub get_message {
	my $self = shift;
	local $_ = $_[0];
	$self->has_message
		? $self->message->( @_ )
		: $self->_default_message->( @_ );
}

sub validate {
	my $self = shift;
	
	return undef
		if ( $self->{compiled_type_constraint} ||= $self->_build_compiled_check )
		->( @_ );
		
	local $_ = $_[0];
	return $self->get_message( @_ );
} #/ sub validate

sub validate_explain {
	my $self = shift;
	my ( $value, $varname ) = @_;
	$varname = '$_' unless defined $varname;
	
	return undef if $self->check( $value );
	
	if ( $self->has_parent ) {
		my $parent = $self->parent->validate_explain( $value, $varname );
		return [
			sprintf( '"%s" is a subtype of "%s"', $self, $self->parent ),
			@$parent
			]
			if $parent;
	}
	
	my $message = sprintf(
		'%s%s',
		$self->get_message( $value ),
		$varname eq q{$_} ? '' : sprintf( ' (in %s)', $varname ),
	);
	
	if ( $self->is_parameterized and $self->parent->has_deep_explanation ) {
		my $deep = $self->parent->deep_explanation->( $self, $value, $varname );
		return [ $message, @$deep ] if $deep;
	}

	local $SIG{__WARN__} = sub {};
	return [
		$message,
		sprintf( '"%s" is defined as: %s', $self, $self->_perlcode )
	];
} #/ sub validate_explain

my $b;

sub _perlcode {
	my $self = shift;
	
	local our $AvoidCallbacks = 1;
	return $self->inline_check( '$_' )
		if $self->can_be_inlined;
		
	$b ||= do {
		local $@;
		require B::Deparse;
		my $tmp = "B::Deparse"->new;
		$tmp->ambient_pragmas( strict => "all", warnings => "all" )
			if $tmp->can( 'ambient_pragmas' );
		$tmp;
	};
	
	my $code = $b->coderef2text( $self->constraint );
	$code =~ s/\s+/ /g;
	return "sub $code";
} #/ sub _perlcode

sub assert_valid {
	my $self = shift;
	
	return !!1
		if ( $self->{compiled_type_constraint} ||= $self->_build_compiled_check )
		->( @_ );
		
	local $_ = $_[0];
	$self->_failed_check( "$self", $_ );
} #/ sub assert_valid

sub assert_return {
	my $self = shift;
	
	return $_[0]
		if ( $self->{compiled_type_constraint} ||= $self->_build_compiled_check )
		->( @_ );
		
	local $_ = $_[0];
	$self->_failed_check( "$self", $_ );
} #/ sub assert_return

sub can_be_inlined {
	my $self = shift;
	return $self->parent->can_be_inlined
		if $self->has_parent && $self->_is_null_constraint;
	return !!1
		if !$self->has_parent && $self->_is_null_constraint;
	return $self->has_inlined;
}

sub inline_check {
	my $self = shift;
	_croak 'Cannot inline type constraint check for "%s"', $self
		unless $self->can_be_inlined;
		
	return $self->parent->inline_check( @_ )
		if $self->has_parent && $self->_is_null_constraint;
	return '(!!1)'
		if !$self->has_parent && $self->_is_null_constraint;
		
	local $_ = $_[0];
	my @r = $self->inlined->( $self, @_ );
	if ( @r and not defined $r[0] ) {
		_croak 'Inlining type constraint check for "%s" returned undef!', $self
			unless $self->has_parent;
		$r[0] = $self->parent->inline_check( @_ );
	}
	my $r = join " && " => map {
		/[;{}]/ && !/\Ado \{.+\}\z/
			? "do { $SafePackage $_ }"
			: "($_)"
	} @r;
	return @r == 1 ? $r : "($r)";
} #/ sub inline_check

sub inline_assert {
	require B;
	my $self = shift;
	my ( $varname, $typevarname, %extras ) = @_;
	
	my $inline_check;
	if ( $self->can_be_inlined ) {
		$inline_check = sprintf( '(%s)', $self->inline_check( $varname ) );
	}
	elsif ( $typevarname ) {
		$inline_check = sprintf( '%s->check(%s)', $typevarname, $varname );
	}
	else {
		_croak 'Cannot inline type constraint check for "%s"', $self;
	}
	
	my $do_wrapper = !delete $extras{no_wrapper};
	
	my $inline_throw;
	if ( $typevarname ) {
		$inline_throw = sprintf(
			'Type::Tiny::_failed_check(%s, %s, %s, %s)',
			$typevarname,
			B::perlstring( "$self" ),
			$varname,
			join(
				',', map +( B::perlstring( $_ ) => B::perlstring( $extras{$_} ) ),
				sort keys %extras
			),
		);
	} #/ if ( $typevarname )
	else {
		$inline_throw = sprintf(
			'Type::Tiny::_failed_check(%s, %s, %s, %s)',
			$self->{uniq},
			B::perlstring( "$self" ),
			$varname,
			join(
				',', map +( B::perlstring( $_ ) => B::perlstring( $extras{$_} ) ),
				sort keys %extras
			),
		);
	} #/ else [ if ( $typevarname ) ]
	
	$do_wrapper
		? qq[do { no warnings "void"; $SafePackage $inline_check or $inline_throw; $varname };]
		: qq[     no warnings "void"; $SafePackage $inline_check or $inline_throw; $varname   ];
} #/ sub inline_assert

sub _failed_check {
	require Error::TypeTiny::Assertion;
	
	my ( $self, $name, $value, %attrs ) = @_;
	$self = $ALL_TYPES{$self} if defined $self && !ref $self;
	
	my $exception_class =
		delete( $attrs{exception_class} ) || "Error::TypeTiny::Assertion";
	my $callback = delete( $attrs{on_die} );

	if ( $self ) {
		return $exception_class->throw_cb(
			$callback,
			message => $self->get_message( $value ),
			type    => $self,
			value   => $value,
			%attrs,
		);
	}
	else {
		return $exception_class->throw_cb(
			$callback,
			message => sprintf( '%s did not pass type constraint "%s"', _dd( $value ), $name ),
			value => $value,
			%attrs,
		);
	}
} #/ sub _failed_check

sub coerce {
	my $self = shift;
	$self->_assert_coercion->coerce( @_ );
}

sub assert_coerce {
	my $self = shift;
	$self->_assert_coercion->assert_coerce( @_ );
}

sub is_parameterizable {
	shift->has_constraint_generator;
}

sub is_parameterized {
	shift->has_parameters;
}

{
	my %seen;
	
	sub ____make_key {
		#<<<
		join ',', map {
			Types::TypeTiny::is_TypeTiny( $_ )  ? sprintf( '$Type::Tiny::ALL_TYPES{%s}', defined( $_->{uniq} ) ? $_->{uniq} : '____CANNOT_KEY____' ) :
			ref() eq 'ARRAY'                    ? do { $seen{$_}++ ? '____CANNOT_KEY____' : sprintf( '[%s]', ____make_key( @$_ ) ) } :
			ref() eq 'HASH'                     ? do { $seen{$_}++ ? '____CANNOT_KEY____' : sprintf( '{%s}', ____make_key( do { my %h = %$_; map +( $_, $h{$_} ), sort keys %h; } ) ) } :
			ref() eq 'SCALAR' || ref() eq 'REF' ? do { $seen{$_}++ ? '____CANNOT_KEY____' : sprintf( '\\(%s)', ____make_key( $$_ ) ) } :
			!defined()                          ? 'undef' :
			!ref()                              ? do { require B; B::perlstring( $_ ) } :
			'____CANNOT_KEY____';
		} @_;
		#>>>
	} #/ sub ____make_key
	my %param_cache;
	
	sub parameterize {
		my $self = shift;
		
		$self->is_parameterizable
			or @_
			? _croak( "Type '%s' does not accept parameters", "$self" )
			: return ( $self );
			
		@_ = map Types::TypeTiny::to_TypeTiny( $_ ), @_;
		
		# Generate a key for caching parameterized type constraints,
		# but only if all the parameters are strings or type constraints.
		%seen = ();
		my $key = $self->____make_key( @_ );
		undef( $key )             if $key =~ /____CANNOT_KEY____/;
		return $param_cache{$key} if defined $key && defined $param_cache{$key};
		
		local $Type::Tiny::parameterize_type = $self;
		local $_                             = $_[0];
		my $P;
		
		my ( $constraint, $compiled ) = $self->constraint_generator->( @_ );
		
		if ( Types::TypeTiny::is_TypeTiny( $constraint ) ) {
			$P = $constraint;
		}
		else {
			my %options = (
				constraint   => $constraint,
				display_name => $self->name_generator->( $self, @_ ),
				parameters   => [@_],
			);
			$options{compiled_type_constraint} = $compiled
				if $compiled;
			$options{inlined} = $self->inline_generator->( @_ )
				if $self->has_inline_generator;
			$options{type_default} = $self->{type_default_generator}->( @_ )
				if exists $self->{type_default_generator}; # undocumented
			exists $options{$_} && !defined $options{$_} && delete $options{$_}
				for keys %options;
			
			$P = $self->create_child_type( %options );
			
			if ( $self->has_coercion_generator ) {
				my @args = @_;
				$P->{_build_coercion} = sub {
					my $coercion = shift;
					my $built    = $self->coercion_generator->( $self, $P, @args );
					$coercion->add_type_coercions( @{ $built->type_coercion_map } ) if $built;
					$coercion->freeze;
				};
			}
		} #/ else [ if ( Types::TypeTiny::is_TypeTiny...)]
		
		if ( defined $key ) {
			$param_cache{$key} = $P;
			Scalar::Util::weaken( $param_cache{$key} );
		}
		
		$P->coercion->freeze unless $self->has_coercion_generator;
		
		return $P;
	} #/ sub parameterize
}

sub child_type_class {
	__PACKAGE__;
}

sub create_child_type {
	my $self = shift;
	my %moreopts;
	$moreopts{is_object} = 1 if $self->{is_object};
	return $self->child_type_class->new( parent => $self, %moreopts, @_ );
}

sub complementary_type {
	my $self = shift;
	my $r    = ( $self->{complementary_type} ||= $self->_build_complementary_type );
	Scalar::Util::weaken( $self->{complementary_type} )
		unless Scalar::Util::isweak( $self->{complementary_type} );
	return $r;
}

sub _build_complementary_type {
	my $self = shift;
	my %opts = (
		constraint   => sub { not $self->check( $_ ) },
		display_name => sprintf( "~%s", $self ),
	);
	$opts{display_name} =~ s/^\~{2}//;
	$opts{inlined} = sub { shift; "not(" . $self->inline_check( @_ ) . ")" }
		if $self->can_be_inlined;
	$opts{display_name} = $opts{name} = $self->{complement_name}
		if $self->{complement_name};
	return "Type::Tiny"->new( %opts );
} #/ sub _build_complementary_type

sub _instantiate_moose_type {
	my $self = shift;
	my %opts = @_;
	require Moose::Meta::TypeConstraint;
	return "Moose::Meta::TypeConstraint"->new( %opts );
}

sub _build_moose_type {
	my $self = shift;
	
	my $r;
	if ( $self->{_is_core} ) {
		require Moose::Util::TypeConstraints;
		$r = Moose::Util::TypeConstraints::find_type_constraint( $self->name );
		$r->{"Types::TypeTiny::to_TypeTiny"} = $self;
		Scalar::Util::weaken( $r->{"Types::TypeTiny::to_TypeTiny"} );
	}
	else {
		# Type::Tiny is more flexible than Moose, allowing
		# inlined to return a list. So we need to wrap the
		# inlined coderef to make sure Moose gets a single
		# string.
		#
		my $wrapped_inlined = sub {
			shift;
			$self->inline_check( @_ );
		};
		
		my %opts;
		$opts{name}   = $self->qualified_name if $self->has_library && !$self->is_anon;
		$opts{parent} = $self->parent->moose_type if $self->has_parent;
		$opts{constraint} = $self->constraint unless $self->_is_null_constraint;
		$opts{message}    = $self->message   if $self->has_message;
		$opts{inlined}    = $wrapped_inlined if $self->has_inlined;
		
		$r                                   = $self->_instantiate_moose_type( %opts );
		$r->{"Types::TypeTiny::to_TypeTiny"} = $self;
		$self->{moose_type}                  = $r;                                     # prevent recursion
		$r->coercion( $self->coercion->moose_coercion ) if $self->has_coercion;
	} #/ else [ if ( $self->{_is_core})]
	
	return $r;
} #/ sub _build_moose_type

sub _build_mouse_type {
	my $self = shift;
	
	my %options;
	$options{name} = $self->qualified_name if $self->has_library && !$self->is_anon;
	$options{parent}     = $self->parent->mouse_type if $self->has_parent;
	$options{constraint} = $self->constraint unless $self->_is_null_constraint;
	$options{message}    = $self->message if $self->has_message;
	
	require Mouse::Meta::TypeConstraint;
	my $r = "Mouse::Meta::TypeConstraint"->new( %options );
	
	$self->{mouse_type} = $r;    # prevent recursion
	$r->_add_type_coercions(
		$self->coercion->freeze->_codelike_type_coercion_map( 'mouse_type' ) )
		if $self->has_coercion;
		
	return $r;
} #/ sub _build_mouse_type

sub exportables {
	my ( $self, $base_name, $tag ) = ( shift, @_ ); # $tag is undocumented
	if ( not $self->is_anon ) {
		$base_name ||= $self->name;
	}
	$tag ||= 0;

	my @exportables;
	return \@exportables if ! $base_name;

	require Eval::TypeTiny;

	push @exportables, {
		name => $base_name,
		code => Eval::TypeTiny::type_to_coderef( $self ),
		tags => [ 'types' ],
	} if $tag eq 'types' || !$tag;

	push @exportables, {
		name => sprintf( 'is_%s', $base_name ),
		code => $self->compiled_check,
		tags => [ 'is' ],
	} if $tag eq 'is' || !$tag;

	push @exportables, {
		name => sprintf( 'assert_%s', $base_name ),
		code => $self->_overload_coderef,
		tags => [ 'assert' ],
	} if $tag eq 'assert' || !$tag;

	push @exportables, {
		name => sprintf( 'to_%s', $base_name ),
		code => $self->has_coercion && $self->coercion->frozen
			? $self->coercion->compiled_coercion
			: sub ($) { $self->coerce( $_[0] ) },
		tags => [ 'to' ],
	} if $tag eq 'to' || !$tag;

	return \@exportables;
}

sub exportables_by_tag {
	my ( $self, $tag, $base_name ) = ( shift, @_ );
	my @matched = grep {
		my $e = $_;
		grep $_ eq $tag, @{ $e->{tags} || [] };
	} @{ $self->exportables( $base_name, $tag ) };
	return @matched if wantarray;
	_croak( 'Expected to find one exportable tagged "%s", found %d', $tag, scalar @matched )
		unless @matched == 1;
	return $matched[0];
}

sub _process_coercion_list {
	my $self = shift;
	
	my @pairs;
	while ( @_ ) {
		my $next = shift;
		if ( blessed( $next )
			and $next->isa( 'Type::Coercion' )
			and $next->is_parameterized )
		{
			push @pairs => ( @{ $next->_reparameterize( $self )->type_coercion_map } );
		}
		elsif ( blessed( $next ) and $next->can( 'type_coercion_map' ) ) {
			push @pairs => (
				@{ $next->type_coercion_map },
			);
		}
		elsif ( ref( $next ) eq q(ARRAY) ) {
			unshift @_, @$next;
		}
		else {
			push @pairs => (
				Types::TypeTiny::to_TypeTiny( $next ),
				shift,
			);
		}
	} #/ while ( @_ )
	
	return @pairs;
} #/ sub _process_coercion_list

sub plus_coercions {
	my $self = shift;
	my $new  = $self->_clone;
	$new->coercion->add_type_coercions(
		$self->_process_coercion_list( @_ ),
		@{ $self->coercion->type_coercion_map },
	);
	$new->coercion->freeze;
	return $new;
} #/ sub plus_coercions

sub plus_fallback_coercions {
	my $self = shift;
	
	my $new = $self->_clone;
	$new->coercion->add_type_coercions(
		@{ $self->coercion->type_coercion_map },
		$self->_process_coercion_list( @_ ),
	);
	$new->coercion->freeze;
	return $new;
} #/ sub plus_fallback_coercions

sub minus_coercions {
	my $self = shift;
	
	my $new = $self->_clone;
	my @not = grep Types::TypeTiny::is_TypeTiny( $_ ),
		$self->_process_coercion_list( $new, @_ );
		
	my @keep;
	my $c = $self->coercion->type_coercion_map;
	for ( my $i = 0 ; $i <= $#$c ; $i += 2 ) {
		my $keep_this = 1;
		NOT: for my $n ( @not ) {
			if ( $c->[$i] == $n ) {
				$keep_this = 0;
				last NOT;
			}
		}
		
		push @keep, $c->[$i], $c->[ $i + 1 ] if $keep_this;
	} #/ for ( my $i = 0 ; $i <=...)
	
	$new->coercion->add_type_coercions( @keep );
	$new->coercion->freeze;
	return $new;
} #/ sub minus_coercions

sub no_coercions {
	my $new = shift->_clone;
	$new->coercion->freeze;
	$new;
}

sub coercibles {
	my $self = shift;
	$self->has_coercion ? $self->coercion->_source_type_union : $self;
}

sub isa {
	my $self = shift;
	
	if ( $INC{"Moose.pm"}
		and ref( $self )
		and $_[0] =~ /^(?:Class::MOP|MooseX?::Meta)::(.+)$/ )
	{
		my $meta = $1;
		
		return !!1                       if $meta eq 'TypeConstraint';
		return $self->is_parameterized   if $meta eq 'TypeConstraint::Parameterized';
		return $self->is_parameterizable if $meta eq 'TypeConstraint::Parameterizable';
		return $self->isa( 'Type::Tiny::Union' ) if $meta eq 'TypeConstraint::Union';
		
		my $inflate = $self->moose_type;
		return $inflate->isa( @_ );
	} #/ if ( $INC{"Moose.pm"} ...)
	
	if ( $INC{"Mouse.pm"}
		and ref( $self )
		and $_[0] eq 'Mouse::Meta::TypeConstraint' )
	{
		return !!1;
	}
	
	$self->SUPER::isa( @_ );
} #/ sub isa

sub _build_my_methods {
	return {};
}

sub _lookup_my_method {
	my $self = shift;
	my ( $name ) = @_;
	
	if ( $self->my_methods->{$name} ) {
		return $self->my_methods->{$name};
	}
	
	if ( $self->has_parent ) {
		return $self->parent->_lookup_my_method( @_ );
	}
	
	return;
} #/ sub _lookup_my_method

my %object_methods = (
	with_attribute_values => 1, stringifies_to => 1,
	numifies_to           => 1
);

sub can {
	my $self = shift;
	
	return !!0
		if $_[0] eq 'type_parameter'
		&& blessed( $_[0] )
		&& $_[0]->has_parameters;
		
	my $can = $self->SUPER::can( @_ );
	return $can if $can;
	
	if ( ref( $self ) ) {
		if ( $INC{"Moose.pm"} ) {
			my $method = $self->moose_type->can( @_ );
			return sub { shift->moose_type->$method( @_ ) }
				if $method;
		}
		if ( $_[0] =~ /\Amy_(.+)\z/ ) {
			my $method = $self->_lookup_my_method( $1 );
			return $method if $method;
		}
		if ( $self->{is_object} && $object_methods{ $_[0] } ) {
			require Type::Tiny::ConstrainedObject;
			return Type::Tiny::ConstrainedObject->can( $_[0] );
		}
		for my $util ( qw/ grep map sort rsort first any all assert_any assert_all / ) {
			if ( $_[0] eq $util ) {
				$self->{'_util'}{$util} ||= eval { $self->_build_util( $util ) };
				return unless $self->{'_util'}{$util};
				return sub { my $s = shift; $s->{'_util'}{$util}( @_ ) };
			}
		}
	} #/ if ( ref( $self ) )
	
	return;
} #/ sub can

sub AUTOLOAD {
	my $self = shift;
	my ( $m ) = ( our $AUTOLOAD =~ /::(\w+)$/ );
	return if $m eq 'DESTROY';
	
	if ( ref( $self ) ) {
		if ( $INC{"Moose.pm"} ) {
			my $method = $self->moose_type->can( $m );
			return $self->moose_type->$method( @_ ) if $method;
		}
		if ( $m =~ /\Amy_(.+)\z/ ) {
			my $method = $self->_lookup_my_method( $1 );
			return &$method( $self, @_ ) if $method;
		}
		if ( $self->{is_object} && $object_methods{$m} ) {
			require Type::Tiny::ConstrainedObject;
			unshift @_, $self;
			no strict 'refs';
			goto \&{"Type::Tiny::ConstrainedObject::$m"};
		}
		for my $util ( qw/ grep map sort rsort first any all assert_any assert_all / ) {
			if ( $m eq $util ) {
				return ( $self->{'_util'}{$util} ||= $self->_build_util( $util ) )->( @_ );
			}
		}
	} #/ if ( ref( $self ) )
	
	_croak q[Can't locate object method "%s" via package "%s"], $m,
		ref( $self ) || $self;
} #/ sub AUTOLOAD

sub DOES {
	my $self = shift;
	
	return !!1
		if ref( $self )
		&& $_[0] =~ m{^ Type::API::Constraint (?: ::Coercible | ::Inlinable )? $}x;
	return !!1 if !ref( $self ) && $_[0] eq 'Type::API::Constraint::Constructor';
	
	"UNIVERSAL"->can( "DOES" ) ? $self->SUPER::DOES( @_ ) : $self->isa( @_ );
} #/ sub DOES

sub _has_xsub {
	require B;
	!!B::svref_2object( shift->compiled_check )->XSUB;
}

sub _build_util {
	my ( $self, $func ) = @_;
	Scalar::Util::weaken( my $type = $self );
	
	if ( $func eq 'grep'
		|| $func eq 'first'
		|| $func eq 'any'
		|| $func eq 'all'
		|| $func eq 'assert_any'
		|| $func eq 'assert_all' )
	{
		my ( $inline, $compiled );
		
		if ( $self->can_be_inlined ) {
			$inline = $self->inline_check( '$_' );
		}
		else {
			$compiled = $self->compiled_check;
			$inline   = '$compiled->($_)';
		}
		
		if ( $func eq 'grep' ) {
			return eval "sub { grep { $inline } \@_ }";
		}
		elsif ( $func eq 'first' ) {
			return eval "sub { for (\@_) { return \$_ if ($inline) }; undef; }";
		}
		elsif ( $func eq 'any' ) {
			return eval "sub { for (\@_) { return !!1 if ($inline) }; !!0; }";
		}
		elsif ( $func eq 'assert_any' ) {
			my $qname = B::perlstring( $self->name );
			return
				eval
				"sub { for (\@_) { return \@_ if ($inline) }; Type::Tiny::_failed_check(\$type, $qname, \@_ ? \$_[-1] : undef); }";
		}
		elsif ( $func eq 'all' ) {
			return eval "sub { for (\@_) { return !!0 unless ($inline) }; !!1; }";
		}
		elsif ( $func eq 'assert_all' ) {
			my $qname = B::perlstring( $self->name );
			return
				eval
				"sub { my \$idx = 0; for (\@_) { Type::Tiny::_failed_check(\$type, $qname, \$_, varname => sprintf('\$_[%d]', \$idx)) unless ($inline); ++\$idx }; \@_; }";
		}
	} #/ if ( $func eq 'grep' ||...)
	
	if ( $func eq 'map' ) {
		my ( $inline, $compiled );
		my $c = $self->_assert_coercion;
		
		if ( $c->can_be_inlined ) {
			$inline = $c->inline_coercion( '$_' );
		}
		else {
			$compiled = $c->compiled_coercion;
			$inline   = '$compiled->($_)';
		}
		
		return eval "sub { map { $inline } \@_ }";
	} #/ if ( $func eq 'map' )
	
	if ( $func eq 'sort' || $func eq 'rsort' ) {
		my ( $inline, $compiled );
		
		my $ptype = $self->find_parent( sub { $_->has_sorter } );
		_croak "No sorter for this type constraint" unless $ptype;
		
		my $sorter = $ptype->sorter;
		
		# Schwarzian transformation
		if ( ref( $sorter ) eq 'ARRAY' ) {
			my $sort_key;
			( $sorter, $sort_key ) = @$sorter;
			
			if ( $func eq 'sort' ) {
				return
					eval
					"our (\$a, \$b); sub { map \$_->[0], sort { \$sorter->(\$a->[1],\$b->[1]) } map [\$_,\$sort_key->(\$_)], \@_ }";
			}
			elsif ( $func eq 'rsort' ) {
				return
					eval
					"our (\$a, \$b); sub { map \$_->[0], sort { \$sorter->(\$b->[1],\$a->[1]) } map [\$_,\$sort_key->(\$_)], \@_ }";
			}
		} #/ if ( ref( $sorter ) eq...)
		
		# Simple sort
		else {
			if ( $func eq 'sort' ) {
				return eval "our (\$a, \$b); sub { sort { \$sorter->(\$a,\$b) } \@_ }";
			}
			elsif ( $func eq 'rsort' ) {
				return eval "our (\$a, \$b); sub { sort { \$sorter->(\$b,\$a) } \@_ }";
			}
		}
	} #/ if ( $func eq 'sort' ||...)
	
	die "Unknown function: $func";
} #/ sub _build_util

sub of    { shift->parameterize( @_ ) }
sub where { shift->create_child_type( constraint => @_ ) }

# fill out Moose-compatible API
sub inline_environment        { +{} }
sub _inline_check             { shift->inline_check( @_ ) }
sub _compiled_type_constraint { shift->compiled_check( @_ ) }
sub meta { _croak( "Not really a Moose::Meta::TypeConstraint. Sorry!" ) }
sub compile_type_constraint           { shift->compiled_check }
sub _actually_compile_type_constraint { shift->_build_compiled_check }
sub hand_optimized_type_constraint { shift->{hand_optimized_type_constraint} }

sub has_hand_optimized_type_constraint {
	exists( shift->{hand_optimized_type_constraint} );
}
sub type_parameter { ( shift->parameters || [] )->[0] }

sub parameterized_from {
	$_[0]->is_parameterized ? shift->parent : _croak( "Not a parameterized type" );
}
sub has_parameterized_from { $_[0]->is_parameterized }

# some stuff for Mouse-compatible API
sub __is_parameterized      { shift->is_parameterized( @_ ) }
sub _add_type_coercions     { shift->coercion->add_type_coercions( @_ ) }
sub _as_string              { shift->qualified_name( @_ ) }
sub _compiled_type_coercion { shift->coercion->compiled_coercion( @_ ) }
sub _identity               { Scalar::Util::refaddr( shift ) }

sub _unite {
	require Type::Tiny::Union;
	"Type::Tiny::Union"->new( type_constraints => \@_ );
}

# Hooks for Type::Tie
sub TIESCALAR {
	require Type::Tie;
	unshift @_, 'Type::Tie::SCALAR';
	goto \&Type::Tie::SCALAR::TIESCALAR;
}

sub TIEARRAY {
	require Type::Tie;
	unshift @_, 'Type::Tie::ARRAY';
	goto \&Type::Tie::ARRAY::TIEARRAY;
}

sub TIEHASH {
	require Type::Tie;
	unshift @_, 'Type::Tie::HASH';
	goto \&Type::Tie::HASH::TIEHASH;
}

1;

__END__

=pod

=encoding utf-8

=for stopwords Moo(se)-compatible MooseX MouseX MooX Moose-compat invocant

=head1 NAME

Type::Tiny - tiny, yet Moo(se)-compatible type constraint

=head1 SYNOPSIS

 use v5.12;
 use strict;
 use warnings;
 
 package Horse {
   use Moo;
   use Types::Standard qw( Str Int Enum ArrayRef Object );
   use Type::Params qw( signature );
   use namespace::autoclean;
   
   has name => (
     is       => 'ro',
     isa      => Str,
     required => 1,
   );
   has gender => (
     is       => 'ro',
     isa      => Enum[qw( f m )],
   );
   has age => (
     is       => 'rw',
     isa      => Int->where( '$_ >= 0' ),
   );
   has children => (
     is       => 'ro',
     isa      => ArrayRef[Object],
     default  => sub { return [] },
   );
   
   sub add_child {
     state $check = signature(
       method     => Object,
       positional => [ Object ],
     );                                         # method signature
     my ( $self, $child ) = $check->( @_ );     # unpack @_
     
     push @{ $self->children }, $child;
     return $self;
   }
 }
 
 package main;
 
 my $boldruler = Horse->new(
   name    => "Bold Ruler",
   gender  => 'm',
   age     => 16,
 );
 
 my $secretariat = Horse->new(
   name    => "Secretariat",
   gender  => 'm',
   age     => 0,
 );
 
 $boldruler->add_child( $secretariat );

=head1 STATUS

This module is covered by the
L<Type-Tiny stability policy|Type::Tiny::Manual::Policies/"STABILITY">.

=head1 DESCRIPTION

This documents the internals of the L<Type::Tiny> class. L<Type::Tiny::Manual>
is a better starting place if you're new.

L<Type::Tiny> is a small class for creating Moose-like type constraint
objects which are compatible with Moo, Moose and Mouse.

   use Scalar::Util qw(looks_like_number);
   use Type::Tiny;
   
   my $NUM = "Type::Tiny"->new(
      name       => "Number",
      constraint => sub { looks_like_number($_) },
      message    => sub { "$_ ain't a number" },
   );
   
   package Ermintrude {
      use Moo;
      has favourite_number => (is => "ro", isa => $NUM);
   }
   
   package Bullwinkle {
      use Moose;
      has favourite_number => (is => "ro", isa => $NUM);
   }
   
   package Maisy {
      use Mouse;
      has favourite_number => (is => "ro", isa => $NUM);
   }

Type::Tiny conforms to L<Type::API::Constraint>,
L<Type::API::Constraint::Coercible>,
L<Type::API::Constraint::Constructor>, and
L<Type::API::Constraint::Inlinable>.

Maybe now we won't need to have separate MooseX, MouseX and MooX versions
of everything? We can but hope...

=head2 Constructor

=over

=item C<< new(%attributes) >>

Moose-style constructor function.

=back

=head2 Attributes

Attributes are named values that may be passed to the constructor. For
each attribute, there is a corresponding reader method. For example:

   my $type = Type::Tiny->new( name => "Foo" );
   print $type->name, "\n";   # says "Foo"

=head3 Important attributes

These are the attributes you are likely to be most interested in
providing when creating your own type constraints, and most interested
in reading when dealing with type constraint objects.

=over

=item C<< constraint >>

Coderef to validate a value (C<< $_ >>) against the type constraint.
The coderef will not be called unless the value is known to pass any
parent type constraint (see C<parent> below).

Alternatively, a string of Perl code checking C<< $_ >> can be passed
as a parameter to the constructor, and will be converted to a coderef.

Defaults to C<< sub { 1 } >> - i.e. a coderef that passes all values.

=item C<< parent >>

Optional attribute; parent type constraint. For example, an "Integer"
type constraint might have a parent "Number".

If provided, must be a Type::Tiny object.

=item C<< inlined >>

A coderef which returns a string of Perl code suitable for inlining this
type. Optional.

(The coderef will be called in list context and can actually return
a list of strings which will be joined with C<< && >>. If the first item
on the list is undef, it will be substituted with the type's parent's
inline check.)

If C<constraint> (above) is a coderef generated via L<Sub::Quote>, then
Type::Tiny I<may> be able to automatically generate C<inlined> for you.
If C<constraint> (above) is a string, it will be able to.

=item C<< name >>

The name of the type constraint. These need to conform to certain naming
rules (they must begin with an uppercase letter and continue using only
letters, digits 0-9 and underscores).

Optional; if not supplied will be an anonymous type constraint.

=item C<< display_name >>

A name to display for the type constraint when stringified. These don't
have to conform to any naming rules. Optional; a default name will be
calculated from the C<name>.

=item C<< library >>

The package name of the type library this type is associated with.
Optional. Informational only: setting this attribute does not install
the type into the package.

=item C<< deprecated >>

Optional boolean indicating whether a type constraint is deprecated.
L<Type::Library> will issue a warning if you attempt to import a deprecated
type constraint, but otherwise the type will continue to function as normal.
There will not be deprecation warnings every time you validate a value, for
instance. If omitted, defaults to the parent's deprecation status (or false
if there's no parent).

=item C<< message >>

Coderef that returns an error message when C<< $_ >> does not validate
against the type constraint. Optional (there's a vaguely sensible default.)

=item C<< coercion >>

A L<Type::Coercion> object associated with this type.

Generally speaking this attribute should not be passed to the constructor;
you should rely on the default lazily-built coercion object.

You may pass C<< coercion => 1 >> to the constructor to inherit coercions
from the constraint's parent. (This requires the parent constraint to have
a coercion.)

=item C<< sorter >>

A coderef which can be passed two values conforming to this type constraint
and returns -1, 0, or 1 to put them in order. Alternatively an arrayref
containing a pair of coderefs — a sorter and a pre-processor for the
Schwarzian transform. Optional.

The idea is to allow for:

  @sorted = Int->sort( 2, 1, 11 );    # => 1, 2, 11
  @sorted = Str->sort( 2, 1, 11 );    # => 1, 11, 2 

=item C<< type_default >>

A coderef which returns a sensible default value for this type. For example,
for a B<Counter> type, a sensible default might be "0":

  my $Size = Type::Tiny->new(
    name          => 'Size',
    parent        => Types::Standard::Enum[ qw( XS S M L XL ) ],
    type_default  => sub { return 'M'; },
  );
  
  package Tshirt {
    use Moo;
    has size => (
      is       => 'ro',
      isa      => $Size,
      default  => $Size->type_default,
    );
  }

Child types will inherit a type default from their parent unless the child
has a C<constraint>. If a type neither has nor inherits a type default, then
calling C<type_default> will return undef.

As a special case, this:

  $type->type_default( @args )

Will return:

  sub {
    local $_ = \@args;
    $type->type_default->( @_ );
  }

Many of the types defined in L<Types::Standard> and other bundled type
libraries have type defaults, but discovering them is left as an exercise
for the reader.

=item C<< my_methods >>

Experimental hashref of additional methods that can be called on the type
constraint object.

=back

=head3 Attributes related to parameterizable and parameterized types

The following additional attributes are used for parameterizable (e.g.
C<ArrayRef>) and parameterized (e.g. C<< ArrayRef[Int] >>) type
constraints. Unlike Moose, these aren't handled by separate subclasses.

=over

=item C<< constraint_generator >>

Coderef that is called when a type constraint is parameterized. When called,
it is passed the list of parameters, though any parameter which looks like a
foreign type constraint (Moose type constraints, Mouse type constraints, etc,
I<< and coderefs(!!!) >>) is first coerced to a native Type::Tiny object.

Note that for compatibility with the Moose API, the base type is I<not>
passed to the constraint generator, but can be found in the package variable
C<< $Type::Tiny::parameterize_type >>. The first parameter is also available
as C<< $_ >>.

Types I<can> be parameterized with an empty parameter list. For example,
in L<Types::Standard>, C<Tuple> is just an alias for C<ArrayRef> but
C<< Tuple[] >> will only allow zero-length arrayrefs to pass the constraint.
If you wish C<< YourType >> and C<< YourType[] >> to mean the same thing,
then do:

 return $Type::Tiny::parameterize_type unless @_;

The constraint generator should generate and return a new constraint coderef
based on the parameters. Alternatively, the constraint generator can return a
fully-formed Type::Tiny object, in which case the C<name_generator>,
C<inline_generator>, and C<coercion_generator> attributes documented below
are ignored.

Optional; providing a generator makes this type into a parameterizable
type constraint. If there is no generator, attempting to parameterize the
type constraint will throw an exception.

=item C<< name_generator >>

A coderef which generates a new display_name based on parameters. Called with
the same parameters and package variables as the C<constraint_generator>.
Expected to return a string.

Optional; the default is reasonable.

=item C<< inline_generator >>

A coderef which generates a new inlining coderef based on parameters. Called
with the same parameters and package variables as the C<constraint_generator>.
Expected to return a coderef.

Optional.

=item C<< coercion_generator >>

A coderef which generates a new L<Type::Coercion> object based on parameters.
Called with the same parameters and package variables as the
C<constraint_generator>. Expected to return a blessed object.

Optional.

=item C<< deep_explanation >>

This API is not finalized. Coderef used by L<Error::TypeTiny::Assertion> to
peek inside parameterized types and figure out why a value doesn't pass the
constraint.

=item C<< parameters >>

In parameterized types, returns an arrayref of the parameters.

=back

=head3 Lazy generated attributes

The following attributes should not be usually passed to the constructor;
unless you're doing something especially unusual, you should rely on the
default lazily-built return values.

=over

=item C<< compiled_check >>

Coderef to validate a value (C<< $_[0] >>) against the type constraint.
This coderef is expected to also handle all validation for the parent
type constraints.

=item C<< complementary_type >>

A complementary type for this type. For example, the complementary type
for an integer type would be all things that are not integers, including
floating point numbers, but also alphabetic strings, arrayrefs, filehandles,
etc.

=item C<< moose_type >>, C<< mouse_type >>

Objects equivalent to this type constraint, but as a
L<Moose::Meta::TypeConstraint> or L<Mouse::Meta::TypeConstraint>.

It should rarely be necessary to obtain a L<Moose::Meta::TypeConstraint>
object from L<Type::Tiny> because the L<Type::Tiny> object itself should
be usable pretty much anywhere a L<Moose::Meta::TypeConstraint> is expected.

=back

=head2 Methods

=head3 Predicate methods

These methods return booleans indicating information about the type
constraint. They are each tightly associated with a particular attribute.
(See L</"Attributes">.)

=over

=item C<has_parent>, C<has_library>, C<has_inlined>, C<has_constraint_generator>, C<has_inline_generator>, C<has_coercion_generator>, C<has_parameters>, C<has_message>, C<has_deep_explanation>, C<has_sorter>

Simple Moose-style predicate methods indicating the presence or
absence of an attribute.

=item C<has_coercion>

Predicate method with a little extra DWIM. Returns false if the coercion is
a no-op.

=item C<< is_anon >>

Returns true iff the type constraint does not have a C<name>.

=item C<< is_parameterized >>, C<< is_parameterizable >>

Indicates whether a type has been parameterized (e.g. C<< ArrayRef[Int] >>)
or could potentially be (e.g. C<< ArrayRef >>).

=item C<< has_parameterized_from >>

Useless alias for C<is_parameterized>.

=back

=head3 Validation and coercion

The following methods are used for coercing and validating values
against a type constraint:

=over

=item C<< check($value) >>

Returns true iff the value passes the type constraint.

=item C<< validate($value) >>

Returns the error message for the value; returns an explicit undef if the
value passes the type constraint.

=item C<< assert_valid($value) >>

Like C<< check($value) >> but dies if the value does not pass the type
constraint.

Yes, that's three very similar methods. Blame L<Moose::Meta::TypeConstraint>
whose API I'm attempting to emulate. :-)

=item C<< assert_return($value) >>

Like C<< assert_valid($value) >> but returns the value if it passes the type
constraint.

This seems a more useful behaviour than C<< assert_valid($value) >>. I would
have just changed C<< assert_valid($value) >> to do this, except that there
are edge cases where it could break Moose compatibility.

=item C<< get_message($value) >>

Returns the error message for the value; even if the value passes the type
constraint.

=item C<< validate_explain($value, $varname) >>

Like C<validate> but instead of a string error message, returns an arrayref
of strings explaining the reasoning why the value does not meet the type
constraint, examining parent types, etc.

The C<< $varname >> is an optional string like C<< '$foo' >> indicating the
name of the variable being checked.

=item C<< coerce($value) >>

Attempt to coerce C<< $value >> to this type.

=item C<< assert_coerce($value) >>

Attempt to coerce C<< $value >> to this type. Throws an exception if this is
not possible.

=back

=head3 Child type constraint creation and parameterization

These methods generate new type constraint objects that inherit from the
constraint they are called upon:

=over

=item C<< create_child_type(%attributes) >>

Construct a new Type::Tiny object with this object as its parent.

=item C<< where($coderef) >>

Shortcut for creating an anonymous child type constraint. Use it like
C<< HashRef->where(sub { exists($_->{name}) }) >>. That said, you can
get a similar result using overloaded C<< & >>:

   HashRef & sub { exists($_->{name}) }

Like the C<< constraint >> attribute, this will accept a string of Perl
code:

   HashRef->where('exists($_->{name})')

=item C<< child_type_class >>

The class that create_child_type will construct by default.

=item C<< parameterize(@parameters) >>

Creates a new parameterized type; throws an exception if called on a
non-parameterizable type.

=item C<< of(@parameters) >>

A cute alias for C<parameterize>. Use it like C<< ArrayRef->of(Int) >>.

=item C<< plus_coercions($type1, $code1, ...) >>

Shorthand for creating a new child type constraint with the same coercions
as this one, but then adding some extra coercions (at a higher priority than
the existing ones).

=item C<< plus_fallback_coercions($type1, $code1, ...) >>

Like C<plus_coercions>, but added at a lower priority.

=item C<< minus_coercions($type1, ...) >>

Shorthand for creating a new child type constraint with fewer type coercions.

=item C<< no_coercions >>

Shorthand for creating a new child type constraint with no coercions at all.

=back

=head3 Type relationship introspection methods

These methods allow you to determine a type constraint's relationship to
other type constraints in an organised hierarchy:

=over

=item C<< equals($other) >>, C<< is_subtype_of($other) >>, C<< is_supertype_of($other) >>, C<< is_a_type_of($other) >>

Compare two types. See L<Moose::Meta::TypeConstraint> for what these all mean.
(OK, Moose doesn't define C<is_supertype_of>, but you get the idea, right?)

Note that these have a slightly DWIM side to them. If you create two
L<Type::Tiny::Class> objects which test the same class, they're considered
equal. And:

   my $subtype_of_Num = Types::Standard::Num->create_child_type;
   my $subtype_of_Int = Types::Standard::Int->create_child_type;
   $subtype_of_Int->is_subtype_of( $subtype_of_Num );  # true

=item C<< strictly_equals($other) >>, C<< is_strictly_subtype_of($other) >>, C<< is_strictly_supertype_of($other) >>, C<< is_strictly_a_type_of($other) >>

Stricter versions of the type comparison functions. These only care about
explicit inheritance via C<parent>.

   my $subtype_of_Num = Types::Standard::Num->create_child_type;
   my $subtype_of_Int = Types::Standard::Int->create_child_type;
   $subtype_of_Int->is_strictly_subtype_of( $subtype_of_Num );  # false

=item C<< parents >>

Returns a list of all this type constraint's ancestor constraints. For
example, if called on the C<Str> type constraint would return the list
C<< (Value, Defined, Item, Any) >>.

I<< Due to a historical misunderstanding, this differs from the Moose
implementation of the C<parents> method. In Moose, C<parents> only returns the
immediate parent type constraints, and because type constraints only have
one immediate parent, this is effectively an alias for C<parent>. The
extension module L<MooseX::Meta::TypeConstraint::Intersection> is the only
place where multiple type constraints are returned; and they are returned
as an arrayref in violation of the base class' documentation. I'm keeping
my behaviour as it seems more useful. >>

=item C<< find_parent($coderef) >>

Loops through the parent type constraints I<< including the invocant
itself >> and returns the nearest ancestor type constraint where the
coderef evaluates to true. Within the coderef the ancestor currently
being checked is C<< $_ >>. Returns undef if there is no match.

In list context also returns the number of type constraints which had
been looped through before the matching constraint was found.

=item C<< find_constraining_type >>

Finds the nearest ancestor type constraint (including the type itself)
which has a C<constraint> coderef.

Equivalent to:

   $type->find_parent(sub { not $_->_is_null_constraint })

=item C<< coercibles >>

Return a type constraint which is the union of type constraints that can be
coerced to this one (including this one). If this type constraint has no
coercions, returns itself.

=item C<< type_parameter >>

In parameterized type constraints, returns the first item on the list of
parameters; otherwise returns undef. For example:

   ( ArrayRef[Int] )->type_parameter;    # returns Int
   ( ArrayRef[Int] )->parent;            # returns ArrayRef

Note that parameterizable type constraints can perfectly legitimately take
multiple parameters (several of the parameterizable type constraints in
L<Types::Standard> do). This method only returns the first such parameter.
L</"Attributes related to parameterizable and parameterized types">
documents the C<parameters> attribute, which returns an arrayref of all
the parameters.

=item C<< parameterized_from >>

Harder to spell alias for C<parent> that only works for parameterized
types.

=back

I<< Hint for people subclassing Type::Tiny: >>
Since version 1.006000, the methods for determining subtype, supertype, and
type equality should I<not> be overridden in subclasses of Type::Tiny. This
is because of the problem of diamond inheritance. If X and Y are both
subclasses of Type::Tiny, they I<both> need to be consulted to figure out
how type constraints are related; not just one of them should be overriding
these methods. See the source code for L<Type::Tiny::Enum> for an example of
how subclasses can give hints about type relationships to Type::Tiny.
Summary: push a coderef onto C<< @Type::Tiny::CMP >>. This coderef will be
passed two type constraints. It should then return one of the constants
Type::Tiny::CMP_SUBTYPE (first type is a subtype of second type),
Type::Tiny::CMP_SUPERTYPE (second type is a subtype of first type),
Type::Tiny::CMP_EQUAL (the two types are exactly the same),
Type::Tiny::CMP_EQUIVALENT (the two types are effectively the same), or
Type::Tiny::CMP_UNKNOWN (your coderef couldn't establish any relationship).

=head3 Type relationship introspection function

=over

=item C<< Type::Tiny::cmp($type1, $type2) >>

The subtype/supertype relationship between types results in a partial
ordering of type constraints.

This function will return one of the constants:
Type::Tiny::CMP_SUBTYPE (first type is a subtype of second type),
Type::Tiny::CMP_SUPERTYPE (second type is a subtype of first type),
Type::Tiny::CMP_EQUAL (the two types are exactly the same),
Type::Tiny::CMP_EQUIVALENT (the two types are effectively the same), or
Type::Tiny::CMP_UNKNOWN (couldn't establish any relationship).
In numeric contexts, these evaluate to -1, 1, 0, 0, and 0, making it
potentially usable with C<sort> (though you may need to silence warnings
about treating the empty string as a numeric value).

=back

=head3 List processing methods

=over

=item C<< grep(@list) >>

Filters a list to return just the items that pass the type check.

  @integers = Int->grep(@list);

=item C<< first(@list) >>

Filters the list to return the first item on the list that passes
the type check, or undef if none do.

  $first_lady = Woman->first(@people);

=item C<< map(@list) >>

Coerces a list of items. Only works on types which have a coercion.

  @truths = Bool->map(@list);

=item C<< sort(@list) >>

Sorts a list of items according to the type's preferred sorting mechanism,
or if the type doesn't have a sorter coderef, uses the parent type. If no
ancestor type constraint has a sorter, throws an exception. The C<Str>,
C<StrictNum>, C<LaxNum>, and C<Enum> type constraints include sorters.

  @sorted_numbers = Num->sort( Num->grep(@list) );

=item C<< rsort(@list) >>

Like C<sort> but backwards.

=item C<< any(@list) >>

Returns true if any of the list match the type.

  if ( Int->any(@numbers) ) {
    say "there was at least one integer";
  }

=item C<< all(@list) >>

Returns true if all of the list match the type.

  if ( Int->all(@numbers) ) {
    say "they were all integers";
  }

=item C<< assert_any(@list) >>

Like C<any> but instead of returning a boolean, returns the entire original
list if any item on it matches the type, and dies if none does.

=item C<< assert_all(@list) >>

Like C<all> but instead of returning a boolean, returns the original list if
all items on it match the type, but dies as soon as it finds one that does
not.

=back

=head3 Inlining methods

=for stopwords uated

The following methods are used to generate strings of Perl code which
may be pasted into stringy C<eval>uated subs to perform type checks:

=over

=item C<< can_be_inlined >>

Returns boolean indicating if this type can be inlined.

=item C<< inline_check($varname) >>

Creates a type constraint check for a particular variable as a string of
Perl code. For example:

   print( Types::Standard::Num->inline_check('$foo') );

prints the following output:

   (!ref($foo) && Scalar::Util::looks_like_number($foo))

For Moose-compat, there is an alias C<< _inline_check >> for this method.

=item C<< inline_assert($varname) >>

Much like C<inline_check> but outputs a statement of the form:

   ... or die ...;

Can also be called line C<< inline_assert($varname, $typevarname, %extras) >>.
In this case, it will generate a string of code that may include
C<< $typevarname >> which is supposed to be the name of a variable holding
the type itself. (This is kinda complicated, but it allows a useful string
to still be produced if the type is not inlineable.) The C<< %extras >> are
additional options to be passed to L<Error::TypeTiny::Assertion>'s constructor
and must be key-value pairs of strings only, no references or undefs.

=back

=head3 Other methods

=over

=item C<< qualified_name >>

For non-anonymous type constraints that have a library, returns a qualified
C<< "MyLib::MyType" >> sort of name. Otherwise, returns the same as C<name>.

=item C<< isa($class) >>, C<< can($method) >>, C<< AUTOLOAD(@args) >>

If Moose is loaded, then the combination of these methods is used to mock
a Moose::Meta::TypeConstraint.

If Mouse is loaded, then C<isa> mocks Mouse::Meta::TypeConstraint.

=item C<< DOES($role) >>

Overridden to advertise support for various roles.

See also L<Type::API::Constraint>, etc.

=item C<< TIESCALAR >>, C<< TIEARRAY >>, C<< TIEHASH >>

These are provided as hooks that wrap L<Type::Tie>. They allow the following
to work:

   use Types::Standard qw(Int);
   tie my @list, Int;
   push @list, 123, 456;   # ok
   push @list, "Hello";    # dies

=item C<< exportables( $base_name ) >>

Returns a list of the functions a type library should export if it contains
this type constraint.

Example:

  [
    { name => 'Int',        tags => [ 'types' ],  code => sub { ... } },
    { name => 'is_Int',     tags => [ 'is' ],     code => sub { ... } },
    { name => 'assert_Int', tags => [ 'assert' ], code => sub { ... } },
    { name => 'to_Int',     tags => [ 'to' ],     code => sub { ... } },
  ]

C<< $base_name >> is optional, but allows you to get a list of exportables
using a specific name. This is useful if the type constraint has a name
which wouldn't be a legal Perl function name.

=item C<< exportables_by_tag( $tag, $base_name ) >>

Filters C<exportables> by a specific tag name. In list context, returns all
matching exportables. In scalar context returns a single matching exportable
and dies if multiple exportables match, or none do!

=back

The following methods exist for Moose/Mouse compatibility, but do not do
anything useful.

=over

=item C<< compile_type_constraint >>

=item C<< hand_optimized_type_constraint >>

=item C<< has_hand_optimized_type_constraint >>

=item C<< inline_environment >>

=item C<< meta >>

=back

=head2 Overloading

=over

=item *

Stringification is overloaded to return the qualified name.

=item *

Boolification is overloaded to always return true.

=item *

Coderefification is overloaded to call C<assert_return>.

=item *

On Perl 5.10.1 and above, smart match is overloaded to call C<check>.

=item *

The C<< == >> operator is overloaded to call C<equals>.

=item *

The C<< < >> and C<< > >> operators are overloaded to call C<is_subtype_of>
and C<is_supertype_of>.

=item *

The C<< ~ >> operator is overloaded to call C<complementary_type>.

=item *

The C<< | >> operator is overloaded to build a union of two type constraints.
See L<Type::Tiny::Union>.

=item *

The C<< & >> operator is overloaded to build the intersection of two type
constraints. See L<Type::Tiny::Intersection>.

=item *

The C<< / >> operator provides magical L<Devel::StrictMode> support.
If C<< $ENV{PERL_STRICT} >> (or a few other environment variables) is true,
then it returns the left operand. Normally it returns the right operand.

=back

Previous versions of Type::Tiny would overload the C<< + >> operator to
call C<plus_coercions> or C<plus_fallback_coercions> as appropriate.
Support for this was dropped after 0.040.

=head2 Constants

=over

=item C<< Type::Tiny::SUPPORT_SMARTMATCH >>

Indicates whether the smart match overload is supported on your
version of Perl.

=back

=head2 Package Variables

=over

=item C<< $Type::Tiny::DD >>

This undef by default but may be set to a coderef that Type::Tiny
and related modules will use to dump data structures in things like
error messages.

Otherwise Type::Tiny uses it's own routine to dump data structures.
C<< $DD >> may then be set to a number to limit the lengths of the
dumps. (Default limit is 72.)

This is a package variable (rather than get/set class methods) to allow
for easy localization.

=item C<< $Type::Tiny::AvoidCallbacks >>

If this variable is set to true (you should usually do it in a
C<local> scope), it acts as a hint for type constraints, when
generating inlined code, to avoid making any callbacks to
variables and functions defined outside the inlined code itself.

This should have the effect that C<< $type->inline_check('$foo') >>
will return a string of code capable of checking the type on
Perl installations that don't have Type::Tiny installed. This
is intended to allow Type::Tiny to be used with things like
L<Mite>.

The variable works on the honour system. Types need to explicitly
check it and decide to generate different code based on its
truth value. The bundled types in L<Types::Standard>,
L<Types::Common::Numeric>, and L<Types::Common::String> all do.
(B<StrMatch> is sometimes unable to, and will issue a warning
if it needs to rely on callbacks when asked not to.)

Most normal users can ignore this.

=item C<< $Type::Tiny::SafePackage >>

This is the string "package Type::Tiny;" which is sometimes inserted
into strings of inlined code to avoid namespace clashes. In most cases,
you do not need to change this. However, if you are inlining type
constraint code, saving that code into Perl modules, and uploading them
to CPAN, you may wish to change it to avoid problems with the CPAN
indexer. Most normal users of Type::Tiny do not need to be aware of this.

=back

=head2 Environment

=over

=item C<PERL_TYPE_TINY_XS>

Currently this has more effect on L<Types::Standard> than Type::Tiny. In
future it may be used to trigger or suppress the loading XS implementations
of parts of Type::Tiny.

=back

=head1 BUGS

Please report any bugs to
L<https://github.com/tobyink/p5-type-tiny/issues>.

=head1 SEE ALSO

L<The Type::Tiny homepage|https://typetiny.toby.ink/>.

L<Type::Tiny::Manual>, L<Type::API>.

L<Type::Library>, L<Type::Utils>, L<Types::Standard>, L<Type::Coercion>.

L<Type::Tiny::Class>, L<Type::Tiny::Role>, L<Type::Tiny::Duck>,
L<Type::Tiny::Enum>, L<Type::Tiny::Union>, L<Type::Tiny::Intersection>.

L<Moose::Meta::TypeConstraint>,
L<Mouse::Meta::TypeConstraint>.

L<Type::Params>.

L<Type::Tiny on GitHub|https://github.com/tobyink/p5-type-tiny>,
L<Type::Tiny on Travis-CI|https://travis-ci.com/tobyink/p5-type-tiny>,
L<Type::Tiny on AppVeyor|https://ci.appveyor.com/project/tobyink/p5-type-tiny>,
L<Type::Tiny on Codecov|https://codecov.io/gh/tobyink/p5-type-tiny>,
L<Type::Tiny on Coveralls|https://coveralls.io/github/tobyink/p5-type-tiny>.

=head1 AUTHOR

Toby Inkster E<lt>tobyink@cpan.orgE<gt>.

=head1 THANKS

Thanks to Matt S Trout for advice on L<Moo> integration.

=head1 COPYRIGHT AND LICENCE

This software is copyright (c) 2013-2014, 2017-2022 by Toby Inkster.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=head1 DISCLAIMER OF WARRANTIES

THIS PACKAGE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.
