# INTERNAL MODULE: guts for Map type from Types::Standard.

package Types::Standard::Map;

use 5.008001;
use strict;
use warnings;

BEGIN {
	$Types::Standard::Map::AUTHORITY = 'cpan:TOBYINK';
	$Types::Standard::Map::VERSION   = '2.000001';
}

$Types::Standard::Map::VERSION =~ tr/_//d;

use Type::Tiny      ();
use Types::Standard ();
use Types::TypeTiny ();

sub _croak ($;@) { require Error::TypeTiny; goto \&Error::TypeTiny::croak }

my $meta = Types::Standard->meta;

no warnings;

sub __constraint_generator {
	return $meta->get_type( 'Map' ) unless @_;
	
	my ( $keys, $values ) = @_;
	Types::TypeTiny::is_TypeTiny( $keys )
		or _croak(
		"First parameter to Map[`k,`v] expected to be a type constraint; got $keys" );
	Types::TypeTiny::is_TypeTiny( $values )
		or _croak(
		"Second parameter to Map[`k,`v] expected to be a type constraint; got $values"
		);
		
	my @xsub;
	if ( Type::Tiny::_USE_XS ) {
		my @known = map {
			my $known = Type::Tiny::XS::is_known( $_->compiled_check );
			defined( $known ) ? $known : ();
		} ( $keys, $values );
		
		if ( @known == 2 ) {
			my $xsub = Type::Tiny::XS::get_coderef_for( sprintf "Map[%s,%s]", @known );
			push @xsub, $xsub if $xsub;
		}
	} #/ if ( Type::Tiny::_USE_XS)
	
	sub {
		my $hash = shift;
		$keys->check( $_ )   || return for keys %$hash;
		$values->check( $_ ) || return for values %$hash;
		return !!1;
	}, @xsub;
} #/ sub __constraint_generator

sub __inline_generator {
	my ( $k, $v ) = @_;
	return unless $k->can_be_inlined && $v->can_be_inlined;
	
	my $xsubname;
	if ( Type::Tiny::_USE_XS ) {
		my @known = map {
			my $known = Type::Tiny::XS::is_known( $_->compiled_check );
			defined( $known ) ? $known : ();
		} ( $k, $v );
		
		if ( @known == 2 ) {
			$xsubname = Type::Tiny::XS::get_subname_for( sprintf "Map[%s,%s]", @known );
		}
	} #/ if ( Type::Tiny::_USE_XS)
	
	return sub {
		my $h = $_[1];
		return "$xsubname\($h\)" if $xsubname && !$Type::Tiny::AvoidCallbacks;
		my $p       = Types::Standard::HashRef->inline_check( $h );
		my $k_check = $k->inline_check( '$k' );
		my $v_check = $v->inline_check( '$v' );
		"$p and do { "
			. "my \$ok = 1; "
			. "for my \$v (values \%{$h}) { "
			. "(\$ok = 0, last) unless $v_check " . "}; "
			. "for my \$k (keys \%{$h}) { "
			. "(\$ok = 0, last) unless $k_check " . "}; " . "\$ok " . "}";
	};
} #/ sub __inline_generator

sub __deep_explanation {
	require B;
	my ( $type, $value, $varname ) = @_;
	my ( $kparam, $vparam ) = @{ $type->parameters };
	
	for my $k ( sort keys %$value ) {
		unless ( $kparam->check( $k ) ) {
			return [
				sprintf( '"%s" constrains each key in the hash with "%s"', $type, $kparam ),
				@{
					$kparam->validate_explain(
						$k, sprintf( 'key %s->{%s}', $varname, B::perlstring( $k ) )
					)
				},
			];
		} #/ unless ( $kparam->check( $k...))
		
		unless ( $vparam->check( $value->{$k} ) ) {
			return [
				sprintf( '"%s" constrains each value in the hash with "%s"', $type, $vparam ),
				@{
					$vparam->validate_explain(
						$value->{$k}, sprintf( '%s->{%s}', $varname, B::perlstring( $k ) )
					)
				},
			];
		} #/ unless ( $vparam->check( $value...))
	} #/ for my $k ( sort keys %$value)
	
	# This should never happen...
	return;    # uncoverable statement
} #/ sub __deep_explanation

