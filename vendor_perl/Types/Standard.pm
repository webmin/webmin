package Types::Standard;

use 5.008001;
use strict;
use warnings;

BEGIN {
	eval { require re };
	if ( $] < 5.010 ) { require Devel::TypeTiny::Perl58Compat }
}

BEGIN {
	$Types::Standard::AUTHORITY = 'cpan:TOBYINK';
	$Types::Standard::VERSION   = '2.000001';
}

$Types::Standard::VERSION =~ tr/_//d;

use Type::Library -base;

our @EXPORT_OK = qw( slurpy );

use Eval::TypeTiny  qw( set_subname );
use Scalar::Util    qw( blessed looks_like_number );
use Type::Tiny      ();
use Types::TypeTiny ();

my $is_class_loaded;

BEGIN {
	$is_class_loaded = q{sub {
		no strict 'refs';
		return !!0 if ref $_[0];
		return !!0 if not $_[0];
		return !!0 if ref(do { my $tmpstr = $_[0]; \$tmpstr }) ne 'SCALAR';
		my $stash = \%{"$_[0]\::"};
		return !!1 if exists($stash->{'ISA'}) && *{$stash->{'ISA'}}{ARRAY} && @{$_[0].'::ISA'};
		return !!1 if exists($stash->{'VERSION'});
		foreach my $globref (values %$stash) {
			return !!1
				if ref \$globref eq 'GLOB'
					? *{$globref}{CODE}
					: ref $globref; # const or sub ref
		}
		return !!0;
	}};
	
	*_is_class_loaded =
		Type::Tiny::_USE_XS
		? \&Type::Tiny::XS::Util::is_class_loaded
		: eval $is_class_loaded;
		
	*_HAS_REFUTILXS = eval {
		require Ref::Util::XS;
		Ref::Util::XS::->VERSION( 0.100 );
		1;
	}
		? sub () { !!1 }
		: sub () { !!0 };
} #/ BEGIN

my $add_core_type = sub {
	my $meta = shift;
	my ( $typedef ) = @_;
	
	my $name = $typedef->{name};
	my ( $xsub, $xsubname );
	
	# We want Map and Tuple to be XSified, even if they're not
	# really core.
	$typedef->{_is_core} = 1
		unless $name eq 'Map' || $name eq 'Tuple';
		
	if ( Type::Tiny::_USE_XS
		and not( $name eq 'RegexpRef' ) )
	{
		$xsub     = Type::Tiny::XS::get_coderef_for( $name );
		$xsubname = Type::Tiny::XS::get_subname_for( $name );
	}
	
	elsif ( Type::Tiny::_USE_MOUSE
		and not( $name eq 'RegexpRef' or $name eq 'Int' or $name eq 'Object' ) )
	{
		require Mouse::Util::TypeConstraints;
		$xsub     = "Mouse::Util::TypeConstraints"->can( $name );
		$xsubname = "Mouse::Util::TypeConstraints::$name" if $xsub;
	}
	
	if ( Type::Tiny::_USE_XS
		and Type::Tiny::XS->VERSION < 0.014
		and $name eq 'Bool' )
	{
		# Broken implementation of Bool
		$xsub = $xsubname = undef;
	}
	
	if ( Type::Tiny::_USE_XS
		and ( Type::Tiny::XS->VERSION < 0.016 or $] < 5.018 )
		and $name eq 'Int' )
	{
		# Broken implementation of Int
		$xsub = $xsubname = undef;
	}
	
	$typedef->{compiled_type_constraint} = $xsub if $xsub;
	
	my $orig_inlined = $typedef->{inlined};
	if (
		defined( $xsubname ) and (
		
			# These should be faster than their normal inlined
			# equivalents
			$name eq 'Str'
			or $name eq 'Bool'
			or $name eq 'ClassName'
			or $name eq 'RegexpRef'
			or $name eq 'FileHandle'
		)
		)
	{
		$typedef->{inlined} = sub {
			$Type::Tiny::AvoidCallbacks ? goto( $orig_inlined ) : "$xsubname\($_[1])";
		};
	} #/ if ( defined( $xsubname...))
	
	$meta->add_type( $typedef );
};

my $maybe_load_modules = sub {
	my $code = pop;
	if ( $Type::Tiny::AvoidCallbacks ) {
		$code = sprintf(
			'do { %s %s; %s }',
			$Type::Tiny::SafePackage,
			join( '; ', map "use $_ ()", @_ ),
			$code,
		);
	}
	$code;
};

sub _croak ($;@) { require Error::TypeTiny; goto \&Error::TypeTiny::croak }

my $meta = __PACKAGE__->meta;

# Stringable and LazyLoad are optimizations that complicate
# this module somewhat, but they have led to performance
# improvements. If Types::Standard wasn't such a key type
# library, I wouldn't use them. I strongly discourage anybody
# from using them in their own code. If you're looking for
# examples of how to write a type library sanely, you're
# better off looking at the code for Types::Common::Numeric
# and Types::Common::String.

{

	sub Stringable (&) {
		bless +{ code => $_[0] }, 'Types::Standard::_Stringable';
	}
	Types::Standard::_Stringable->Type::Tiny::_install_overloads(
		q[""] => sub { $_[0]{text} ||= $_[0]{code}->() } );
	
	sub LazyLoad ($$) {
		bless \@_, 'Types::Standard::LazyLoad';
	}
	'Types::Standard::LazyLoad'->Type::Tiny::_install_overloads(
		q[&{}] => sub {
			my ( $typename, $function ) = @{ $_[0] };
			my $type  = $meta->get_type( $typename );
			my $class = "Types::Standard::$typename";
			eval "require $class; 1" or die( $@ );
			
			# Majorly break encapsulation for Type::Tiny :-O
			for my $key ( keys %$type ) {
				next unless ref( $type->{$key} ) eq 'Types::Standard::LazyLoad';
				my $f = $type->{$key}[1];
				$type->{$key} = $class->can( "__$f" );
			}
			my $mm = $type->{my_methods} || {};
			for my $key ( keys %$mm ) {
				next unless ref( $mm->{$key} ) eq 'Types::Standard::LazyLoad';
				my $f = $mm->{$key}[1];
				$mm->{$key} = $class->can( "__$f" );
				set_subname(
					sprintf( "%s::my_%s", $type->qualified_name, $key ),
					$mm->{$key},
				);
			} #/ for my $key ( keys %$mm)
			return $class->can( "__$function" );
		},
	);
}

no warnings;

BEGIN {
	*STRICTNUM =
		$ENV{PERL_TYPES_STANDARD_STRICTNUM}
		? sub() { !!1 }
		: sub() { !!0 }
}

my $_any = $meta->$add_core_type(
	{
		name            => "Any",
		inlined         => sub { "!!1" },
		complement_name => 'None',
		type_default    => sub { return undef; },
	}
);

