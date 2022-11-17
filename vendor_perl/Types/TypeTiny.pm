package Types::TypeTiny;

use 5.008001;
use strict;
use warnings;

our $AUTHORITY = 'cpan:TOBYINK';
our $VERSION   = '2.000001';

$VERSION =~ tr/_//d;

use Scalar::Util qw< blessed refaddr weaken >;

BEGIN {
	*__XS = eval {
		require Type::Tiny::XS;
		'Type::Tiny::XS'->VERSION( '0.022' );
		1;
	}
		? sub () { !!1 }
		: sub () { !!0 };
}

our @EXPORT_OK = (
	map( @{ [ $_, "is_$_", "assert_$_" ] }, __PACKAGE__->type_names ),
	qw/to_TypeTiny/
);
our %EXPORT_TAGS = (
	types  => [ __PACKAGE__->type_names ],
	is     => [ map "is_$_",     __PACKAGE__->type_names ],
	assert => [ map "assert_$_", __PACKAGE__->type_names ],
);

my %cache;

# This `import` method is designed to avoid loading Exporter::Tiny.
# This is so that if you stick to only using the purely OO parts of
# Type::Tiny, you can skip loading the exporter.
#
sub import {

	# If this sub succeeds, it will replace itself.
	# uncoverable subroutine
	return unless @_ > 1;                               # uncoverable statement
	no warnings "redefine";                             # uncoverable statement
	our @ISA = qw( Exporter::Tiny );                    # uncoverable statement
	require Exporter::Tiny;                             # uncoverable statement
	my $next = \&Exporter::Tiny::import;                # uncoverable statement
	*import = $next;                                    # uncoverable statement
	my $class = shift;                                  # uncoverable statement
	my $opts  = { ref( $_[0] ) ? %{ +shift } : () };    # uncoverable statement
	$opts->{into} ||= scalar( caller );                 # uncoverable statement
	_mkall();                                           # uncoverable statement
	return $class->$next( $opts, @_ );                  # uncoverable statement
} #/ sub import

for ( __PACKAGE__->type_names ) {    # uncoverable statement
	eval qq{                                          # uncoverable statement
		sub is_$_     { $_()->check(shift) }           # uncoverable statement
		sub assert_$_ { $_()->assert_return(shift) }   # uncoverable statement
	};                                  # uncoverable statement
}    # uncoverable statement

sub _reinstall_subs {

	# uncoverable subroutine
	my $type = shift;                                        # uncoverable statement
	no strict 'refs';                                        # uncoverable statement
	no warnings 'redefine';                                  # uncoverable statement
	*{ 'is_' . $type->name }     = $type->compiled_check;    # uncoverable statement
	*{ 'assert_' . $type->name } = \&$type;                  # uncoverable statement
	$type;                                                   # uncoverable statement
}    # uncoverable statement

sub _mkall {

	# uncoverable subroutine
	return unless $INC{'Type/Tiny.pm'};                         # uncoverable statement
	__PACKAGE__->get_type( $_ ) for __PACKAGE__->type_names;    # uncoverable statement
}    # uncoverable statement

sub meta {
	return $_[0];
}

sub type_names {
	qw( CodeLike StringLike TypeTiny HashLike ArrayLike _ForeignTypeConstraint );
}

sub has_type {
	my %has = map +( $_ => 1 ), shift->type_names;
	!!$has{ $_[0] };
}

sub get_type {
	my $self = shift;
	return unless $self->has_type( @_ );
	no strict qw(refs);
	&{ $_[0] }();
}

sub coercion_names {
	qw();
}

sub has_coercion {
	my %has = map +( $_ => 1 ), shift->coercion_names;
	!!$has{ $_[0] };
}

sub get_coercion {
	my $self = shift;
	return unless $self->has_coercion( @_ );
	no strict qw(refs);
	&{ $_[0] }();    # uncoverable statement
}

