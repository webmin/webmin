package Types::Common;

use 5.008001;
use strict;
use warnings;

BEGIN {
	eval { require re };
	if ( $] < 5.010 ) { require Devel::TypeTiny::Perl58Compat }
}

BEGIN {
	$Types::Common::AUTHORITY = 'cpan:TOBYINK';
	$Types::Common::VERSION   = '2.000001';
}

our ( @EXPORT, @EXPORT_OK, %EXPORT_TAGS );

use Type::Library
	-extends => [ qw(
		Types::Standard
		Types::Common::Numeric
		Types::Common::String
		Types::TypeTiny
	) ];

use Type::Params -sigs;
$EXPORT_TAGS{sigs} = $Type::Params::EXPORT_TAGS{sigs};
push @EXPORT_OK, @{ $EXPORT_TAGS{sigs} };

sub _generate_t {
	my $package = shift;
	require Type::Registry;
	my $t = 'Type::Registry'->_generate_t( @_ );
	$t->()->add_types( $package );
	return $t;
}
push @EXPORT_OK, 't';

__PACKAGE__->meta->make_immutable;

__END__

=pod

=encoding utf-8

=for stopwords arrayfication hashification

=head1 NAME

Types::Common - the one stop shop

=head1 STATUS

This module is covered by the
L<Type-Tiny stability policy|Type::Tiny::Manual::Policies/"STABILITY">.

=head1 DESCRIPTION

Types::Common doesn't provide any types or functions of its own.
Instead it's a single module that re-exports:

=over

=item *

All the types from L<Types::Standard>.

=item *

All the types from L<Types::Common::Numeric> and L<Types::Common::String>.

=item *

All the types from L<Types::TypeTiny>.

=item *

The C<< -sigs >> tag from L<Type::Params>.

=item *

The C<< t() >> function from L<Type::Registry>.

=back

If you import C<< t() >>, it will also be preloaded with all the type
constraints offered by Types::Common.

=head1 EXPORT

C<< use Types::Common qw( -types -sigs t ) >> might be a sensible place
to start.

C<< use Types::Common -all >> gives you everything.

If you have Perl 5.37.2+, then C<< use Types::Common qw( -lexical -all ) >>
won't pollute your namespace.

=head1 BUGS

Please report any bugs to
L<https://github.com/tobyink/p5-type-tiny/issues>.

=head1 SEE ALSO

L<Types::Standard>,
L<Types::Common::Numeric>,
L<Types::Common::String>;
L<Type::Params>;
L<Type::Registry>.

=head1 AUTHOR

Toby Inkster E<lt>tobyink@cpan.orgE<gt>.

=head1 COPYRIGHT AND LICENCE

This software is copyright (c) 2022 by Toby Inkster.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=head1 DISCLAIMER OF WARRANTIES

THIS PACKAGE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.
