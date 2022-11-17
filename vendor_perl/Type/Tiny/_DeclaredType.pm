package Type::Tiny::_DeclaredType;

use 5.008001;
use strict;
use warnings;

BEGIN {
	$Type::Tiny::_DeclaredType::AUTHORITY = 'cpan:TOBYINK';
	$Type::Tiny::_DeclaredType::VERSION   = '2.000001';
}

$Type::Tiny::_DeclaredType::VERSION =~ tr/_//d;

use Type::Tiny ();
our @ISA = qw( Type::Tiny );

sub new {
	my $class   = shift;
	my %opts    = @_ == 1 ? %{ +shift } : @_;
	
	my $library = delete $opts{library};
	my $name    = delete $opts{name};
	
	$library->can( 'get_type' )
		or Type::Tiny::_croak( "Expected $library to be a type library, but it doesn't seem to be" );
	
	$opts{display_name} = $name;
	$opts{constraint}   = sub {
		my $val = @_ ? pop : $_;
		$library->get_type( $name )->check( $val );
	};
	$opts{inlined} = sub {
		my $val = @_ ? pop : $_;
		sprintf( '%s::is_%s(%s)', $library, $name, $val );
	};
	$opts{_build_coercion} = sub {
		my $realtype = $library->get_type( $name );
		$_[0] = $realtype->coercion if $realtype;
	};
	$class->SUPER::new( %opts );
} #/ sub new

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Type::Tiny::_DeclaredType - half-defined type constraint

=head1 STATUS

This module is considered part of Type-Tiny's internals. It is not
covered by the
L<Type-Tiny stability policy|Type::Tiny::Manual::Policies/"STABILITY">.

=head1 DESCRIPTION

This is not considered part of Type::Tiny's public API.

It is a class representing a declared-but-not-defined type constraint.
It inherits from L<Type::Tiny>.

=head2 Constructor

=over

=item C<< new(%options) >>

=back

=head1 BUGS

Please report any bugs to
L<https://github.com/tobyink/p5-type-tiny/issues>.

=head1 AUTHOR

Toby Inkster E<lt>tobyink@cpan.orgE<gt>.

=head1 COPYRIGHT AND LICENCE

This software is copyright (c) 2013-2022 by Toby Inkster.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=head1 DISCLAIMER OF WARRANTIES

THIS PACKAGE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.