my $_item = $meta->$add_core_type(
	{
		name    => "Item",
		inlined => sub { "!!1" },
		parent  => $_any,
	}
);

my $_bool = $meta->$add_core_type(
	{
		name       => "Bool",
		parent     => $_item,
		constraint => sub {
			!ref $_ and ( !defined $_ or $_ eq q() or $_ eq '0' or $_ eq '1' );
		},
		inlined => sub {
			"!ref $_[1] and (!defined $_[1] or $_[1] eq q() or $_[1] eq '0' or $_[1] eq '1')";
		},
		type_default => sub { return !!0; },
	}
);

$_bool->coercion->add_type_coercions( $_any, q{!!$_} );

my $_undef = $meta->$add_core_type(
	{
		name       => "Undef",
		parent     => $_item,
		constraint => sub { !defined $_ },
		inlined    => sub { "!defined($_[1])" },
		type_default => sub { return undef; },
	}
);

my $_def = $meta->$add_core_type(
	{
		name               => "Defined",
		parent             => $_item,
		constraint         => sub { defined $_ },
		inlined            => sub { "defined($_[1])" },
		complementary_type => $_undef,
	}
);

# hackish, but eh
Scalar::Util::weaken( $_undef->{complementary_type} ||= $_def );

my $_val = $meta->$add_core_type(
	{
		name       => "Value",
		parent     => $_def,
		constraint => sub { not ref $_ },
		inlined    => sub { "defined($_[1]) and not ref($_[1])" },
	}
);

my $_str = $meta->$add_core_type(
	{
		name       => "Str",
		parent     => $_val,
		constraint => sub {
			ref( \$_ ) eq 'SCALAR' or ref( \( my $val = $_ ) ) eq 'SCALAR';
		},
		inlined    => sub {
			"defined($_[1]) and do { ref(\\$_[1]) eq 'SCALAR' or ref(\\(my \$val = $_[1])) eq 'SCALAR' }";
		},
		sorter     => sub { $_[0] cmp $_[1] },
		type_default => sub { return ''; },
	}
);

my $_laxnum = $meta->add_type(
	{
		name       => "LaxNum",
		parent     => $_str,
		constraint => sub { looks_like_number( $_ ) and ref( \$_ ) ne 'GLOB' },
		inlined    => sub {
			$maybe_load_modules->(
				qw/ Scalar::Util /,
				'Scalar::Util'->VERSION ge '1.18'    # RT 132426
				? "defined($_[1]) && !ref($_[1]) && Scalar::Util::looks_like_number($_[1])"
				: "defined($_[1]) && !ref($_[1]) && Scalar::Util::looks_like_number($_[1]) && ref(\\($_[1])) ne 'GLOB'"
			);
		},
		sorter     => sub { $_[0] <=> $_[1] },
		type_default => sub { return 0; },
	}
);

my $_strictnum = $meta->add_type(
	{
		name       => "StrictNum",
		parent     => $_str,
		constraint => sub {
			my $val = $_;
			( $val =~ /\A[+-]?[0-9]+\z/ )
				|| (
				$val =~ /\A(?:[+-]?)                #matches optional +- in the beginning
					(?=[0-9]|\.[0-9])                #matches previous +- only if there is something like 3 or .3
					[0-9]*                           #matches 0-9 zero or more times
					(?:\.[0-9]+)?                    #matches optional .89 or nothing
					(?:[Ee](?:[+-]?[0-9]+))?         #matches E1 or e1 or e-1 or e+1 etc
					\z/x
				);
		},
		inlined    => sub {
			'my $val = '
				. $_[1] . ';'
				. Value()->inline_check( '$val' )
				. ' && ( $val =~ /\A[+-]?[0-9]+\z/ || '
				. '$val =~ /\A(?:[+-]?)              # matches optional +- in the beginning
			(?=[0-9]|\.[0-9])                 # matches previous +- only if there is something like 3 or .3
			[0-9]*                            # matches 0-9 zero or more times
			(?:\.[0-9]+)?                     # matches optional .89 or nothing
			(?:[Ee](?:[+-]?[0-9]+))?          # matches E1 or e1 or e-1 or e+1 etc
		\z/x ); '
		},
		sorter     => sub { $_[0] <=> $_[1] },
		type_default => sub { return 0; },
	}
);

my $_num = $meta->add_type(
	{
		name   => "Num",
		parent => ( STRICTNUM ? $_strictnum : $_laxnum ),
	}
);

$meta->$add_core_type(
	{
		name       => "Int",
		parent     => $_num,
		constraint => sub { /\A-?[0-9]+\z/ },
		inlined    => sub {
			"do { my \$tmp = $_[1]; defined(\$tmp) and !ref(\$tmp) and \$tmp =~ /\\A-?[0-9]+\\z/ }";
		},
		type_default => sub { return 0; },
	}
);

my $_classn = $meta->add_type(
	{
		name       => "ClassName",
		parent     => $_str,
		constraint => \&_is_class_loaded,
		inlined    => sub {
			$Type::Tiny::AvoidCallbacks
				? "($is_class_loaded)->(do { my \$tmp = $_[1] })"
				: "Types::Standard::_is_class_loaded(do { my \$tmp = $_[1] })";
		},
	}
);

$meta->add_type(
	{
		name       => "RoleName",
		parent     => $_classn,
		constraint => sub { not $_->can( "new" ) },
		inlined    => sub {
			$Type::Tiny::AvoidCallbacks
				? "($is_class_loaded)->(do { my \$tmp = $_[1] }) and not $_[1]\->can('new')"
				: "Types::Standard::_is_class_loaded(do { my \$tmp = $_[1] }) and not $_[1]\->can('new')";
		},
	}
);

my $_ref = $meta->$add_core_type(
	{
		name                 => "Ref",
		parent               => $_def,
		constraint           => sub { ref $_ },
		inlined              => sub { "!!ref($_[1])" },
		constraint_generator => sub {
			return $meta->get_type( 'Ref' ) unless @_;
			
			my $reftype = shift;
			$reftype =~
				/^(SCALAR|ARRAY|HASH|CODE|REF|GLOB|LVALUE|FORMAT|IO|VSTRING|REGEXP|Regexp)$/i
				or _croak(
				"Parameter to Ref[`a] expected to be a Perl ref type; got $reftype" );
				
			$reftype = "$reftype";
			return sub {
				ref( $_[0] ) and Scalar::Util::reftype( $_[0] ) eq $reftype;
			}
		},
		inline_generator => sub {
			my $reftype = shift;
			return sub {
				my $v = $_[1];
				$maybe_load_modules->(
					qw/ Scalar::Util /,
					"ref($v) and Scalar::Util::reftype($v) eq q($reftype)"
				);
			};
		},
		deep_explanation => sub {
			require B;
			my ( $type, $value, $varname ) = @_;
			my $param = $type->parameters->[0];
			return if $type->check( $value );
			my $reftype = Scalar::Util::reftype( $value );
			return [
				sprintf(
					'"%s" constrains reftype(%s) to be equal to %s', $type, $varname,
					B::perlstring( $param )
				),
				sprintf(
					'reftype(%s) is %s', $varname,
					defined( $reftype ) ? B::perlstring( $reftype ) : "undef"
				),
			];
		},
	}
);

