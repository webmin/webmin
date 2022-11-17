package Type::Coercion::FromMoose;

use 5.008001;
use strict;
use warnings;

BEGIN {
	$Type::Coercion::FromMoose::AUTHORITY = 'cpan:TOBYINK';
	$Type::Coercion::FromMoose::VERSION   = '2.000001';
}

$Type::Coercion::FromMoose::VERSION =~ tr/_//d;

use Scalar::Util qw< blessed >;
use Types::TypeTiny ();

sub _croak ($;@) { require Error::TypeTiny; goto \&Error::TypeTiny::croak }

require Type::Coercion;
our @ISA = 'Type::Coercion';

sub type_coercion_map {
	my $self = shift;
	
	my @from;
	if ( $self->type_constraint ) {
		my $moose = $self->type_constraint->{moose_type};
		@from = @{ $moose->coercion->type_coercion_map }
			if $moose && $moose->has_coercion;
	}
	else {
		_croak
			"The type constraint attached to this coercion has been garbage collected... PANIC";
	}
	
	my @return;
	while ( @from ) {
		my ( $type, $code ) = splice( @from, 0, 2 );
		$type = Moose::Util::TypeConstraints::find_type_constraint( $type )
			unless ref $type;
		push @return, Types::TypeTiny::to_TypeTiny( $type ), $code;
	}
	
	return \@return;
} #/ sub type_coercion_map

sub add_type_coercions {
	my $self = shift;
	_croak "Adding coercions to Type::Coercion::FromMoose not currently supported"
		if @_;
}

sub _build_moose_coercion {
	my $self = shift;
	
	if ( $self->type_constraint ) {
		my $moose = $self->type_constraint->{moose_type};
		return $moose->coercion if $moose && $moose->has_coercion;
	}
	
	$self->SUPER::_build_moose_coercion( @_ );
} #/ sub _build_moose_coercion

sub can_be_inlined {
	0;
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Type::Coercion::FromMoose - a set of coercions borrowed from Moose

=head1 STATUS

This module is considered part of Type-Tiny's internals. It is not
covered by the
L<Type-Tiny stability policy|Type::Tiny::Manual::Policies/"STABILITY">.

=head1 DESCRIPTION

This package inherits from L<Type::Coercion>; see that for most documentation.
The major differences are that C<add_type_coercions> always throws an
exception, and the C<type_coercion_map> is automatically populated from
Moose.

This is mostly for internal purposes.

=head1 BUGS

Please report any bugs to
L<https://github.com/tobyink/p5-type-tiny/issues>.

=head1 SEE ALSO

L<Type::Coercion>.

L<Moose::Meta::TypeCoercion>.

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
