# INTERNAL MODULE: guts for Dict type from Types::Standard.

package Types::Standard::Dict;

use 5.008001;
use strict;
use warnings;

BEGIN {
	$Types::Standard::Dict::AUTHORITY = 'cpan:TOBYINK';
	$Types::Standard::Dict::VERSION   = '2.000001';
}

$Types::Standard::Dict::VERSION =~ tr/_//d;

use Types::Standard ();
use Types::TypeTiny ();

sub _croak ($;@) {
	require Carp;
	goto \&Carp::confess;
	require Error::TypeTiny;
	goto \&Error::TypeTiny::croak;
}

my $_Slurpy   = Types::Standard::Slurpy;
my $_optional = Types::Standard::Optional;
my $_hash     = Types::Standard::HashRef;
my $_map      = Types::Standard::Map;
my $_any      = Types::Standard::Any;

no warnings;

sub pair_iterator {
	_croak( "Expected even-sized list" ) if @_ % 2;
	my @array = @_;
	sub {
		return unless @array;
		splice( @array, 0, 2 );
	};
}

sub __constraint_generator {
	my $slurpy =
		@_
		&& Types::TypeTiny::is_TypeTiny( $_[-1] )
		&& $_[-1]->is_strictly_a_type_of( $_Slurpy )
		? pop->my_unslurpy
		: undef;
	my $iterator = pair_iterator @_;
	my %constraints;
	my %is_optional;
	my @keys;
	
	while ( my ( $k, $v ) = $iterator->() ) {
		$constraints{$k} = $v;
		Types::TypeTiny::is_TypeTiny( $v )
			or _croak(
			"Parameter for Dict[...] with key '$k' expected to be a type constraint; got $v"
			);
		Types::TypeTiny::is_StringLike( $k )
			or _croak( "Key for Dict[...] expected to be string; got $k" );
		push @keys, $k;
		$is_optional{$k} = !!$constraints{$k}->is_strictly_a_type_of( $_optional );
	} #/ while ( my ( $k, $v ) = $iterator...)
	
	return sub {
		my $value = $_[0];
		if ( $slurpy ) {
			my %tmp = map +( exists( $constraints{$_} ) ? () : ( $_ => $value->{$_} ) ),
				keys %$value;
			return unless $slurpy->check( \%tmp );
		}
		else {
			exists( $constraints{$_} ) || return for sort keys %$value;
		}
		for my $k ( @keys ) {
			exists( $value->{$k} )                  or ( $is_optional{$k} ? next : return );
			$constraints{$k}->check( $value->{$k} ) or return;
		}
		return !!1;
	};
} #/ sub __constraint_generator

