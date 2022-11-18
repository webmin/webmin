package Error::TypeTiny::Compilation;

use 5.008001;
use strict;
use warnings;

BEGIN {
	$Error::TypeTiny::Compilation::AUTHORITY = 'cpan:TOBYINK';
	$Error::TypeTiny::Compilation::VERSION   = '2.000001';
}

$Error::TypeTiny::Compilation::VERSION =~ tr/_//d;

require Error::TypeTiny;
our @ISA = 'Error::TypeTiny';

sub code        { $_[0]{code} }
sub environment { $_[0]{environment} ||= {} }
sub errstr      { $_[0]{errstr} }

sub _build_message {
	my $self = shift;
	sprintf( "Failed to compile source because: %s", $self->errstr );
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Error::TypeTiny::Compilation - exception for Eval::TypeTiny

=head1 STATUS

This module is covered by the
L<Type-Tiny stability policy|Type::Tiny::Manual::Policies/"STABILITY">.

=head1 DESCRIPTION

Thrown when compiling a closure fails. Common causes are problems with
inlined type constraints, and syntax errors when coercions are given as
strings of Perl code.

This package inherits from L<Error::TypeTiny>; see that for most
documentation. Major differences are listed below:

=head2 Attributes

=over

=item C<code>

The Perl source code being compiled.

=item C<environment>

Hashref of variables being closed over.

=item C<errstr>

Error message from Perl compiler.

=back

=head1 BUGS

Please report any bugs to
L<https://github.com/tobyink/p5-type-tiny/issues>.

=head1 SEE ALSO

L<Error::TypeTiny>.

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
