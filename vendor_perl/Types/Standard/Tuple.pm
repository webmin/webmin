# INTERNAL MODULE: guts for Tuple type from Types::Standard.

package Types::Standard::Tuple;

use 5.008001;
use strict;
use warnings;

BEGIN {
	$Types::Standard::Tuple::AUTHORITY = 'cpan:TOBYINK';
	$Types::Standard::Tuple::VERSION   = '2.000001';
}

$Types::Standard::Tuple::VERSION =~ tr/_//d;

use Type::Tiny      ();
use Types::Standard ();
use Types::TypeTiny ();

sub _croak ($;@) { require Error::TypeTiny; goto \&Error::TypeTiny::croak }

my $_Optional = Types::Standard::Optional;
my $_Slurpy   = Types::Standard::Slurpy;

no warnings;

sub __constraint_generator {
	my $slurpy =
		@_
		&& Types::TypeTiny::is_TypeTiny( $_[-1] )
		&& $_[-1]->is_strictly_a_type_of( $_Slurpy )
		? pop
		: undef;
		
	my @constraints = @_;
	for ( @constraints ) {
		Types::TypeTiny::is_TypeTiny( $_ )
			or
			_croak( "Parameters to Tuple[...] expected to be type constraints; got $_" );
	}
	
	# By god, the Type::Tiny::XS API is currently horrible
	my @xsub;
	if ( Type::Tiny::_USE_XS and !$slurpy ) {
		my @known = map {
			my $known;
			$known = Type::Tiny::XS::is_known( $_->compiled_check )
				unless $_->is_strictly_a_type_of( $_Optional );
			defined( $known ) ? $known : ();
		} @constraints;
		
		if ( @known == @constraints ) {
			my $xsub = Type::Tiny::XS::get_coderef_for(
				sprintf( "Tuple[%s]", join( ',', @known ) ) );
			push @xsub, $xsub if $xsub;
		}
	} #/ if ( Type::Tiny::_USE_XS...)
	
	my @is_optional = map !!$_->is_strictly_a_type_of( $_Optional ), @constraints;
	my $slurp_hash  = $slurpy && $slurpy->my_slurp_into eq 'HASH';
	my $slurp_any   = $slurpy && $slurpy->my_unslurpy->equals( Types::Standard::Any );
	
	my @sorted_is_optional = sort @is_optional;
	join( "|", @sorted_is_optional ) eq join( "|", @is_optional )
		or _croak(
		"Optional parameters to Tuple[...] cannot precede required parameters" );
		
	sub {
		my $value = $_[0];
		if ( $#constraints < $#$value ) {
			return !!0 unless $slurpy;
			my $tmp;
			if ( $slurp_hash ) {
				( $#$value - $#constraints + 1 ) % 2 or return;
				$tmp = +{ @$value[ $#constraints + 1 .. $#$value ] };
				$slurpy->check( $tmp ) or return;
			}
			elsif ( not $slurp_any ) {
				$tmp = +[ @$value[ $#constraints + 1 .. $#$value ] ];
				$slurpy->check( $tmp ) or return;
			}
		} #/ if ( $#constraints < $#$value)
		for my $i ( 0 .. $#constraints ) {
			( $i > $#$value )
				and return !!$is_optional[$i];
				
			$constraints[$i]->check( $value->[$i] )
				or return !!0;
		}
		return !!1;
	}, @xsub;
} #/ sub __constraint_generator

sub __inline_generator {
	my $slurpy =
		@_
		&& Types::TypeTiny::is_TypeTiny( $_[-1] )
		&& $_[-1]->is_strictly_a_type_of( $_Slurpy )
		? pop
		: undef;
	my @constraints = @_;
	
	return if grep { not $_->can_be_inlined } @constraints;
	return if defined $slurpy && !$slurpy->can_be_inlined;
	
	my $xsubname;
	if ( Type::Tiny::_USE_XS and !$slurpy ) {
		my @known = map {
			my $known;
			$known = Type::Tiny::XS::is_known( $_->compiled_check )
				unless $_->is_strictly_a_type_of( $_Optional );
			defined( $known ) ? $known : ();
		} @constraints;
		
		if ( @known == @constraints ) {
			$xsubname = Type::Tiny::XS::get_subname_for(
				sprintf( "Tuple[%s]", join( ',', @known ) ) );
		}
	} #/ if ( Type::Tiny::_USE_XS...)
	
	my $tmpl = "do { my \$tmp = +[\@{%s}[%d..\$#{%s}]]; %s }";
	my $slurpy_any;
	if ( defined $slurpy ) {
		$tmpl =
			'do { my ($orig, $from, $to) = (%s, %d, $#{%s});'
			. '(($to-$from) %% 2) and do { my $tmp = +{@{$orig}[$from..$to]}; %s }'
			. '}'
			if $slurpy->my_slurp_into eq 'HASH';
		$slurpy_any = 1
			if $slurpy->my_unslurpy->equals( Types::Standard::Any );
	}
	
	my @is_optional = map !!$_->is_strictly_a_type_of( $_Optional ), @constraints;
	my $min = 0+ grep !$_, @is_optional;
	
	return sub {
		my $v = $_[1];
		return "$xsubname\($v\)" if $xsubname && !$Type::Tiny::AvoidCallbacks;
		join " and ",
			Types::Standard::ArrayRef->inline_check( $v ),
			(
			( scalar @constraints == $min and not $slurpy )
			? "\@{$v} == $min"
			: sprintf(
				"(\@{$v} == $min or (\@{$v} > $min and \@{$v} <= ${\(1+$#constraints)}) or (\@{$v} > ${\(1+$#constraints)} and %s))",
				(
					$slurpy_any ? '!!1'
					: (
						$slurpy
						? sprintf( $tmpl, $v, $#constraints + 1, $v, $slurpy->inline_check( '$tmp' ) )
						: sprintf( "\@{$v} <= %d", scalar @constraints )
					)
				),
			)
			),
			map {
			my $inline = $constraints[$_]->inline_check( "$v\->[$_]" );
			$inline eq '(!!1)' ? ()
				: (
				$is_optional[$_] ? sprintf( '(@{%s} <= %d or %s)', $v, $_, $inline )
				: $inline
				);
			} 0 .. $#constraints;
	};
} #/ sub __inline_generator

sub __deep_explanation {
	my ( $type, $value, $varname ) = @_;
	
	my @constraints = @{ $type->parameters };
	my $slurpy =
		@constraints
		&& Types::TypeTiny::is_TypeTiny( $constraints[-1] )
		&& $constraints[-1]->is_strictly_a_type_of( $_Slurpy )
		? pop( @constraints )
		: undef;
	@constraints = map Types::TypeTiny::to_TypeTiny( $_ ), @constraints;
	
	if ( @constraints < @$value and not $slurpy ) {
		return [
			sprintf(
				'"%s" expects at most %d values in the array', $type, scalar( @constraints )
			),
			sprintf( '%d values found; too many', scalar( @$value ) ),
		];
	}
	
	for my $i ( 0 .. $#constraints ) {
		next
			if $constraints[$i]
			->is_strictly_a_type_of( Types::Standard::Optional )
			&& $i > $#$value;
		next if $constraints[$i]->check( $value->[$i] );
		
		return [
			sprintf(
				'"%s" constrains value at index %d of array with "%s"', $type, $i,
				$constraints[$i]
			),
			@{
				$constraints[$i]
					->validate_explain( $value->[$i], sprintf( '%s->[%s]', $varname, $i ) )
			},
		];
	} #/ for my $i ( 0 .. $#constraints)
	
	if ( defined( $slurpy ) ) {
		my $tmp =
			$slurpy->my_slurp_into eq 'HASH'
			? +{ @$value[ $#constraints + 1 .. $#$value ] }
			: +[ @$value[ $#constraints + 1 .. $#$value ] ];
		$slurpy->check( $tmp )
			or return [
			sprintf(
				'Array elements from index %d are slurped into a %s which is constrained with "%s"',
				$#constraints + 1,
				( $slurpy->my_slurp_into eq 'HASH' ) ? 'hashref' : 'arrayref',
				( $slurpy->my_unslurpy || $slurpy ),
			),
			@{ ( $slurpy->my_unslurpy || $slurpy )->validate_explain( $tmp, '$SLURPY' ) },
			];
	} #/ if ( defined( $slurpy ...))
	
	# This should never happen...
	return;    # uncoverable statement
} #/ sub __deep_explanation

my $label_counter = 0;

sub __coercion_generator {
	my ( $parent, $child, @tuple ) = @_;
	
	my $slurpy =
		@tuple
		&& Types::TypeTiny::is_TypeTiny( $tuple[-1] )
		&& $tuple[-1]->is_strictly_a_type_of( $_Slurpy )
		? pop( @tuple )
		: undef;
	
	my $child_coercions_exist = 0;
	my $all_inlinable         = 1;
	for my $tc ( @tuple, ( $slurpy ? $slurpy : () ) ) {
		$all_inlinable = 0 if !$tc->can_be_inlined;
		$all_inlinable = 0 if $tc->has_coercion && !$tc->coercion->can_be_inlined;
		$child_coercions_exist++ if $tc->has_coercion;
	}
	
	return unless $child_coercions_exist;
	my $C = "Type::Coercion"->new( type_constraint => $child );
	
	my $slurpy_is_hashref = $slurpy && $slurpy->my_slurp_into eq 'HASH';
		
	if ( $all_inlinable ) {
		$C->add_type_coercions(
			$parent => Types::Standard::Stringable {
				my $label = sprintf( "TUPLELABEL%d", ++$label_counter );
				my @code;
				push @code, 'do { my ($orig, $return_orig, $tmp, @new) = ($_, 0);';
				push @code, "$label: {";
				push @code,
					sprintf(
					'(($return_orig = 1), last %s) if @$orig > %d;', $label,
					scalar @tuple
					) unless $slurpy;
				for my $i ( 0 .. $#tuple ) {
					my $ct          = $tuple[$i];
					my $ct_coerce   = $ct->has_coercion;
					my $ct_optional = $ct->is_a_type_of( Types::Standard::Optional );
					
					push @code, sprintf(
						'if (@$orig > %d) { $tmp = %s; (%s) ? ($new[%d]=$tmp) : (($return_orig=1), last %s) }',
						$i,
						$ct_coerce
						? $ct->coercion->inline_coercion( "\$orig->[$i]" )
						: "\$orig->[$i]",
						$ct->inline_check( '$tmp' ),
						$i,
						$label,
					);
				} #/ for my $i ( 0 .. $#tuple)
				if ( $slurpy ) {
					my $size = @tuple;
					push @code, sprintf( 'if (@$orig > %d) {', $size );
					push @code, sprintf(
						(
							$slurpy_is_hashref
							? 'my $tail = do { no warnings; +{ @{$orig}[%d .. $#$orig]} };'
							: 'my $tail = [ @{$orig}[%d .. $#$orig] ];'
						),
						$size,
					);
					push @code,
						$slurpy->has_coercion
						? sprintf(
						'$tail = %s;',
						$slurpy->coercion->inline_coercion( '$tail' )
						)
						: q();
					push @code, sprintf(
						'(%s) ? push(@new, %s$tail) : ($return_orig++);',
						$slurpy->inline_check( '$tail' ),
						( $slurpy_is_hashref ? '%' : '@' ),
					);
					push @code, '}';
				} #/ if ( $slurpy )
				push @code, '}';
				push @code, '$return_orig ? $orig : \\@new';
				push @code, '}';
				"@code";
			}
		);
	} #/ if ( $all_inlinable )
	
	else {
		my @is_optional = map !!$_->is_strictly_a_type_of( $_Optional ), @tuple;
		
		$C->add_type_coercions(
			$parent => sub {
				my $value = @_ ? $_[0] : $_;
				
				if ( !$slurpy and @$value > @tuple ) {
					return $value;
				}
				
				my @new;
				for my $i ( 0 .. $#tuple ) {
					return \@new if $i > $#$value and $is_optional[$i];
					
					my $ct = $tuple[$i];
					my $x  = $ct->has_coercion ? $ct->coerce( $value->[$i] ) : $value->[$i];
					
					return $value unless $ct->check( $x );
					
					$new[$i] = $x;
				} #/ for my $i ( 0 .. $#tuple)
				
				if ( $slurpy and @$value > @tuple ) {
					no warnings;
					my $tmp =
						$slurpy_is_hashref
						? { @{$value}[ @tuple .. $#$value ] }
						: [ @{$value}[ @tuple .. $#$value ] ];
					$tmp = $slurpy->coerce( $tmp ) if $slurpy->has_coercion;
					$slurpy->check( $tmp )
						? push( @new, $slurpy_is_hashref ? %$tmp : @$tmp )
						: return ( $value );
				} #/ if ( $slurpy and @$value...)
				
				return \@new;
			},
		);
	} #/ else [ if ( $all_inlinable ) ]
	
	return $C;
} #/ sub __coercion_generator

1;