sub __inline_generator {

	# We can only inline a parameterized Dict if all the
	# constraints inside can be inlined.
	
	my $slurpy =
		@_
		&& Types::TypeTiny::is_TypeTiny( $_[-1] )
		&& $_[-1]->is_strictly_a_type_of( $_Slurpy )
		? pop->my_unslurpy
		: undef;
	return if $slurpy && !$slurpy->can_be_inlined;
	
	# Is slurpy a very loose type constraint?
	# i.e. Any, Item, Defined, Ref, or HashRef
	my $slurpy_is_any = $slurpy && $_hash->is_a_type_of( $slurpy );
	
	# Is slurpy a parameterized Map, or expressable as a parameterized Map?
	my $slurpy_is_map =
		$slurpy
		&& $slurpy->is_parameterized
		&& (
		( $slurpy->parent->strictly_equals( $_map ) && $slurpy->parameters )
		|| ( $slurpy->parent->strictly_equals( $_hash )
			&& [ $_any, $slurpy->parameters->[0] ] )
		);
		
	my $iterator = pair_iterator @_;
	my %constraints;
	my @keys;
	
	while ( my ( $k, $c ) = $iterator->() ) {
		return unless $c->can_be_inlined;
		$constraints{$k} = $c;
		push @keys, $k;
	}
	
	my $regexp = join "|", map quotemeta, @keys;
	return sub {
		require B;
		my $h = $_[1];
		join " and ",
			Types::Standard::HashRef->inline_check( $h ),
			(
			$slurpy_is_any
			? ()
			: $slurpy_is_map ? do {
				'(not grep {' . "my \$v = ($h)->{\$_};" . sprintf(
					'not((/\\A(?:%s)\\z/) or ((%s) and (%s)))',
					$regexp,
					$slurpy_is_map->[0]->inline_check( '$_' ),
					$slurpy_is_map->[1]->inline_check( '$v' ),
				) . "} keys \%{$h})";
				}
			: $slurpy ? do {
				'do {'
					. "my \$slurpy_tmp = +{ map /\\A(?:$regexp)\\z/ ? () : (\$_ => ($h)->{\$_}), keys \%{$h} };"
					. $slurpy->inline_check( '$slurpy_tmp' ) . '}';
				}
			: "not(grep !/\\A(?:$regexp)\\z/, keys \%{$h})"
			),
			(
			map {
				my $k = B::perlstring( $_ );
				$constraints{$_}->is_strictly_a_type_of( $_optional )
					? sprintf(
					'(!exists %s->{%s} or %s)', $h, $k,
					$constraints{$_}->inline_check( "$h\->{$k}" )
					)
					: (
					"exists($h\->{$k})",
					$constraints{$_}->inline_check( "$h\->{$k}" )
					)
			} @keys
			),
			;
	}
} #/ sub __inline_generator

sub __deep_explanation {
	require B;
	my ( $type, $value, $varname ) = @_;
	my @params = @{ $type->parameters };
	
	my $slurpy =
		@params
		&& Types::TypeTiny::is_TypeTiny( $params[-1] )
		&& $params[-1]->is_strictly_a_type_of( $_Slurpy )
		? pop( @params )->my_unslurpy
		: undef;
	my $iterator = pair_iterator @params;
	my %constraints;
	my @keys;
	
	while ( my ( $k, $c ) = $iterator->() ) {
		push @keys, $k;
		$constraints{$k} = $c;
	}
	
	for my $k ( @keys ) {
		next
			if $constraints{$k}->has_parent
			&& ( $constraints{$k}->parent == Types::Standard::Optional )
			&& ( !exists $value->{$k} );
		next if $constraints{$k}->check( $value->{$k} );
		
		return [
			sprintf( '"%s" requires key %s to appear in hash', $type, B::perlstring( $k ) )
			]
			unless exists $value->{$k};
			
		return [
			sprintf(
				'"%s" constrains value at key %s of hash with "%s"',
				$type,
				B::perlstring( $k ),
				$constraints{$k},
			),
			@{
				$constraints{$k}->validate_explain(
					$value->{$k},
					sprintf( '%s->{%s}', $varname, B::perlstring( $k ) ),
				)
			},
		];
	} #/ for my $k ( @keys )
	
	if ( $slurpy ) {
		my %tmp = map { exists( $constraints{$_} ) ? () : ( $_ => $value->{$_} ) }
			keys %$value;
			
		my $explain = $slurpy->validate_explain( \%tmp, '$slurpy' );
		return [
			sprintf(
				'"%s" requires the hashref of additional key/value pairs to conform to "%s"',
				$type, $slurpy
			),
			@$explain,
		] if $explain;
	} #/ if ( $slurpy )
	else {
		for my $k ( sort keys %$value ) {
			return [
				sprintf(
					'"%s" does not allow key %s to appear in hash', $type, B::perlstring( $k )
				)
				]
				unless exists $constraints{$k};
		}
	} #/ else [ if ( $slurpy ) ]
	
	# This should never happen...
	return;    # uncoverable statement
} #/ sub __deep_explanation

my $label_counter = 0;
our ( $keycheck_counter, @KEYCHECK ) = -1;