my ( $__get_linear_isa_dfs, $tried_mro );
$__get_linear_isa_dfs = sub {
	if ( !$tried_mro && eval { require mro } ) {
		$__get_linear_isa_dfs = \&mro::get_linear_isa;
		goto $__get_linear_isa_dfs;
	}
	no strict 'refs';
	my $classname = shift;
	my @lin       = ( $classname );
	my %stored;
	foreach my $parent ( @{"$classname\::ISA"} ) {
		my $plin = $__get_linear_isa_dfs->( $parent );
		foreach ( @$plin ) {
			next if exists $stored{$_};
			push( @lin, $_ );
			$stored{$_} = 1;
		}
	}
	return \@lin;
};

sub _check_overload {
	my $package = shift;
	if ( ref $package ) {
		$package = blessed( $package );
		return !!0 if !defined $package;
	}
	my $op  = shift;
	my $mro = $__get_linear_isa_dfs->( $package );
	foreach my $p ( @$mro ) {
		my $fqmeth = $p . q{::(} . $op;
		return !!1 if defined &{$fqmeth};
	}
	!!0;
} #/ sub _check_overload

sub _get_check_overload_sub {
	if ( $Type::Tiny::AvoidCallbacks ) {
		return
			'(sub { require overload; overload::Overloaded(ref $_[0] or $_[0]) and overload::Method((ref $_[0] or $_[0]), $_[1]) })->';
	}
	return 'Types::TypeTiny::_check_overload';
}

sub StringLike () {
	return $cache{StringLike} if defined $cache{StringLike};
	require Type::Tiny;
	my %common = (
		name       => "StringLike",
		library    => __PACKAGE__,
		constraint => sub {
			defined( $_ ) && !ref( $_ )
				or blessed( $_ ) && _check_overload( $_, q[""] );
		},
		inlined => sub {
			qq/defined($_[1]) && !ref($_[1]) or Scalar::Util::blessed($_[1]) && ${\ +_get_check_overload_sub() }($_[1], q[""])/;
		},
		type_default => sub { return '' },
	);
	if ( __XS ) {
		my $xsub     = Type::Tiny::XS::get_coderef_for( 'StringLike' );
		my $xsubname = Type::Tiny::XS::get_subname_for( 'StringLike' );
		my $inlined  = $common{inlined};
		$cache{StringLike} = "Type::Tiny"->new(
			%common,
			compiled_type_constraint => $xsub,
			inlined                  => sub {
			
				# uncoverable subroutine
				( $Type::Tiny::AvoidCallbacks or not $xsubname )
					? goto( $inlined )
					: qq/$xsubname($_[1])/    # uncoverable statement
			},
		);
		_reinstall_subs $cache{StringLike};
	} #/ if ( __XS )
	else {
		$cache{StringLike} = "Type::Tiny"->new( %common );
	}
} #/ sub StringLike

sub HashLike (;@) {
	return $cache{HashLike} if defined( $cache{HashLike} ) && !@_;
	require Type::Tiny;
	my %common = (
		name       => "HashLike",
		library    => __PACKAGE__,
		constraint => sub {
			ref( $_ ) eq q[HASH]
				or blessed( $_ ) && _check_overload( $_, q[%{}] );
		},
		inlined => sub {
			qq/ref($_[1]) eq q[HASH] or Scalar::Util::blessed($_[1]) && ${\ +_get_check_overload_sub() }($_[1], q[\%{}])/;
		},
		type_default => sub { return {} },
		constraint_generator => sub {
			my $param = TypeTiny()->assert_coerce( shift );
			my $check = $param->compiled_check;
			sub {
				my %hash = %$_;
				for my $key ( sort keys %hash ) {
					$check->( $hash{$key} ) or return 0;
				}
				return 1;
			};
		},
		inline_generator => sub {
			my $param = TypeTiny()->assert_coerce( shift );
			return unless $param->can_be_inlined;
			sub {
				my $var  = pop;
				my $code = sprintf(
					'do { my $ok=1; my %%h = %%{%s}; for my $k (sort keys %%h) { ($ok=0,next) unless (%s) }; $ok }',
					$var,
					$param->inline_check( '$h{$k}' ),
				);
				return ( undef, $code );
			};
		},
		coercion_generator => sub {
			my ( $parent, $child, $param ) = @_;
			return unless $param->has_coercion;
			my $coercible = $param->coercion->_source_type_union->compiled_check;
			my $C         = "Type::Coercion"->new( type_constraint => $child );
			$C->add_type_coercions(
				$parent => sub {
					my $origref = @_ ? $_[0] : $_;
					my %orig    = %$origref;
					my %new;
					for my $k ( sort keys %orig ) {
						return $origref unless $coercible->( $orig{$k} );
						$new{$k} = $param->coerce( $orig{$k} );
					}
					\%new;
				},
			);
			return $C;
		},
	);
	if ( __XS ) {
		my $xsub     = Type::Tiny::XS::get_coderef_for( 'HashLike' );
		my $xsubname = Type::Tiny::XS::get_subname_for( 'HashLike' );
		my $inlined  = $common{inlined};
		$cache{HashLike} = "Type::Tiny"->new(
			%common,
			compiled_type_constraint => $xsub,
			inlined                  => sub {
			
				# uncoverable subroutine
				( $Type::Tiny::AvoidCallbacks or not $xsubname )
					? goto( $inlined )
					: qq/$xsubname($_[1])/    # uncoverable statement
			},
		);
		_reinstall_subs $cache{HashLike};
	} #/ if ( __XS )
	else {
		$cache{HashLike} = "Type::Tiny"->new( %common );
	}
	
	@_ ? $cache{HashLike}->parameterize( @{ $_[0] } ) : $cache{HashLike};
} #/ sub HashLike (;@)

sub ArrayLike (;@) {
	return $cache{ArrayLike} if defined( $cache{ArrayLike} ) && !@_;
	require Type::Tiny;
	my %common = (
		name       => "ArrayLike",
		library    => __PACKAGE__,
		constraint => sub {
			ref( $_ ) eq q[ARRAY]
				or blessed( $_ ) && _check_overload( $_, q[@{}] );
		},
		inlined => sub {
			qq/ref($_[1]) eq q[ARRAY] or Scalar::Util::blessed($_[1]) && ${\ +_get_check_overload_sub() }($_[1], q[\@{}])/;
		},
		type_default => sub { return [] },
		constraint_generator => sub {
			my $param = TypeTiny()->assert_coerce( shift );
			my $check = $param->compiled_check;
			sub {
				my @arr = @$_;
				for my $val ( @arr ) {
					$check->( $val ) or return 0;
				}
				return 1;
			};
		},
		inline_generator => sub {
			my $param = TypeTiny()->assert_coerce( shift );
			return unless $param->can_be_inlined;
			sub {
				my $var  = pop;
				my $code = sprintf(
					'do { my $ok=1; for my $v (@{%s}) { ($ok=0,next) unless (%s) }; $ok }',
					$var,
					$param->inline_check( '$v' ),
				);
				return ( undef, $code );
			};
		},
		coercion_generator => sub {
			my ( $parent, $child, $param ) = @_;
			return unless $param->has_coercion;
			my $coercible = $param->coercion->_source_type_union->compiled_check;
			my $C         = "Type::Coercion"->new( type_constraint => $child );
			$C->add_type_coercions(
				$parent => sub {
					my $origref = @_ ? $_[0] : $_;
					my @orig    = @$origref;
					my @new;
					for my $v ( @orig ) {
						return $origref unless $coercible->( $v );
						push @new, $param->coerce( $v );
					}
					\@new;
				},
			);
			return $C;
		},
	);
	if ( __XS ) {
		my $xsub     = Type::Tiny::XS::get_coderef_for( 'ArrayLike' );
		my $xsubname = Type::Tiny::XS::get_subname_for( 'ArrayLike' );
		my $inlined  = $common{inlined};
		$cache{ArrayLike} = "Type::Tiny"->new(
			%common,
			compiled_type_constraint => $xsub,
			inlined                  => sub {
			
				# uncoverable subroutine
				( $Type::Tiny::AvoidCallbacks or not $xsubname )
					? goto( $inlined )
					: qq/$xsubname($_[1])/    # uncoverable statement
			},
		);
		_reinstall_subs $cache{ArrayLike};
	} #/ if ( __XS )
	else {
		$cache{ArrayLike} = "Type::Tiny"->new( %common );
	}
	
	@_ ? $cache{ArrayLike}->parameterize( @{ $_[0] } ) : $cache{ArrayLike};
} #/ sub ArrayLike (;@)

if ( $] ge '5.014' ) {
	&Scalar::Util::set_prototype( $_, ';$' ) for \&HashLike, \&ArrayLike;
}

