package Types::Common::Numeric;

use 5.008001;
use strict;
use warnings;

BEGIN {
	$Types::Common::Numeric::AUTHORITY = 'cpan:TOBYINK';
	$Types::Common::Numeric::VERSION   = '2.000001';
}

$Types::Common::Numeric::VERSION =~ tr/_//d;

use Type::Library -base, -declare => qw(
	PositiveNum PositiveOrZeroNum
	PositiveInt PositiveOrZeroInt
	NegativeNum NegativeOrZeroNum
	NegativeInt NegativeOrZeroInt
	SingleDigit
	NumRange IntRange
);

use Type::Tiny ();
use Types::Standard qw( Num Int Bool );

sub _croak ($;@) { require Error::TypeTiny; goto \&Error::TypeTiny::croak }

my $meta = __PACKAGE__->meta;

$meta->add_type(
	name       => 'PositiveNum',
	parent     => Num,
	constraint => sub { $_ > 0 },
	inlined    => sub { undef, qq($_ > 0) },
	message    => sub { "Must be a positive number" },
);

$meta->add_type(
	name       => 'PositiveOrZeroNum',
	parent     => Num,
	constraint => sub { $_ >= 0 },
	inlined    => sub { undef, qq($_ >= 0) },
	message    => sub { "Must be a number greater than or equal to zero" },
	type_default => sub { return 0; },
);

my ( $pos_int, $posz_int );
if ( Type::Tiny::_USE_XS ) {
	$pos_int = Type::Tiny::XS::get_coderef_for( 'PositiveInt' )
		if Type::Tiny::XS->VERSION >= 0.013;    # fixed bug with "00"
	$posz_int = Type::Tiny::XS::get_coderef_for( 'PositiveOrZeroInt' );
}

$meta->add_type(
	name       => 'PositiveInt',
	parent     => Int,
	constraint => sub { $_ > 0 },
	inlined    => sub {
		if ( $pos_int ) {
			my $xsub = Type::Tiny::XS::get_subname_for( $_[0]->name );
			return "$xsub($_[1])" if $xsub && !$Type::Tiny::AvoidCallbacks;
		}
		undef, qq($_ > 0);
	},
	message => sub { "Must be a positive integer" },
	$pos_int ? ( compiled_type_constraint => $pos_int ) : (),
);

$meta->add_type(
	name       => 'PositiveOrZeroInt',
	parent     => Int,
	constraint => sub { $_ >= 0 },
	inlined    => sub {
		if ( $posz_int ) {
			my $xsub = Type::Tiny::XS::get_subname_for( $_[0]->name );
			return "$xsub($_[1])" if $xsub && !$Type::Tiny::AvoidCallbacks;
		}
		undef, qq($_ >= 0);
	},
	message => sub { "Must be an integer greater than or equal to zero" },
	$posz_int ? ( compiled_type_constraint => $posz_int ) : (),
	type_default => sub { return 0; },
);

$meta->add_type(
	name       => 'NegativeNum',
	parent     => Num,
	constraint => sub { $_ < 0 },
	inlined    => sub { undef, qq($_ < 0) },
	message    => sub { "Must be a negative number" },
);

$meta->add_type(
	name       => 'NegativeOrZeroNum',
	parent     => Num,
	constraint => sub { $_ <= 0 },
	inlined    => sub { undef, qq($_ <= 0) },
	message    => sub { "Must be a number less than or equal to zero" },
	type_default => sub { return 0; },
);

$meta->add_type(
	name       => 'NegativeInt',
	parent     => Int,
	constraint => sub { $_ < 0 },
	inlined    => sub { undef, qq($_ < 0) },
	message    => sub { "Must be a negative integer" },
);

$meta->add_type(
	name       => 'NegativeOrZeroInt',
	parent     => Int,
	constraint => sub { $_ <= 0 },
	inlined    => sub { undef, qq($_ <= 0) },
	message    => sub { "Must be an integer less than or equal to zero" },
	type_default => sub { return 0; },
);

$meta->add_type(
	name       => 'SingleDigit',
	parent     => Int,
	constraint => sub { $_ >= -9 and $_ <= 9 },
	inlined    => sub { undef, qq($_ >= -9), qq($_ <= 9) },
	message    => sub { "Must be a single digit" },
	type_default => sub { return 0; },
);