$meta->$add_core_type(
	{
		name       => "CodeRef",
		parent     => $_ref,
		constraint => sub { ref $_ eq "CODE" },
		inlined    => sub {
			_HAS_REFUTILXS && !$Type::Tiny::AvoidCallbacks
				? "Ref::Util::XS::is_plain_coderef($_[1])"
				: "ref($_[1]) eq 'CODE'";
		},
		type_default => sub { return sub {}; },
	}
);

my $_regexp = $meta->$add_core_type(
	{
		name       => "RegexpRef",
		parent     => $_ref,
		constraint => sub {
			ref( $_ ) && !!re::is_regexp( $_ ) or blessed( $_ ) && $_->isa( 'Regexp' );
		},
		inlined    => sub {
			my $v = $_[1];
			$maybe_load_modules->(
				qw/ Scalar::Util re /,
				"ref($v) && !!re::is_regexp($v) or Scalar::Util::blessed($v) && $v\->isa('Regexp')"
			);
		},
		type_default => sub { return qr//; },
	}
);

$meta->$add_core_type(
	{
		name       => "GlobRef",
		parent     => $_ref,
		constraint => sub { ref $_ eq "GLOB" },
		inlined    => sub {
			_HAS_REFUTILXS && !$Type::Tiny::AvoidCallbacks
				? "Ref::Util::XS::is_plain_globref($_[1])"
				: "ref($_[1]) eq 'GLOB'";
		},
	}
);

$meta->$add_core_type(
	{
		name       => "FileHandle",
		parent     => $_ref,
		constraint => sub {
			( ref( $_ ) && Scalar::Util::openhandle( $_ ) )
				or ( blessed( $_ ) && $_->isa( "IO::Handle" ) );
		},
		inlined => sub {
			$maybe_load_modules->(
				qw/ Scalar::Util /,
				"(ref($_[1]) && Scalar::Util::openhandle($_[1])) "
					. "or (Scalar::Util::blessed($_[1]) && $_[1]\->isa(\"IO::Handle\"))"
			);
		},
	}
);

my $_arr = $meta->$add_core_type(
	{
		name       => "ArrayRef",
		parent     => $_ref,
		constraint => sub { ref $_ eq "ARRAY" },
		inlined    => sub {
			_HAS_REFUTILXS && !$Type::Tiny::AvoidCallbacks
				? "Ref::Util::XS::is_plain_arrayref($_[1])"
				: "ref($_[1]) eq 'ARRAY'";
		},
		constraint_generator => LazyLoad( ArrayRef => 'constraint_generator' ),
		inline_generator     => LazyLoad( ArrayRef => 'inline_generator' ),
		deep_explanation     => LazyLoad( ArrayRef => 'deep_explanation' ),
		coercion_generator   => LazyLoad( ArrayRef => 'coercion_generator' ),
		type_default         => sub { return []; },
		type_default_generator => sub {
			return $Type::Tiny::parameterize_type->type_default if @_ < 2;
			return undef;
		},
	}
);

my $_hash = $meta->$add_core_type(
	{
		name       => "HashRef",
		parent     => $_ref,
		constraint => sub { ref $_ eq "HASH" },
		inlined    => sub {
			_HAS_REFUTILXS && !$Type::Tiny::AvoidCallbacks
				? "Ref::Util::XS::is_plain_hashref($_[1])"
				: "ref($_[1]) eq 'HASH'";
		},
		constraint_generator => LazyLoad( HashRef => 'constraint_generator' ),
		inline_generator     => LazyLoad( HashRef => 'inline_generator' ),
		deep_explanation     => LazyLoad( HashRef => 'deep_explanation' ),
		coercion_generator   => LazyLoad( HashRef => 'coercion_generator' ),
		type_default         => sub { return {}; },
		type_default_generator => sub {
			return $Type::Tiny::parameterize_type->type_default if @_ < 2;
			return undef;
		},
		my_methods           => {
			hashref_allows_key   => LazyLoad( HashRef => 'hashref_allows_key' ),
			hashref_allows_value => LazyLoad( HashRef => 'hashref_allows_value' ),
		},
	}
);

$meta->$add_core_type(
	{
		name                 => "ScalarRef",
		parent               => $_ref,
		constraint           => sub { ref $_ eq "SCALAR" or ref $_ eq "REF" },
		inlined              => sub { "ref($_[1]) eq 'SCALAR' or ref($_[1]) eq 'REF'" },
		constraint_generator => LazyLoad( ScalarRef => 'constraint_generator' ),
		inline_generator     => LazyLoad( ScalarRef => 'inline_generator' ),
		deep_explanation     => LazyLoad( ScalarRef => 'deep_explanation' ),
		coercion_generator   => LazyLoad( ScalarRef => 'coercion_generator' ),
		type_default         => sub { my $x; return \$x; },
	}
);

my $_obj = $meta->$add_core_type(
	{
		name       => "Object",
		parent     => $_ref,
		constraint => sub { blessed $_ },
		inlined    => sub {
			_HAS_REFUTILXS && !$Type::Tiny::AvoidCallbacks
				? "Ref::Util::XS::is_blessed_ref($_[1])"
				: $maybe_load_modules->(
				'Scalar::Util',
				"Scalar::Util::blessed($_[1])"
				);
		},
		is_object => 1,
	}
);

$meta->$add_core_type(
	{
		name                 => "Maybe",
		parent               => $_item,
		constraint_generator => sub {
			return $meta->get_type( 'Maybe' ) unless @_;
			
			my $param = Types::TypeTiny::to_TypeTiny( shift );
			Types::TypeTiny::is_TypeTiny( $param )
				or _croak(
				"Parameter to Maybe[`a] expected to be a type constraint; got $param" );
				
			my $param_compiled_check = $param->compiled_check;
			my @xsub;
			if ( Type::Tiny::_USE_XS ) {
				my $paramname = Type::Tiny::XS::is_known( $param_compiled_check );
				push @xsub, Type::Tiny::XS::get_coderef_for( "Maybe[$paramname]" )
					if $paramname;
			}
			elsif ( Type::Tiny::_USE_MOUSE and $param->_has_xsub ) {
				require Mouse::Util::TypeConstraints;
				my $maker = "Mouse::Util::TypeConstraints"->can( "_parameterize_Maybe_for" );
				push @xsub, $maker->( $param ) if $maker;
			}
			
			return (
				sub {
					my $value = shift;
					return !!1 unless defined $value;
					return $param->check( $value );
				},
				@xsub,
			);
		},
		inline_generator => sub {
			my $param = shift;
			
			my $param_compiled_check = $param->compiled_check;
			my $xsubname;
			if ( Type::Tiny::_USE_XS ) {
				my $paramname = Type::Tiny::XS::is_known( $param_compiled_check );
				$xsubname = Type::Tiny::XS::get_subname_for( "Maybe[$paramname]" );
			}
			
			return unless $param->can_be_inlined;
			return sub {
				my $v = $_[1];
				return "$xsubname\($v\)" if $xsubname && !$Type::Tiny::AvoidCallbacks;
				my $param_check = $param->inline_check( $v );
				"!defined($v) or $param_check";
			};
		},
		deep_explanation => sub {
			my ( $type, $value, $varname ) = @_;
			my $param = $type->parameters->[0];
			
			return [
				sprintf( '%s is defined', Type::Tiny::_dd( $value ) ),
				sprintf(
					'"%s" constrains the value with "%s" if it is defined', $type, $param
				),
				@{ $param->validate_explain( $value, $varname ) },
			];
		},
		coercion_generator => sub {
			my ( $parent, $child, $param ) = @_;
			return unless $param->has_coercion;
			return $param->coercion;
		},
		type_default       => sub { return undef; },
		type_default_generator => sub {
			$_[0]->type_default || $Type::Tiny::parameterize_type->type_default ;
		},
	}
);

my $_map = $meta->$add_core_type(
	{
		name                 => "Map",
		parent               => $_hash,
		constraint_generator => LazyLoad( Map => 'constraint_generator' ),
		inline_generator     => LazyLoad( Map => 'inline_generator' ),
		deep_explanation     => LazyLoad( Map => 'deep_explanation' ),
		coercion_generator   => LazyLoad( Map => 'coercion_generator' ),
		my_methods           => {
			hashref_allows_key   => LazyLoad( Map => 'hashref_allows_key' ),
			hashref_allows_value => LazyLoad( Map => 'hashref_allows_value' ),
		},
		type_default_generator => sub {
			return $Type::Tiny::parameterize_type->type_default;
		},
	}
);

my $_Optional = $meta->add_type(
	{
		name                 => "Optional",
		parent               => $_item,
		constraint_generator => sub {
			return $meta->get_type( 'Optional' ) unless @_;
			
			my $param = Types::TypeTiny::to_TypeTiny( shift );
			Types::TypeTiny::is_TypeTiny( $param )
				or _croak(
				"Parameter to Optional[`a] expected to be a type constraint; got $param" );
				
			sub { $param->check( $_[0] ) }
		},
		inline_generator => sub {
			my $param = shift;
			return unless $param->can_be_inlined;
			return sub {
				my $v = $_[1];
				$param->inline_check( $v );
			};
		},
		deep_explanation => sub {
			my ( $type, $value, $varname ) = @_;
			my $param = $type->parameters->[0];
			
			return [
				sprintf( '%s exists', $varname ),
				sprintf( '"%s" constrains %s with "%s" if it exists', $type, $varname, $param ),
				@{ $param->validate_explain( $value, $varname ) },
			];
		},
		coercion_generator => sub {
			my ( $parent, $child, $param ) = @_;
			return unless $param->has_coercion;
			return $param->coercion;
		},
		type_default_generator => sub {
			return $_[0]->type_default;
		},
	}
);

my $_slurpy;
$_slurpy = $meta->add_type(
	{
		name                 => "Slurpy",
		slurpy               => 1,
		parent               => $_item,
		constraint_generator => sub {
			my $self  = $_slurpy;
			my $param = @_ ? Types::TypeTiny::to_TypeTiny(shift) : $_any;
			Types::TypeTiny::is_TypeTiny( $param )
				or _croak(
				"Parameter to Slurpy[`a] expected to be a type constraint; got $param" );
			
			return $self->create_child_type(
				slurpy          => 1,
				display_name    => $self->name_generator->( $self, $param ),
				parameters      => [ $param ],
				constraint      => sub { $param->check( $_[0] ) },
				type_default    => $param->type_default,
				_build_coercion => sub {
					my $coercion = shift;
					$coercion->add_type_coercions( @{ $param->coercion->type_coercion_map } )
						if $param->has_coercion;
					$coercion->freeze;
				},
				$param->can_be_inlined
					? ( inlined => sub { $param->inline_check( $_[1] ) } )
					: (),
			);
		},
		deep_explanation => sub {
			my ( $type, $value, $varname ) = @_;
			my $param = $type->parameters->[0];
			return [
				sprintf( '%s is slurpy', $varname ),
				@{ $param->validate_explain( $value, $varname ) },
			];
		},
		my_methods => {
			'unslurpy' => sub {
				my $self  = shift;
				$self->{_my_unslurpy} ||= $self->find_parent(
					sub { $_->parent->{uniq} == $_slurpy->{uniq} }
				)->type_parameter;
			},
			'slurp_into' => sub {
				my $self  = shift;
				my $parameters = $self->find_parent(
					sub { $_->parent->{uniq} == $_slurpy->{uniq} }
				)->parameters;
				if ( $parameters->[1] ) {
					return $parameters->[1];
				}
				my $constraint = $parameters->[0];
				return 'HASH'
					if $constraint->is_a_type_of( HashRef() )
					or $constraint->is_a_type_of( Map() )
					or $constraint->is_a_type_of( Dict() );
				return 'ARRAY';
			},
		},
	}
);

sub slurpy {
	my $t = shift;
	my $s = $_slurpy->of( $t );
	$s->{slurpy} ||= 1;
	wantarray ? ( $s, @_ ) : $s;
}

$meta->$add_core_type(
	{
		name           => "Tuple",
		parent         => $_arr,
		name_generator => sub {
			my ( $s, @a ) = @_;
			sprintf( '%s[%s]', $s, join q[,], @a );
		},
		constraint_generator => LazyLoad( Tuple => 'constraint_generator' ),
		inline_generator     => LazyLoad( Tuple => 'inline_generator' ),
		deep_explanation     => LazyLoad( Tuple => 'deep_explanation' ),
		coercion_generator   => LazyLoad( Tuple => 'coercion_generator' ),
	}
);

$meta->add_type(
	{
		name           => "CycleTuple",
		parent         => $_arr,
		name_generator => sub {
			my ( $s, @a ) = @_;
			sprintf( '%s[%s]', $s, join q[,], @a );
		},
		constraint_generator => LazyLoad( CycleTuple => 'constraint_generator' ),
		inline_generator     => LazyLoad( CycleTuple => 'inline_generator' ),
		deep_explanation     => LazyLoad( CycleTuple => 'deep_explanation' ),
		coercion_generator   => LazyLoad( CycleTuple => 'coercion_generator' ),
	}
);

$meta->add_type(
	{
		name           => "Dict",
		parent         => $_hash,
		name_generator => sub {
			my ( $s, @p ) = @_;
			my $l = @p
				&& Types::TypeTiny::is_TypeTiny( $p[-1] )
				&& $p[-1]->is_strictly_a_type_of( Types::Standard::Slurpy() )
				? pop(@p)
				: undef;
			my %a = @p;
			sprintf(
				'%s[%s%s]', $s,
				join( q[,], map sprintf( "%s=>%s", $_, $a{$_} ), sort keys %a ),
				$l ? ",$l" : ''
			);
		},
		constraint_generator => LazyLoad( Dict => 'constraint_generator' ),
		inline_generator     => LazyLoad( Dict => 'inline_generator' ),
		deep_explanation     => LazyLoad( Dict => 'deep_explanation' ),
		coercion_generator   => LazyLoad( Dict => 'coercion_generator' ),
		my_methods           => {
			dict_is_slurpy       => LazyLoad( Dict => 'dict_is_slurpy' ),
			hashref_allows_key   => LazyLoad( Dict => 'hashref_allows_key' ),
			hashref_allows_value => LazyLoad( Dict => 'hashref_allows_value' ),
		},
	}
);

$meta->add_type(
	{
		name       => "Overload",
		parent     => $_obj,
		constraint => sub { require overload; overload::Overloaded( $_ ) },
		inlined    => sub {
			$maybe_load_modules->(
				qw/ Scalar::Util overload /,
				$INC{'overload.pm'}
				? "Scalar::Util::blessed($_[1]) and overload::Overloaded($_[1])"
				: "Scalar::Util::blessed($_[1]) and do { use overload (); overload::Overloaded($_[1]) }"
			);
		},
		constraint_generator => sub {
			return $meta->get_type( 'Overload' ) unless @_;
			
			my @operations = map {
				Types::TypeTiny::is_StringLike( $_ )
					? "$_"
					: _croak( "Parameters to Overload[`a] expected to be a strings; got $_" );
			} @_;
			
			require overload;
			return sub {
				my $value = shift;
				for my $op ( @operations ) {
					return unless overload::Method( $value, $op );
				}
				return !!1;
			}
		},
		inline_generator => sub {
			my @operations = @_;
			return sub {
				require overload;
				my $v = $_[1];
				$maybe_load_modules->(
					qw/ Scalar::Util overload /,
					join " and ",
					"Scalar::Util::blessed($v)",
					map "overload::Method($v, q[$_])", @operations
				);
			};
		},
		is_object => 1,
	}
);

$meta->add_type(
	{
		name                 => "StrMatch",
		parent               => $_str,
		constraint_generator => LazyLoad( StrMatch => 'constraint_generator' ),
		inline_generator     => LazyLoad( StrMatch => 'inline_generator' ),
	}
);

$meta->add_type(
	{
		name       => "OptList",
		parent     => $_arr,
		constraint => sub {
			for my $inner ( @$_ ) {
				return unless ref( $inner ) eq q(ARRAY);
				return unless @$inner == 2;
				return unless is_Str( $inner->[0] );
			}
			return !!1;
		},
		inlined => sub {
			my ( $self, $var ) = @_;
			my $Str_check = Str()->inline_check( '$inner->[0]' );
			my @code      = 'do { my $ok = 1; ';
			push @code, sprintf( 'for my $inner (@{%s}) { no warnings; ', $var );
			push @code,
				sprintf(
				'($ok=0) && last unless ref($inner) eq q(ARRAY) && @$inner == 2 && (%s); ',
				$Str_check
				);
			push @code, '} ';
			push @code, '$ok }';
			return ( undef, join( q( ), @code ) );
		},
		type_default => sub { return [] },
	}
);

$meta->add_type(
	{
		name       => "Tied",
		parent     => $_ref,
		constraint => sub {
			!!tied(
				Scalar::Util::reftype( $_ ) eq 'HASH'             ? %{$_}
				: Scalar::Util::reftype( $_ ) eq 'ARRAY'          ? @{$_}
				: Scalar::Util::reftype( $_ ) =~ /^(SCALAR|REF)$/ ? ${$_}
				:                                                   undef
			);
		},
		inlined => sub {
			my ( $self, $var ) = @_;
			$maybe_load_modules->(
				qw/ Scalar::Util /,
				$self->parent->inline_check( $var )
					. " and !!tied(Scalar::Util::reftype($var) eq 'HASH' ? \%{$var} : Scalar::Util::reftype($var) eq 'ARRAY' ? \@{$var} : Scalar::Util::reftype($var) =~ /^(SCALAR|REF)\$/ ? \${$var} : undef)"
			);
		},
		name_generator => sub {
			my $self  = shift;
			my $param = Types::TypeTiny::to_TypeTiny( shift );
			unless ( Types::TypeTiny::is_TypeTiny( $param ) ) {
				Types::TypeTiny::is_StringLike( $param )
					or _croak( "Parameter to Tied[`a] expected to be a class name; got $param" );
				require B;
				return sprintf( "%s[%s]", $self, B::perlstring( $param ) );
			}
			return sprintf( "%s[%s]", $self, $param );
		},
		constraint_generator => LazyLoad( Tied => 'constraint_generator' ),
		inline_generator     => LazyLoad( Tied => 'inline_generator' ),
	}
);

$meta->add_type(
	{
		name                 => "InstanceOf",
		parent               => $_obj,
		constraint_generator => sub {
			return $meta->get_type( 'InstanceOf' ) unless @_;
			require Type::Tiny::Class;
			my @classes = map {
				Types::TypeTiny::is_TypeTiny( $_ )
					? $_
					: "Type::Tiny::Class"->new(
					class        => $_,
					display_name => sprintf( 'InstanceOf[%s]', B::perlstring( $_ ) )
					)
			} @_;
			return $classes[0] if @classes == 1;
			
			require B;
			require Type::Tiny::Union;
			return "Type::Tiny::Union"->new(
				type_constraints => \@classes,
				display_name     => sprintf(
					'InstanceOf[%s]', join q[,], map B::perlstring( $_->class ), @classes
				),
			);
		},
	}
);

$meta->add_type(
	{
		name                 => "ConsumerOf",
		parent               => $_obj,
		constraint_generator => sub {
			return $meta->get_type( 'ConsumerOf' ) unless @_;
			require B;
			require Type::Tiny::Role;
			my @roles = map {
				Types::TypeTiny::is_TypeTiny( $_ )
					? $_
					: "Type::Tiny::Role"->new(
					role         => $_,
					display_name => sprintf( 'ConsumerOf[%s]', B::perlstring( $_ ) )
					)
			} @_;
			return $roles[0] if @roles == 1;
			
			require Type::Tiny::Intersection;
			return "Type::Tiny::Intersection"->new(
				type_constraints => \@roles,
				display_name     => sprintf(
					'ConsumerOf[%s]', join q[,], map B::perlstring( $_->role ), @roles
				),
			);
		},
	}
);

$meta->add_type(
	{
		name                 => "HasMethods",
		parent               => $_obj,
		constraint_generator => sub {
			return $meta->get_type( 'HasMethods' ) unless @_;
			require B;
			require Type::Tiny::Duck;
			return "Type::Tiny::Duck"->new(
				methods      => \@_,
				display_name =>
					sprintf( 'HasMethods[%s]', join q[,], map B::perlstring( $_ ), @_ ),
			);
		},
	}
);

$meta->add_type(
	{
		name                 => "Enum",
		parent               => $_str,
		constraint_generator => sub {
			return $meta->get_type( 'Enum' ) unless @_;
			my $coercion;
			if ( ref( $_[0] ) and ref( $_[0] ) eq 'SCALAR' ) {
				$coercion = ${ +shift };
			}
			elsif ( ref( $_[0] ) && !blessed( $_[0] )
				or blessed( $_[0] ) && $_[0]->isa( 'Type::Coercion' ) )
			{
				$coercion = shift;
			}
			require B;
			require Type::Tiny::Enum;
			return "Type::Tiny::Enum"->new(
				values       => \@_,
				display_name => sprintf( 'Enum[%s]', join q[,], map B::perlstring( $_ ), @_ ),
				$coercion ? ( coercion => $coercion ) : (),
			);
		},
		type_default => undef,
	}
);

$meta->add_coercion(
	{
		name              => "MkOpt",
		type_constraint   => $meta->get_type( "OptList" ),
		type_coercion_map => [
			$_arr,   q{ Exporter::Tiny::mkopt($_) },
			$_hash,  q{ Exporter::Tiny::mkopt($_) },
			$_undef, q{ [] },
		],
	}
);

$meta->add_coercion(
	{
		name               => "Join",
		type_constraint    => $_str,
		coercion_generator => sub {
			my ( $self, $target, $sep ) = @_;
			Types::TypeTiny::is_StringLike( $sep )
				or _croak( "Parameter to Join[`a] expected to be a string; got $sep" );
			require B;
			$sep = B::perlstring( $sep );
			return ( ArrayRef(), qq{ join($sep, \@\$_) } );
		},
	}
);

$meta->add_coercion(
	{
		name               => "Split",
		type_constraint    => $_arr,
		coercion_generator => sub {
			my ( $self, $target, $re ) = @_;
			ref( $re ) eq q(Regexp)
				or _croak(
				"Parameter to Split[`a] expected to be a regular expresssion; got $re" );
			my $regexp_string = "$re";
			$regexp_string =~ s/\\\//\\\\\//g;    # toothpicks
			return ( Str(), qq{ [split /$regexp_string/, \$_] } );
		},
	}
);

__PACKAGE__->meta->make_immutable;

1;

__END__

=pod

=for stopwords booleans vstrings typeglobs

=encoding utf-8

=for stopwords datetimes

=head1 NAME

Types::Standard - bundled set of built-in types for Type::Tiny

=head1 SYNOPSIS

 use v5.12;
 use strict;
 use warnings;
 
 package Horse {
   use Moo;
   use Types::Standard qw( Str Int Enum ArrayRef Object );
   use Type::Params qw( compile );
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
 
 use Types::Standard qw( is_Object assert_Object );
 
 # is_Object($thing) returns a boolean
 my $is_it_an_object = is_Object($boldruler);
 
 # assert_Object($thing) returns $thing or dies
 say assert_Object($boldruler)->name;  # says "Bold Ruler"

=head1 STATUS

This module is covered by the
L<Type-Tiny stability policy|Type::Tiny::Manual::Policies/"STABILITY">.

=head1 DESCRIPTION

This documents the details of the L<Types::Standard> type library.
L<Type::Tiny::Manual> is a better starting place if you're new.

L<Type::Tiny> bundles a few types which seem to be useful.

=head2 Moose-like

The following types are similar to those described in
L<Moose::Util::TypeConstraints>.

=over

=item *

B<< Any >>

Absolutely any value passes this type constraint (even undef).

=item *

B<< Item >>

Essentially the same as B<Any>. All other type constraints in this library
inherit directly or indirectly from B<Item>.

=item *

B<< Bool >>

Values that are reasonable booleans. Accepts 1, 0, the empty string and
undef.

=item *

B<< Maybe[`a] >>

Given another type constraint, also accepts undef. For example,
B<< Maybe[Int] >> accepts all integers plus undef.

=item *

B<< Undef >>

Only undef passes this type constraint.

=item *

B<< Defined >>

Only undef fails this type constraint.

=item *

B<< Value >>

Any defined, non-reference value.

=item *

B<< Str >>

Any string.

(The only difference between B<Value> and B<Str> is that the former accepts
typeglobs and vstrings.)

Other customers also bought: B<< StringLike >> from L<Types::TypeTiny>.

=item *

B<< Num >>

See B<LaxNum> and B<StrictNum> below.

=item *

B<< Int >>

An integer; that is a string of digits 0 to 9, optionally prefixed with a
hyphen-minus character.

Expect inconsistent results for dualvars, and numbers too high (or negative
numbers too low) for Perl to safely represent as an integer.

=item *

B<< ClassName >>

The name of a loaded package. The package must have C<< @ISA >> or
C<< $VERSION >> defined, or must define at least one sub to be considered
a loaded package.

=item *

B<< RoleName >>

Like B<< ClassName >>, but the package must I<not> define a method called
C<new>. This is subtly different from Moose's type constraint of the same
name; let me know if this causes you any problems. (I can't promise I'll
change anything though.)

=item *

B<< Ref[`a] >>

Any defined reference value, including blessed objects.

Unlike Moose, B<Ref> is a parameterized type, allowing Scalar::Util::reftype
checks, a la

   Ref["HASH"]  # hashrefs, including blessed hashrefs

=item *

B<< ScalarRef[`a] >>

A value where C<< ref($value) eq "SCALAR" or ref($value) eq "REF" >>.

If parameterized, the referred value must pass the additional constraint.
For example, B<< ScalarRef[Int] >> must be a reference to a scalar which
holds an integer value.

=item *

B<< ArrayRef[`a] >>

A value where C<< ref($value) eq "ARRAY" >>.

If parameterized, the elements of the array must pass the additional
constraint. For example, B<< ArrayRef[Num] >> must be a reference to an
array of numbers.

As an extension to Moose's B<ArrayRef> type, a minimum and maximum array
length can be given:

   ArrayRef[CodeRef, 1]        # ArrayRef of at least one CodeRef
   ArrayRef[FileHandle, 0, 2]  # ArrayRef of up to two FileHandles
   ArrayRef[Any, 0, 100]       # ArrayRef of up to 100 elements

Other customers also bought: B<< ArrayLike >> from L<Types::TypeTiny>.

=item *

B<< HashRef[`a] >>

A value where C<< ref($value) eq "HASH" >>.

If parameterized, the values of the hash must pass the additional
constraint. For example, B<< HashRef[Num] >> must be a reference to an
hash where the values are numbers. The hash keys are not constrained,
but Perl limits them to strings; see B<Map> below if you need to further
constrain the hash values.

Other customers also bought: B<< HashLike >> from L<Types::TypeTiny>.

=item *

B<< CodeRef >>

A value where C<< ref($value) eq "CODE" >>.

Other customers also bought: B<< CodeLike >> from L<Types::TypeTiny>.

=item *

B<< RegexpRef >>

A reference where C<< re::is_regexp($value) >> is true, or
a blessed reference where C<< $value->isa("Regexp") >> is true.

=item *

B<< GlobRef >>

A value where C<< ref($value) eq "GLOB" >>.

=item *

B<< FileHandle >>

A file handle.

=item *

B<< Object >>

A blessed object.

(This also accepts regexp refs.)

=back

=head2 Structured

Okay, so I stole some ideas from L<MooseX::Types::Structured>.

=over

=item *

B<< Map[`k, `v] >>

Similar to B<HashRef> but parameterized with type constraints for both the
key and value. The constraint for keys would typically be a subtype of
B<Str>.

=item *

B<< Tuple[...] >>

Subtype of B<ArrayRef>, accepting a list of type constraints for
each slot in the array.

B<< Tuple[Int, HashRef] >> would match C<< [1, {}] >> but not C<< [{}, 1] >>.

=item *

B<< Dict[...] >>

Subtype of B<HashRef>, accepting a list of type constraints for
each slot in the hash.

For example B<< Dict[name => Str, id => Int] >> allows
C<< { name => "Bob", id => 42 } >>.

=item *

B<< Optional[`a] >>

Used in conjunction with B<Dict> and B<Tuple> to specify slots that are
optional and may be omitted (but not necessarily set to an explicit undef).

B<< Dict[name => Str, id => Optional[Int]] >> allows C<< { name => "Bob" } >>
but not C<< { name => "Bob", id => "BOB" } >>.

Note that any use of B<< Optional[`a] >> outside the context of
parameterized B<Dict> and B<Tuple> type constraints makes little sense,
and its behaviour is undefined. (An exception: it is used by
L<Type::Params> for a similar purpose to how it's used in B<Tuple>.)

=back

This module also exports a B<Slurpy> parameterized type, which can be
used as follows.

It can cause additional trailing values in a B<Tuple> to be slurped
into a structure and validated. For example, slurping into an arrayref:

   my $type = Tuple[ Str, Slurpy[ ArrayRef[Int] ] ];
   
   $type->( ["Hello"] );                # ok
   $type->( ["Hello", 1, 2, 3] );       # ok
   $type->( ["Hello", [1, 2, 3]] );     # not ok

Or into a hashref:

   my $type2 = Tuple[ Str, Slurpy[ Map[Int, RegexpRef] ] ];
   
   $type2->( ["Hello"] );                               # ok
   $type2->( ["Hello", 1, qr/one/i, 2, qr/two/] );      # ok

It can cause additional values in a B<Dict> to be slurped into a
hashref and validated:

   my $type3 = Dict[ values => ArrayRef, Slurpy[ HashRef[Str] ] ];
   
   $type3->( { values => [] } );                        # ok
   $type3->( { values => [], name => "Foo" } );         # ok
   $type3->( { values => [], name => [] } );            # not ok

In either B<Tuple> or B<Dict>, B<< Slurpy[Any] >> can be used to indicate
that additional values are acceptable, but should not be constrained in
any way. 

B<< Slurpy[Any] >> is an optimized code path. Although the following are
essentially equivalent checks, the former should run a lot faster:

   Tuple[ Int, Slurpy[Any] ]
   Tuple[ Int, Slurpy[ArrayRef] ]

A function C<< slurpy($type) >> is also exported which was historically
how slurpy types were created.

Outside of B<Dict> and B<Tuple>, B<< Slurpy[Foo] >> should just act the
same as B<Foo>. But don't do that.

=begin trustme

=item slurpy

=end trustme

=head2 Objects

Okay, so I stole some ideas from L<MooX::Types::MooseLike::Base>.

=over

=item *

B<< InstanceOf[`a] >>

Shortcut for a union of L<Type::Tiny::Class> constraints.

B<< InstanceOf["Foo", "Bar"] >> allows objects blessed into the C<Foo>
or C<Bar> classes, or subclasses of those.

Given no parameters, just equivalent to B<Object>.

=item *

B<< ConsumerOf[`a] >>

Shortcut for an intersection of L<Type::Tiny::Role> constraints.

B<< ConsumerOf["Foo", "Bar"] >> allows objects where C<< $o->DOES("Foo") >>
and C<< $o->DOES("Bar") >> both return true.

Given no parameters, just equivalent to B<Object>.

=item *

B<< HasMethods[`a] >>

Shortcut for a L<Type::Tiny::Duck> constraint.

B<< HasMethods["foo", "bar"] >> allows objects where C<< $o->can("foo") >>
and C<< $o->can("bar") >> both return true.

Given no parameters, just equivalent to B<Object>.

=back

=head2 More

There are a few other types exported by this module:

=over

=item *

B<< Overload[`a] >>

With no parameters, checks that the value is an overloaded object. Can
be given one or more string parameters, which are specific operations
to check are overloaded. For example, the following checks for objects
which overload addition and subtraction.

   Overload["+", "-"]

=item *

B<< Tied[`a] >>

A reference to a tied scalar, array or hash.

Can be parameterized with a type constraint which will be applied to
the object returned by the C<< tied() >> function. As a convenience,
can also be parameterized with a string, which will be inflated to a
L<Type::Tiny::Class>.

   use Types::Standard qw(Tied);
   use Type::Utils qw(class_type);
   
   my $My_Package = class_type { class => "My::Package" };
   
   tie my %h, "My::Package";
   \%h ~~ Tied;                   # true
   \%h ~~ Tied[ $My_Package ];    # true
   \%h ~~ Tied["My::Package"];    # true
   
   tie my $s, "Other::Package";
   \$s ~~ Tied;                   # true
   $s  ~~ Tied;                   # false !!

If you need to check that something is specifically a reference to
a tied hash, use an intersection:

   use Types::Standard qw( Tied HashRef );
   
   my $TiedHash = (Tied) & (HashRef);
   
   tie my %h, "My::Package";
   tie my $s, "Other::Package";
   
   \%h ~~ $TiedHash;     # true
   \$s ~~ $TiedHash;     # false

=item *

B<< StrMatch[`a] >>

A string that matches a regular expression:

   declare "Distance",
      as StrMatch[ qr{^([0-9]+)\s*(mm|cm|m|km)$} ];

You can optionally provide a type constraint for the array of subexpressions:

   declare "Distance",
      as StrMatch[
         qr{^([0-9]+)\s*(.+)$},
         Tuple[
            Int,
            enum(DistanceUnit => [qw/ mm cm m km /]),
         ],
      ];

Here's an example using L<Regexp::Common>:

   package Local::Host {
      use Moose;
      use Regexp::Common;
      has ip_address => (
         is         => 'ro',
         required   => 1,
         isa        => StrMatch[qr/^$RE{net}{IPv4}$/],
         default    => '127.0.0.1',
      );
   }

On certain versions of Perl, type constraints of the forms
B<< StrMatch[qr/../ >> and B<< StrMatch[qr/\A..\z/ >> with any number
of intervening dots can be optimized to simple length checks.

=item *

B<< Enum[`a] >>

As per MooX::Types::MooseLike::Base:

   has size => (
      is     => "ro",
      isa    => Enum[qw( S M L XL XXL )],
   );

You can enable coercion by passing C<< \1 >> before the list of values.

   has size => (
      is     => "ro",
      isa    => Enum[ \1, qw( S M L XL XXL ) ],
      coerce => 1,
   );

This will use the C<closest_match> method in L<Type::Tiny::Enum> to
coerce closely matching strings.

=item *

B<< OptList >>

An arrayref of arrayrefs in the style of L<Data::OptList> output.

=item *

B<< LaxNum >>, B<< StrictNum >>

In Moose 2.09, the B<Num> type constraint implementation was changed from
being a wrapper around L<Scalar::Util>'s C<looks_like_number> function to
a stricter regexp (which disallows things like "-Inf" and "Nan").

Types::Standard provides I<both> implementations. B<LaxNum> is measurably
faster.

The B<Num> type constraint is currently an alias for B<LaxNum> unless you
set the C<PERL_TYPES_STANDARD_STRICTNUM> environment variable to true before
loading Types::Standard, in which case it becomes an alias for B<StrictNum>.
The constant C<< Types::Standard::STRICTNUM >> can be used to check if
B<Num> is being strict.

Most people should probably use B<Num> or B<StrictNum>. Don't explicitly
use B<LaxNum> unless you specifically need an attribute which will accept
things like "Inf".

=item *

B<< CycleTuple[`a] >>

Similar to B<Tuple>, but cyclical.

   CycleTuple[Int, HashRef]

will allow C<< [1,{}] >> and C<< [1,{},2,{}] >> but disallow
C<< [1,{},2] >> and C<< [1,{},2,[]] >>.

I think you understand B<CycleTuple> already.

Currently B<Optional> and B<Slurpy> parameters are forbidden. There are
fairly limited use cases for them, and it's not exactly clear what they
should mean.

The following is an efficient way of checking for an even-sized arrayref:

   CycleTuple[Any, Any]

The following is an arrayref which would be suitable for coercing to a
hashref:

   CycleTuple[Str, Any]

All the examples so far have used two parameters, but the following is
also a possible B<CycleTuple>:

   CycleTuple[Str, Int, HashRef]

This will be an arrayref where the 0th, 3rd, 6th, etc values are
strings, the 1st, 4th, 7th, etc values are integers, and the 2nd,
5th, 8th, etc values are hashrefs.

=back

=head2 Coercions

Most of the types in this type library have no coercions by default.
The exception is B<Bool> as of Types::Standard 1.003_003, which coerces
from B<Any> via C<< !!$_ >>.

Some standalone coercions may be exported. These can be combined
with type constraints using the C<< plus_coercions >> method.

=over

=item *

B<< MkOpt >>

A coercion from B<ArrayRef>, B<HashRef> or B<Undef> to B<OptList>. Example
usage in a Moose attribute:

   use Types::Standard qw( OptList MkOpt );
   
   has options => (
      is     => "ro",
      isa    => OptList->plus_coercions( MkOpt ),
      coerce => 1,
   );

=item *

B<< Split[`a] >>

Split a string on a regexp.

   use Types::Standard qw( ArrayRef Str Split );
   
   has name => (
      is     => "ro",
      isa    => ArrayRef->of(Str)->plus_coercions(Split[qr/\s/]),
      coerce => 1,
   );

=item *

B<< Join[`a] >>

Join an array of strings with a delimiter.

   use Types::Standard qw( Str Join );
   
   my $FileLines = Str->plus_coercions(Join["\n"]);
   
   has file_contents => (
      is     => "ro",
      isa    => $FileLines,
      coerce => 1,
   );

=back

=head2 Constants

=over

=item C<< Types::Standard::STRICTNUM >>

Indicates whether B<Num> is an alias for B<StrictNum>. (It is usually an
alias for B<LaxNum>.)

=back

=head2 Environment

=over

=item C<PERL_TYPES_STANDARD_STRICTNUM>

Switches to more strict regexp-based number checking instead of using
C<looks_like_number>.

=item C<PERL_TYPE_TINY_XS>

If set to false, can be used to suppress the loading of XS implementions of
some type constraints.

=item C<PERL_ONLY>

If C<PERL_TYPE_TINY_XS> does not exist, can be set to true to suppress XS
usage similarly. (Several other CPAN distributions also pay attention to this
environment variable.)

=back

=begin private

=item Stringable

=item LazyLoad

=end private

=head1 BUGS

Please report any bugs to
L<https://github.com/tobyink/p5-type-tiny/issues>.

=head1 SEE ALSO

L<The Type::Tiny homepage|https://typetiny.toby.ink/>.

L<Type::Tiny::Manual>.

L<Type::Tiny>, L<Type::Library>, L<Type::Utils>, L<Type::Coercion>.

L<Moose::Util::TypeConstraints>,
L<Mouse::Util::TypeConstraints>,
L<MooseX::Types::Structured>.

L<Types::XSD> provides some type constraints based on XML Schema's data
types; this includes constraints for ISO8601-formatted datetimes, integer
ranges (e.g. B<< PositiveInteger[maxInclusive=>10] >> and so on.

L<Types::Encodings> provides B<Bytes> and B<Chars> type constraints that
were formerly found in Types::Standard.

L<Types::Common::Numeric> and L<Types::Common::String> provide replacements
for L<MooseX::Types::Common>.

=head1 AUTHOR

Toby Inkster E<lt>tobyink@cpan.orgE<gt>.

=head1 COPYRIGHT AND LICENCE

This software is copyright (c) 2013-2014, 2017-2022 by Toby Inkster.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=head1 DISCLAIMER OF WARRANTIES

THIS PACKAGE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.