sub CodeLike () {
	return $cache{CodeLike} if $cache{CodeLike};
	require Type::Tiny;
	my %common = (
		name       => "CodeLike",
		constraint => sub {
			ref( $_ ) eq q[CODE]
				or blessed( $_ ) && _check_overload( $_, q[&{}] );
		},
		inlined => sub {
			qq/ref($_[1]) eq q[CODE] or Scalar::Util::blessed($_[1]) && ${\ +_get_check_overload_sub() }($_[1], q[\&{}])/;
		},
		type_default => sub { return sub {} },
		library => __PACKAGE__,
	);
	if ( __XS ) {
		my $xsub     = Type::Tiny::XS::get_coderef_for( 'CodeLike' );
		my $xsubname = Type::Tiny::XS::get_subname_for( 'CodeLike' );
		my $inlined  = $common{inlined};
		$cache{CodeLike} = "Type::Tiny"->new(
			%common,
			compiled_type_constraint => $xsub,
			inlined                  => sub {
			
				# uncoverable subroutine
				( $Type::Tiny::AvoidCallbacks or not $xsubname )
					? goto( $inlined )
					: qq/$xsubname($_[1])/    # uncoverable statement
			},
		);
		_reinstall_subs $cache{CodeLike};
	} #/ if ( __XS )
	else {
		$cache{CodeLike} = "Type::Tiny"->new( %common );
	}
} #/ sub CodeLike