sub __coercion_generator {
	my $slurpy =
		@_
		&& Types::TypeTiny::is_TypeTiny( $_[-1] )
		&& $_[-1]->is_strictly_a_type_of( $_Slurpy )
		? pop->my_unslurpy
		: undef;
	my ( $parent, $child, %dict ) = @_;
	my $C = "Type::Coercion"->new( type_constraint => $child );
	
	my $all_inlinable         = 1;
	my $child_coercions_exist = 0;
	for my $tc ( values %dict ) {
		$all_inlinable = 0 if !$tc->can_be_inlined;
		$all_inlinable = 0 if $tc->has_coercion && !$tc->coercion->can_be_inlined;
		$child_coercions_exist++ if $tc->has_coercion;
	}
	$all_inlinable = 0 if $slurpy && !$slurpy->can_be_inlined;
	$all_inlinable = 0
		if $slurpy
		&& $slurpy->has_coercion
		&& !$slurpy->coercion->can_be_inlined;
		
	$child_coercions_exist++ if $slurpy && $slurpy->has_coercion;
	return unless $child_coercions_exist;
	
	if ( $all_inlinable ) {
		$C->add_type_coercions(
			$parent => Types::Standard::Stringable {
				require B;
				
				my $keycheck = join "|", map quotemeta,
					sort { length( $b ) <=> length( $a ) or $a cmp $b } keys %dict;
				$keycheck = $KEYCHECK[ ++$keycheck_counter ] = qr{^($keycheck)$}ms;    # regexp for legal keys
				
				my $label = sprintf( "DICTLABEL%d", ++$label_counter );
				my @code;
				push @code, 'do { my ($orig, $return_orig, $tmp, %new) = ($_, 0);';
				push @code, "$label: {";
				if ( $slurpy ) {
					push @code,
						sprintf(
						'my $slurped = +{ map +($_=~$%s::KEYCHECK[%d])?():($_=>$orig->{$_}), keys %%$orig };',
						__PACKAGE__, $keycheck_counter
						);
					if ( $slurpy->has_coercion ) {
						push @code,
							sprintf(
							'my $coerced = %s;',
							$slurpy->coercion->inline_coercion( '$slurped' )
							);
						push @code,
							sprintf(
							'((%s)&&(%s))?(%%new=%%$coerced):(($return_orig = 1), last %s);',
							$_hash->inline_check( '$coerced' ), $slurpy->inline_check( '$coerced' ),
							$label
							);
					} #/ if ( $slurpy->has_coercion)
					else {
						push @code,
							sprintf(
							'(%s)?(%%new=%%$slurped):(($return_orig = 1), last %s);',
							$slurpy->inline_check( '$slurped' ), $label
							);
					}
				} #/ if ( $slurpy )
				else {
					push @code,
						sprintf(
						'($_ =~ $%s::KEYCHECK[%d])||(($return_orig = 1), last %s) for sort keys %%$orig;',
						__PACKAGE__, $keycheck_counter, $label
						);
				}
				for my $k ( keys %dict ) {
					my $ct          = $dict{$k};
					my $ct_coerce   = $ct->has_coercion;
					my $ct_optional = $ct->is_a_type_of( $_optional );
					my $K           = B::perlstring( $k );
					
					push @code, sprintf(
						'if (exists $orig->{%s}) { $tmp = %s; (%s) ? ($new{%s}=$tmp) : (($return_orig=1), last %s) }',
						$K,
						$ct_coerce
						? $ct->coercion->inline_coercion( "\$orig->{$K}" )
						: "\$orig->{$K}",
						$ct->inline_check( '$tmp' ),
						$K,
						$label,
					);
				} #/ for my $k ( keys %dict )
				push @code, '}';
				push @code, '$return_orig ? $orig : \\%new';
				push @code, '}';
				
				#warn "CODE:: @code";
				"@code";
			}
		);
	} #/ if ( $all_inlinable )
	
	else {
		my %is_optional = map {
			;
			$_ => !!$dict{$_}->is_strictly_a_type_of( $_optional )
		} sort keys %dict;
		$C->add_type_coercions(
			$parent => sub {
				my $value = @_ ? $_[0] : $_;
				my %new;
				
				if ( $slurpy ) {
					my %slurped = map exists( $dict{$_} ) ? () : ( $_ => $value->{$_} ),
						keys %$value;
						
					if ( $slurpy->check( \%slurped ) ) {
						%new = %slurped;
					}
					elsif ( $slurpy->has_coercion ) {
						my $coerced = $slurpy->coerce( \%slurped );
						$slurpy->check( $coerced ) ? ( %new = %$coerced ) : ( return $value );
					}
					else {
						return $value;
					}
				} #/ if ( $slurpy )
				else {
					for my $k ( keys %$value ) {
						return $value unless exists $dict{$k};
					}
				}
				
				for my $k ( keys %dict ) {
					next if $is_optional{$k} and not exists $value->{$k};
					
					my $ct = $dict{$k};
					my $x  = $ct->has_coercion ? $ct->coerce( $value->{$k} ) : $value->{$k};
					
					return $value unless $ct->check( $x );
					
					$new{$k} = $x;
				} #/ for my $k ( keys %dict )
				
				return \%new;
			},
		);
	} #/ else [ if ( $all_inlinable ) ]
	
	return $C;
} #/ sub __coercion_generator