for my $base ( qw/Num Int/ ) {
	$meta->add_type(
		name                 => "${base}Range",
		parent               => Types::Standard->get_type( $base ),
		constraint_generator => sub {
			return $meta->get_type( "${base}Range" ) unless @_;
			
			my $base_obj = Types::Standard->get_type( $base );
			
			my ( $min, $max, $min_excl, $max_excl ) = @_;
			!defined( $min )
				or $base_obj->check( $min )
				or _croak(
				"${base}Range min must be a %s; got %s", lc( $base ),
				$min
				);
			!defined( $max )
				or $base_obj->check( $max )
				or _croak(
				"${base}Range max must be a %s; got %s", lc( $base ),
				$max
				);
			!defined( $min_excl )
				or Bool->check( $min_excl )
				or _croak( "${base}Range minexcl must be a boolean; got $min_excl" );
			!defined( $max_excl )
				or Bool->check( $max_excl )
				or _croak( "${base}Range maxexcl must be a boolean; got $max_excl" );
				
			# this is complicated so defer to the inline generator
			eval sprintf(
				'sub { %s }',
				join ' and ',
				grep defined,
				$meta->get_type( "${base}Range" )->inline_generator->( @_ )->( undef, '$_[0]' ),
			);
		},
		inline_generator => sub {
			my ( $min, $max, $min_excl, $max_excl ) = @_;
			
			my $gt = $min_excl ? '>' : '>=';
			my $lt = $max_excl ? '<' : '<=';
			
			return sub {
				my $v    = $_[1];
				my @code = ( undef );    # parent constraint
				push @code, "$v $gt $min";
				push @code, "$v $lt $max" if defined $max;
				return @code;
			};
		},
		deep_explanation => sub {
			my ( $type, $value, $varname ) = @_;
			my ( $min, $max, $min_excl, $max_excl ) = @{ $type->parameters || [] };
			my @whines;
			if ( defined $max ) {
				push @whines, sprintf(
					'"%s" expects %s to be %s %d and %s %d',
					$type,
					$varname,
					$min_excl ? 'greater than' : 'at least',
					$min,
					$max_excl ? 'less than' : 'at most',
					$max,
				);
			} #/ if ( defined $max )
			else {
				push @whines, sprintf(
					'"%s" expects %s to be %s %d',
					$type,
					$varname,
					$min_excl ? 'greater than' : 'at least',
					$min,
				);
			}
			push @whines, sprintf(
				"%s is %s",
				$varname,
				$value,
			);
			return \@whines;
		},
	);
} #/ for my $base ( qw/Num Int/)

__PACKAGE__->meta->make_immutable;

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Types::Common::Numeric - drop-in replacement for MooseX::Types::Common::Numeric

=head1 STATUS

This module is covered by the
L<Type-Tiny stability policy|Type::Tiny::Manual::Policies/"STABILITY">.

=head1 DESCRIPTION

A drop-in replacement for L<MooseX::Types::Common::Numeric>.

=head2 Types

The following types are similar to those described in
L<MooseX::Types::Common::Numeric>.

=over

=item *

B<PositiveNum>

=item *

B<PositiveOrZeroNum>

=item *

B<PositiveInt>

=item *

B<PositiveOrZeroInt>

=item *

B<NegativeNum>

=item *

B<NegativeOrZeroNum>

=item *

B<NegativeInt>

=item *

B<NegativeOrZeroInt>

=item *

B<SingleDigit>

C<SingleDigit> interestingly accepts the numbers -9 to -1; not
just 0 to 9. 

=back

This module also defines an extra pair of type constraints not found in
L<MooseX::Types::Common::Numeric>.

=over

=item *

B<< IntRange[`min, `max] >>

Type constraint for an integer between min and max. For example:

  IntRange[1, 10]

The maximum can be omitted.

  IntRange[10]   # at least 10

The minimum and maximum are inclusive.

=item *

B<< NumRange[`min, `max] >>

Type constraint for a number between min and max. For example:

  NumRange[0.1, 10.0]

As with IntRange, the maximum can be omitted, and the minimum and maximum
are inclusive.

Exclusive ranges can be useful for non-integer values, so additional parameters
can be given to make the minimum and maximum exclusive.

  NumRange[0.1, 10.0, 0, 0]  # both inclusive
  NumRange[0.1, 10.0, 0, 1]  # exclusive maximum, so 10.0 is invalid
  NumRange[0.1, 10.0, 1, 0]  # exclusive minimum, so 0.1 is invalid
  NumRange[0.1, 10.0, 1, 1]  # both exclusive

Making one of the limits exclusive means that a C<< < >> or C<< > >> operator
will be used instead of the usual C<< <= >> or C<< >= >> operators.

=back

=head1 BUGS

Please report any bugs to
L<https://github.com/tobyink/p5-type-tiny/issues>.

=head1 SEE ALSO

L<Types::Standard>, L<Types::Common::String>.

L<MooseX::Types::Common>,
L<MooseX::Types::Common::Numeric>,
L<MooseX::Types::Common::String>.

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
