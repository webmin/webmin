package Type::Coercion::Union;

use 5.008001;
use strict;
use warnings;

BEGIN {
	$Type::Coercion::Union::AUTHORITY = 'cpan:TOBYINK';
	$Type::Coercion::Union::VERSION   = '2.000001';
}

$Type::Coercion::Union::VERSION =~ tr/_//d;

use Scalar::Util qw< blessed >;
use Types::TypeTiny ();

sub _croak ($;@) { require Error::TypeTiny; goto \&Error::TypeTiny::croak }

require Type::Coercion;
our @ISA = 'Type::Coercion';

sub _preserve_type_constraint {
	my $self = shift;
	$self->{_union_of} = $self->{type_constraint}->type_constraints
		if $self->{type_constraint};
}

sub _maybe_restore_type_constraint {
	my $self = shift;
	if ( my $union = $self->{_union_of} ) {
		return Type::Tiny::Union->new( type_constraints => $union );
	}
	return;    # uncoverable statement
}

sub type_coercion_map {
	my $self = shift;
	
	Types::TypeTiny::assert_TypeTiny( my $type = $self->type_constraint );
	$type->isa( 'Type::Tiny::Union' )
		or _croak
		"Type::Coercion::Union must be used in conjunction with Type::Tiny::Union";
		
	my @c;
	for my $tc ( @$type ) {
		next unless $tc->has_coercion;
		push @c, @{ $tc->coercion->type_coercion_map };
	}
	return \@c;
} #/ sub type_coercion_map

sub add_type_coercions {
	my $self = shift;
	_croak "Adding coercions to Type::Coercion::Union not currently supported"
		if @_;
}

sub _build_moose_coercion {
	my $self = shift;
	
	my %options = ();
	$options{type_constraint} = $self->type_constraint
		if $self->has_type_constraint;
		
	require Moose::Meta::TypeCoercion::Union;
	my $r = "Moose::Meta::TypeCoercion::Union"->new( %options );
	
	return $r;
} #/ sub _build_moose_coercion

sub can_be_inlined {
	my $self = shift;
	
	Types::TypeTiny::assert_TypeTiny( my $type = $self->type_constraint );
	
	for my $tc ( @$type ) {
		next       unless $tc->has_coercion;
		return !!0 unless $tc->coercion->can_be_inlined;
	}
	
	!!1;
} #/ sub can_be_inlined

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Type::Coercion::Union - a set of coercions to a union type constraint

=head1 STATUS

This module is covered by the
L<Type-Tiny stability policy|Type::Tiny::Manual::Policies/"STABILITY">.

=head1 DESCRIPTION

This package inherits from L<Type::Coercion>; see that for most documentation.
The major differences are that C<add_type_coercions> always throws an
exception, and the C<type_coercion_map> is automatically populated from
the child constraints of the union type constraint.

=head1 BUGS

Please report any bugs to
L<https://github.com/tobyink/p5-type-tiny/issues>.

=head1 SEE ALSO

L<Type::Coercion>.

L<Moose::Meta::TypeCoercion::Union>.

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