sub TypeTiny () {
	return $cache{TypeTiny} if defined $cache{TypeTiny};
	require Type::Tiny;
	$cache{TypeTiny} = "Type::Tiny"->new(
		name       => "TypeTiny",
		constraint => sub { blessed( $_ ) && $_->isa( q[Type::Tiny] ) },
		inlined    => sub {
			my $var = $_[1];
			"Scalar::Util::blessed($var) && $var\->isa(q[Type::Tiny])";
		},
		type_default => sub { require Types::Standard; return Types::Standard::Any() },
		library         => __PACKAGE__,
		_build_coercion => sub {
			my $c = shift;
			$c->add_type_coercions( _ForeignTypeConstraint(), \&to_TypeTiny );
			$c->freeze;
		},
	);
} #/ sub TypeTiny

sub _ForeignTypeConstraint () {
	return $cache{_ForeignTypeConstraint} if defined $cache{_ForeignTypeConstraint};
	require Type::Tiny;
	$cache{_ForeignTypeConstraint} = "Type::Tiny"->new(
		name       => "_ForeignTypeConstraint",
		constraint => \&_is_ForeignTypeConstraint,
		inlined    => sub {
			qq/ref($_[1]) && do { require Types::TypeTiny; Types::TypeTiny::_is_ForeignTypeConstraint($_[1]) }/;
		},
		library => __PACKAGE__,
	);
} #/ sub _ForeignTypeConstraint

my %ttt_cache;

