package Type::Tiny::_HalfOp;

use 5.008001;
use strict;
use warnings;

BEGIN {
	$Type::Tiny::_HalfOp::AUTHORITY = 'cpan:TOBYINK';
	$Type::Tiny::_HalfOp::VERSION   = '2.000001';
}

$Type::Tiny::_HalfOp::VERSION =~ tr/_//d;

sub new {
	my ( $class, $op, $param, $type ) = @_;
	bless {
		op    => $op,
		param => $param,
		type  => $type,
	}, $class;
}

sub complete {
	require overload;
	my ( $self, $type ) = @_;
	my $complete_type = $type->parameterize( @{ $self->{param} } );
	my $method        = overload::Method( $complete_type, $self->{op} );
	$complete_type->$method( $self->{type}, undef );
}

1;

__END__

=pod

=encoding utf-8

=for stopwords pragmas

=head1 NAME

Type::Tiny::_HalfOp - half-completed overloaded operation

=head1 STATUS

This module is considered part of Type-Tiny's internals. It is not
covered by the
L<Type-Tiny stability policy|Type::Tiny::Manual::Policies/"STABILITY">.

=head1 DESCRIPTION

This is not considered part of Type::Tiny's public API.

It is a class representing a half-completed overloaded operation.

=head2 Constructor

=over

=item C<< new($operation, $param, $type) >>

=back

=head2 Method

=over

=item C<< complete($type) >>

=back

=head1 BUGS

Please report any bugs to
L<https://github.com/tobyink/p5-type-tiny/issues>.

=head1 AUTHOR

Graham Knop E<lt>haarg@cpan.orgE<gt>.

=head1 COPYRIGHT AND LICENCE

This software is copyright (c) 2014, 2017-2022 by Graham Knop.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=head1 DISCLAIMER OF WARRANTIES

THIS PACKAGE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.