sub __coercion_generator {
	my ( $parent, $child, $kparam, $vparam ) = @_;
	return unless $kparam->has_coercion || $vparam->has_coercion;
	
	my $kcoercable_item =
		$kparam->has_coercion
		? $kparam->coercion->_source_type_union
		: $kparam;
	my $vcoercable_item =
		$vparam->has_coercion
		? $vparam->coercion->_source_type_union
		: $vparam;
	my $C = "Type::Coercion"->new( type_constraint => $child );
	
	if ( ( !$kparam->has_coercion or $kparam->coercion->can_be_inlined )
		and ( !$vparam->has_coercion or $vparam->coercion->can_be_inlined )
		and $kcoercable_item->can_be_inlined
		and $vcoercable_item->can_be_inlined )
	{
		$C->add_type_coercions(
			$parent => Types::Standard::Stringable {
				my @code;
				push @code, 'do { my ($orig, $return_orig, %new) = ($_, 0);';
				push @code, 'for (keys %$orig) {';
				push @code,
					sprintf(
					'++$return_orig && last unless (%s);',
					$kcoercable_item->inline_check( '$_' )
					);
				push @code,
					sprintf(
					'++$return_orig && last unless (%s);',
					$vcoercable_item->inline_check( '$orig->{$_}' )
					);
				push @code, sprintf(
					'$new{(%s)} = (%s);',
					$kparam->has_coercion ? $kparam->coercion->inline_coercion( '$_' ) : '$_',
					$vparam->has_coercion
					? $vparam->coercion->inline_coercion( '$orig->{$_}' )
					: '$orig->{$_}',
				);
				push @code, '}';
				push @code, '$return_orig ? $orig : \\%new';
				push @code, '}';
				"@code";
			}
		);
	} #/ if ( ( !$kparam->has_coercion...))
	else {
		$C->add_type_coercions(
			$parent => sub {
				my $value = @_ ? $_[0] : $_;
				my %new;
				for my $k ( keys %$value ) {
					return $value
						unless $kcoercable_item->check( $k )
						&& $vcoercable_item->check( $value->{$k} );
					$new{ $kparam->has_coercion ? $kparam->coerce( $k ) : $k } =
						$vparam->has_coercion
						? $vparam->coerce( $value->{$k} )
						: $value->{$k};
				}
				return \%new;
			},
		);
	} #/ else [ if ( ( !$kparam->has_coercion...))]
	
	return $C;
} #/ sub __coercion_generator

sub __hashref_allows_key {
	my $self = shift;
	my ( $key ) = @_;
	
	return Types::Standard::is_Str( $key ) if $self == Types::Standard::Map();
	
	my $map = $self->find_parent(
		sub { $_->has_parent && $_->parent == Types::Standard::Map() } );
	my ( $kcheck, $vcheck ) = @{ $map->parameters };
	
	( $kcheck or Types::Standard::Any() )->check( $key );
} #/ sub __hashref_allows_key

sub __hashref_allows_value {
	my $self = shift;
	my ( $key, $value ) = @_;
	
	return !!0 unless $self->my_hashref_allows_key( $key );
	return !!1 if $self == Types::Standard::Map();
	
	my $map = $self->find_parent(
		sub { $_->has_parent && $_->parent == Types::Standard::Map() } );
	my ( $kcheck, $vcheck ) = @{ $map->parameters };
	
	( $kcheck or Types::Standard::Any() )->check( $key )
		and ( $vcheck or Types::Standard::Any() )->check( $value );
} #/ sub __hashref_allows_value

1;