sub _is_ForeignTypeConstraint {
	my $t = @_ ? $_[0] : $_;
	return !!1 if ref $t eq 'CODE';
	if ( my $class = blessed $t ) {
		return !!0 if $class->isa( "Type::Tiny" );
		return !!1 if $class->isa( "Moose::Meta::TypeConstraint" );
		return !!1 if $class->isa( "MooseX::Types::TypeDecorator" );
		return !!1 if $class->isa( "Validation::Class::Simple" );
		return !!1 if $class->isa( "Validation::Class" );
		return !!1 if $t->can( "check" );
	}
	!!0;
} #/ sub _is_ForeignTypeConstraint

sub to_TypeTiny {
	my $t = @_ ? $_[0] : $_;
	
	return $t unless ( my $ref = ref $t );
	return $t if $ref =~ /^Type::Tiny\b/;
	
	return $ttt_cache{ refaddr( $t ) } if $ttt_cache{ refaddr( $t ) };
	
	#<<<
	if ( my $class = blessed $t) {
		return $t                                 if $class->isa( "Type::Tiny" );
		return _TypeTinyFromMoose( $t )           if $class eq "MooseX::Types::TypeDecorator";      # needed before MooseX::Types 0.35.
		return _TypeTinyFromMoose( $t )           if $class->isa( "Moose::Meta::TypeConstraint" );
		return _TypeTinyFromMoose( $t )           if $class->isa( "MooseX::Types::TypeDecorator" );
		return _TypeTinyFromMouse( $t )           if $class->isa( "Mouse::Meta::TypeConstraint" );
		return _TypeTinyFromValidationClass( $t ) if $class->isa( "Validation::Class::Simple" );
		return _TypeTinyFromValidationClass( $t ) if $class->isa( "Validation::Class" );
		return $t->to_TypeTiny                    if $t->can( "DOES" ) && $t->DOES( "Type::Library::Compiler::TypeConstraint" ) && $t->can( "to_TypeTiny" );
		return _TypeTinyFromGeneric( $t )         if $t->can( "check" );                            # i.e. Type::API::Constraint
	} #/ if ( my $class = blessed...)
	#>>>
	
	return _TypeTinyFromCodeRef( $t ) if $ref eq q(CODE);
	
	$t;
} #/ sub to_TypeTiny

sub _TypeTinyFromMoose {
	my $t = $_[0];
	
	if ( ref $t->{"Types::TypeTiny::to_TypeTiny"} ) {
		return $t->{"Types::TypeTiny::to_TypeTiny"};
	}
	
	if ( $t->name ne '__ANON__' ) {
		require Types::Standard;
		my $ts = 'Types::Standard'->get_type( $t->name );
		return $ts if $ts->{_is_core};
	}
	
	#<<<
	my ( $tt_class, $tt_opts ) =
		$t->can( 'parameterize' )                          ? _TypeTinyFromMoose_parameterizable( $t ) :
		$t->isa( 'Moose::Meta::TypeConstraint::Enum' )     ? _TypeTinyFromMoose_enum( $t ) :
		$t->isa( 'Moose::Meta::TypeConstraint::Class' )    ? _TypeTinyFromMoose_class( $t ) :
		$t->isa( 'Moose::Meta::TypeConstraint::Role' )     ? _TypeTinyFromMoose_role( $t ) :
		$t->isa( 'Moose::Meta::TypeConstraint::Union' )    ? _TypeTinyFromMoose_union( $t ) :
		$t->isa( 'Moose::Meta::TypeConstraint::DuckType' ) ? _TypeTinyFromMoose_ducktype( $t ) :
		_TypeTinyFromMoose_baseclass( $t );
	#>>>
	
	# Standard stuff to do with all type constraints from Moose,
	# regardless of variety.
	$tt_opts->{moose_type}   = $t;
	$tt_opts->{display_name} = $t->name;
	$tt_opts->{message}      = sub { $t->get_message( $_ ) }
		if $t->has_message;
		
	my $new = $tt_class->new( %$tt_opts );
	$ttt_cache{ refaddr( $t ) } = $new;
	weaken( $ttt_cache{ refaddr( $t ) } );
	
	$new->{coercion} = do {
		require Type::Coercion::FromMoose;
		'Type::Coercion::FromMoose'->new(
			type_constraint => $new,
			moose_coercion  => $t->coercion,
		);
	} if $t->has_coercion;
	
	return $new;
} #/ sub _TypeTinyFromMoose