sub __dict_is_slurpy {
	my $self = shift;
	
	return !!0 if $self == Types::Standard::Dict();
	
	my $dict = $self->find_parent(
		sub { $_->has_parent && $_->parent == Types::Standard::Dict() } );
	my $slurpy =
		@{ $dict->parameters }
		&& Types::TypeTiny::is_TypeTiny( $dict->parameters->[-1] )
		&& $dict->parameters->[-1]->is_strictly_a_type_of( $_Slurpy )
		? $dict->parameters->[-1]
		: undef;
} #/ sub __dict_is_slurpy

sub __hashref_allows_key {
	my $self = shift;
	my ( $key ) = @_;
	
	return Types::Standard::is_Str( $key ) if $self == Types::Standard::Dict();
	
	my $dict = $self->find_parent(
		sub { $_->has_parent && $_->parent == Types::Standard::Dict() } );
	my %params;
	my $slurpy = $dict->my_dict_is_slurpy;
	if ( $slurpy ) {
		my @args = @{ $dict->parameters };
		pop @args;
		%params = @args;
		$slurpy = $slurpy->my_unslurpy;
	}
	else {
		%params = @{ $dict->parameters };
	}
	
	return !!1
		if exists( $params{$key} );
	return !!0
		if !$slurpy;
	return Types::Standard::is_Str( $key )
		if $slurpy == Types::Standard::Any()
		|| $slurpy == Types::Standard::Item()
		|| $slurpy == Types::Standard::Defined()
		|| $slurpy == Types::Standard::Ref();
	return $slurpy->my_hashref_allows_key( $key )
		if $slurpy->is_a_type_of( Types::Standard::HashRef() );
	return !!0;
} #/ sub __hashref_allows_key

sub __hashref_allows_value {
	my $self = shift;
	my ( $key, $value ) = @_;
	
	return !!0 unless $self->my_hashref_allows_key( $key );
	return !!1 if $self == Types::Standard::Dict();
	
	my $dict = $self->find_parent(
		sub { $_->has_parent && $_->parent == Types::Standard::Dict() } );
	my %params;
	my $slurpy = $dict->my_dict_is_slurpy;
	if ( $slurpy ) {
		my @args = @{ $dict->parameters };
		pop @args;
		%params = @args;
		$slurpy = $slurpy->my_unslurpy;
	}
	else {
		%params = @{ $dict->parameters };
	}
	
	return !!1
		if exists( $params{$key} ) && $params{$key}->check( $value );
	return !!0
		if !$slurpy;
	return !!1
		if $slurpy == Types::Standard::Any()
		|| $slurpy == Types::Standard::Item()
		|| $slurpy == Types::Standard::Defined()
		|| $slurpy == Types::Standard::Ref();
	return $slurpy->my_hashref_allows_value( $key, $value )
		if $slurpy->is_a_type_of( Types::Standard::HashRef() );
	return !!0;
} #/ sub __hashref_allows_value

1;
