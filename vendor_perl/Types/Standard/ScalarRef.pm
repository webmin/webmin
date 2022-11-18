# INTERNAL MODULE: guts for ScalarRef type from Types::Standard.

package Types::Standard::ScalarRef;

use 5.008001;
use strict;
use warnings;

BEGIN {
	$Types::Standard::ScalarRef::AUTHORITY = 'cpan:TOBYINK';
	$Types::Standard::ScalarRef::VERSION   = '2.000001';
}

$Types::Standard::ScalarRef::VERSION =~ tr/_//d;

use Types::Standard ();
use Types::TypeTiny ();

sub _croak ($;@) { require Error::TypeTiny; goto \&Error::TypeTiny::croak }

no warnings;

sub __constraint_generator {
	return Types::Standard::ScalarRef unless @_;
	
	my $param = shift;
	Types::TypeTiny::is_TypeTiny( $param )
		or _croak(
		"Parameter to ScalarRef[`a] expected to be a type constraint; got $param" );
		
	return sub {
		my $ref = shift;
		$param->check( $$ref ) || return;
		return !!1;
	};
} #/ sub __constraint_generator

sub __inline_generator {
	my $param = shift;
	return unless $param->can_be_inlined;
	return sub {
		my $v           = $_[1];
		my $param_check = $param->inline_check( "\${$v}" );
		"(ref($v) eq 'SCALAR' or ref($v) eq 'REF') and $param_check";
	};
}

sub __deep_explanation {
	my ( $type, $value, $varname ) = @_;
	my $param = $type->parameters->[0];
	
	for my $item ( $$value ) {
		next if $param->check( $item );
		return [
			sprintf(
				'"%s" constrains the referenced scalar value with "%s"', $type, $param
			),
			@{ $param->validate_explain( $item, sprintf( '${%s}', $varname ) ) },
		];
	}
	
	# This should never happen...
	return;    # uncoverable statement
} #/ sub __deep_explanation

sub __coercion_generator {
	my ( $parent, $child, $param ) = @_;
	return unless $param->has_coercion;
	
	my $coercable_item = $param->coercion->_source_type_union;
	my $C              = "Type::Coercion"->new( type_constraint => $child );
	
	if ( $param->coercion->can_be_inlined and $coercable_item->can_be_inlined ) {
		$C->add_type_coercions(
			$parent => Types::Standard::Stringable {
				my @code;
				push @code, 'do { my ($orig, $return_orig, $new) = ($_, 0);';
				push @code, 'for ($$orig) {';
				push @code,
					sprintf(
					'++$return_orig && last unless (%s);',
					$coercable_item->inline_check( '$_' )
					);
				push @code,
					sprintf(
					'$new = (%s);',
					$param->coercion->inline_coercion( '$_' )
					);
				push @code, '}';
				push @code, '$return_orig ? $orig : \\$new';
				push @code, '}';
				"@code";
			}
		);
	} #/ if ( $param->coercion->...)
	else {
		$C->add_type_coercions(
			$parent => sub {
				my $value = @_ ? $_[0] : $_;
				my $new;
				for my $item ( $$value ) {
					return $value unless $coercable_item->check( $item );
					$new = $param->coerce( $item );
				}
				return \$new;
			},
		);
	} #/ else [ if ( $param->coercion->...)]
	
	return $C;
} #/ sub __coercion_generator

1;