sub _TypeTinyFromMoose_baseclass {
	my $t = shift;
	my %opts;
	$opts{parent}     = to_TypeTiny( $t->parent ) if $t->has_parent;
	$opts{constraint} = $t->constraint;
	$opts{inlined}    = sub { shift; $t->_inline_check( @_ ) }
		if $t->can( "can_be_inlined" ) && $t->can_be_inlined;
		
	# Cowardly refuse to inline types that need to close over stuff
	if ( $opts{inlined} ) {
		my %env = %{ $t->inline_environment || {} };
		delete( $opts{inlined} ) if keys %env;
	}
	
	require Type::Tiny;
	return 'Type::Tiny' => \%opts;
} #/ sub _TypeTinyFromMoose_baseclass

sub _TypeTinyFromMoose_union {
	my $t = shift;
	my @mapped = map _TypeTinyFromMoose( $_ ), @{ $t->type_constraints };
	require Type::Tiny::Union;
	return 'Type::Tiny::Union' => { type_constraints => \@mapped };
}

sub _TypeTinyFromMoose_enum {
	my $t = shift;
	require Type::Tiny::Enum;
	return 'Type::Tiny::Enum' => { values => [ @{ $t->values } ] };
}

sub _TypeTinyFromMoose_class {
	my $t = shift;
	require Type::Tiny::Class;
	return 'Type::Tiny::Class' => { class => $t->class };
}

sub _TypeTinyFromMoose_role {
	my $t = shift;
	require Type::Tiny::Role;
	return 'Type::Tiny::Role' => { role => $t->role };
}

sub _TypeTinyFromMoose_ducktype {
	my $t = shift;
	require Type::Tiny::Duck;
	return 'Type::Tiny::Duck' => { methods => [ @{ $t->methods } ] };
}

sub _TypeTinyFromMoose_parameterizable {
	my $t = shift;
	my ( $class, $opts ) = _TypeTinyFromMoose_baseclass( $t );
	$opts->{constraint_generator} = sub {
	
		# convert args into Moose native types; not strictly necessary
		my @args = map { is_TypeTiny( $_ ) ? $_->moose_type : $_ } @_;
		_TypeTinyFromMoose( $t->parameterize( @args ) );
	};
	return ( $class, $opts );
} #/ sub _TypeTinyFromMoose_parameterizable

sub _TypeTinyFromValidationClass {
	my $t = $_[0];
	
	require Type::Tiny;
	require Types::Standard;
	
	my %opts = (
		parent            => Types::Standard::HashRef(),
		_validation_class => $t,
	);
	
	if ( $t->VERSION >= "7.900048" ) {
		$opts{constraint} = sub {
			$t->params->clear;
			$t->params->add( %$_ );
			my $f = $t->filtering;
			$t->filtering( 'off' );
			my $r = eval { $t->validate };
			$t->filtering( $f || 'pre' );
			return $r;
		};
		$opts{message} = sub {
			$t->params->clear;
			$t->params->add( %$_ );
			my $f = $t->filtering;
			$t->filtering( 'off' );
			my $r = ( eval { $t->validate } ? "OK" : $t->errors_to_string );
			$t->filtering( $f || 'pre' );
			return $r;
		};
	} #/ if ( $t->VERSION >= "7.900048")
	else    # need to use hackish method
	{
		$opts{constraint} = sub {
			$t->params->clear;
			$t->params->add( %$_ );
			no warnings "redefine";
			local *Validation::Class::Directive::Filters::execute_filtering = sub { $_[0] };
			eval { $t->validate };
		};
		$opts{message} = sub {
			$t->params->clear;
			$t->params->add( %$_ );
			no warnings "redefine";
			local *Validation::Class::Directive::Filters::execute_filtering = sub { $_[0] };
			eval { $t->validate } ? "OK" : $t->errors_to_string;
		};
	} #/ else [ if ( $t->VERSION >= "7.900048")]
	
	require Type::Tiny;
	my $new = "Type::Tiny"->new( %opts );
	
	$new->coercion->add_type_coercions(
		Types::Standard::HashRef() => sub {
			my %params = %$_;
			for my $k ( keys %params ) { delete $params{$_} unless $t->get_fields( $k ) }
			$t->params->clear;
			$t->params->add( %params );
			eval { $t->validate };
			$t->get_hash;
		},
	);
	
	$ttt_cache{ refaddr( $t ) } = $new;
	weaken( $ttt_cache{ refaddr( $t ) } );
	return $new;
} #/ sub _TypeTinyFromValidationClass

sub _TypeTinyFromGeneric {
	my $t = $_[0];
	
	my %opts = (
		constraint => sub { $t->check( @_ ? @_ : $_ ) },
	);
	
	$opts{message} = sub { $t->get_message( @_ ? @_ : $_ ) }
		if $t->can( "get_message" );
		
	$opts{display_name} = $t->name if $t->can( "name" );
	
	$opts{coercion} = sub { $t->coerce( @_ ? @_ : $_ ) }
		if $t->can( "has_coercion" )
		&& $t->has_coercion
		&& $t->can( "coerce" );
		
	if ( $t->can( 'can_be_inlined' )
		&& $t->can_be_inlined
		&& $t->can( 'inline_check' ) )
	{
		$opts{inlined} = sub { $t->inline_check( $_[1] ) };
	}
	
	require Type::Tiny;
	my $new = "Type::Tiny"->new( %opts );
	$ttt_cache{ refaddr( $t ) } = $new;
	weaken( $ttt_cache{ refaddr( $t ) } );
	return $new;
} #/ sub _TypeTinyFromGeneric

sub _TypeTinyFromMouse {
	my $t = $_[0];
	
	my %opts = (
		constraint => sub { $t->check( @_       ? @_ : $_ ) },
		message    => sub { $t->get_message( @_ ? @_ : $_ ) },
	);
	
	$opts{display_name} = $t->name if $t->can( "name" );
	
	$opts{coercion} = sub { $t->coerce( @_ ? @_ : $_ ) }
		if $t->can( "has_coercion" )
		&& $t->has_coercion
		&& $t->can( "coerce" );
		
	if ( $t->{'constraint_generator'} ) {
		$opts{constraint_generator} = sub {
		
			# convert args into Moose native types; not strictly necessary
			my @args = map { is_TypeTiny( $_ ) ? $_->mouse_type : $_ } @_;
			_TypeTinyFromMouse( $t->parameterize( @args ) );
		};
	}
	
	require Type::Tiny;
	my $new = "Type::Tiny"->new( %opts );
	$ttt_cache{ refaddr( $t ) } = $new;
	weaken( $ttt_cache{ refaddr( $t ) } );
	return $new;
} #/ sub _TypeTinyFromMouse

my $QFS;

sub _TypeTinyFromCodeRef {
	my $t = $_[0];
	
	my %opts = (
		constraint => sub {
			return !!eval { $t->( $_ ) };
		},
		message => sub {
			local $@;
			eval { $t->( $_ ); 1 } or do { chomp $@; return $@ if $@ };
			return sprintf( '%s did not pass type constraint', Type::Tiny::_dd( $_ ) );
		},
	);
	
	if ( $QFS ||= "Sub::Quote"->can( "quoted_from_sub" ) ) {
		my ( undef, $perlstring, $captures ) = @{ $QFS->( $t ) || [] };
		if ( $perlstring ) {
			$perlstring = "!!eval{ $perlstring }";
			$opts{inlined} = sub {
				my $var = $_[1];
				Sub::Quote::inlinify(
					$perlstring,
					$var,
					$var eq q($_) ? '' : "local \$_ = $var;",
					1,
				);
				}
				if $perlstring && !$captures;
		} #/ if ( $perlstring )
	} #/ if ( $QFS ||= "Sub::Quote"...)
	
	require Type::Tiny;
	my $new = "Type::Tiny"->new( %opts );
	$ttt_cache{ refaddr( $t ) } = $new;
	weaken( $ttt_cache{ refaddr( $t ) } );
	return $new;
} #/ sub _TypeTinyFromCodeRef

1;

__END__

=pod

=encoding utf-8

=for stopwords arrayfication hashification

=head1 NAME

Types::TypeTiny - type constraints used internally by Type::Tiny

=head1 STATUS

This module is covered by the
L<Type-Tiny stability policy|Type::Tiny::Manual::Policies/"STABILITY">.

=head1 DESCRIPTION

Dogfooding.

This isn't a real Type::Library-based type library; that would involve
too much circularity. But it exports some type constraints which, while
designed for use within Type::Tiny, may be more generally useful.

=head2 Types

=over

=item *

B<< StringLike >>

Accepts strings and objects overloading stringification.

=item *

B<< HashLike[`a] >>

Accepts hashrefs and objects overloading hashification.

Since Types::TypeTiny 1.012, may be parameterized with another type
constraint like B<< HashLike[Int] >>.

=item *

B<< ArrayLike[`a] >>

Accepts arrayrefs and objects overloading arrayfication.

Since Types::TypeTiny 1.012, may be parameterized with another type
constraint like B<< ArrayLike[Int] >>.

=item *

B<< CodeLike >>

Accepts coderefs and objects overloading codification.

=item *

B<< TypeTiny >>

Accepts blessed L<Type::Tiny> objects.

=item *

B<< _ForeignTypeConstraint >>

Any reference which to_TypeTiny recognizes as something that can be coerced
to a Type::Tiny object.

Yes, the underscore is included.

=back

=head2 Coercion Functions

=over

=item C<< to_TypeTiny($constraint) >>

Promotes (or "demotes" if you prefer) a "foreign" type constraint to a
Type::Tiny object. Can handle:

=over

=item *

Moose types (including L<Moose::Meta::TypeConstraint> objects and
L<MooseX::Types::TypeDecorator> objects).

=item *

Mouse types (including L<Mouse::Meta::TypeConstraint> objects).

=item *

L<Validation::Class> and L<Validation::Class::Simple> objects.

=item *

Types built using L<Type::Library::Compiler>.

=item *

Any object which provides C<check> and C<get_message> methods.
(This includes L<Specio> and L<Type::Nano> types.) If the object
provides C<has_coercion> and L<coerce> methods, these will
be used to handle quoting. If the object provides C<can_be_inlined>
and C<inline_check> methods, these will be used to handling inlining.
If the object provides a C<name> method, this will be assumed to
return the type name.

=item *

Coderefs (but not blessed coderefs or objects overloading C<< &{} >>
unless they provide the methods described above!) Coderefs are expected
to return true iff C<< $_ >> passes the constraint. If C<< $_ >> fails
the type constraint, they may either return false, or die with a helpful
error message.

=item *

L<Sub::Quote>-enabled coderefs. These are handled the same way as above,
but Type::Tiny will consult Sub::Quote to determine if they can be inlined.

=back

=back

=head2 Methods

These are implemented so that C<< Types::TypeTiny->meta->get_type($foo) >>
works, for rough compatibility with a real L<Type::Library> type library.

=over

=item C<< meta >>

=item C<< type_names >>

=item C<< get_type($name) >>

=item C<< has_type($name) >>

=item C<< coercion_names >>

=item C<< get_coercion($name) >>

=item C<< has_coercion($name) >>

=back

=head1 BUGS

Please report any bugs to
L<https://github.com/tobyink/p5-type-tiny/issues>.

=head1 SEE ALSO

L<Type::Tiny>.

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
