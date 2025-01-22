package Exporter::Shiny;

use 5.006001;
use strict;
use warnings;

use Exporter::Tiny ();

our $AUTHORITY = 'cpan:TOBYINK';
our $VERSION   = '1.006002';

sub import {
	my $me     = shift;
	my $caller = caller;
	
	(my $nominal_file = $caller) =~ s(::)(/)g;
	$INC{"$nominal_file\.pm"} ||= __FILE__;
	
	if (@_ == 2 and $_[0] eq -setup)
	{
		my (undef, $opts) = @_;
		@_ = @{ delete($opts->{exports}) || [] };
		
		if (%$opts) {
			Exporter::Tiny::_croak(
				'Unsupported Sub::Exporter-style options: %s',
				join(q[, ], sort keys %$opts),
			);
		}
	}
	
	ref($_) && Exporter::Tiny::_croak('Expected sub name, got ref %s', $_) for @_;
	
	no strict qw(refs);
	push @{"$caller\::ISA"}, 'Exporter::Tiny';
	push @{"$caller\::EXPORT_OK"}, @_;
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Exporter::Shiny - shortcut for Exporter::Tiny

=head1 SYNOPSIS

   use Exporter::Shiny qw( foo bar );

Is a shortcut for:

   use base "Exporter::Tiny";
   push our(@EXPORT_OK), qw( foo bar );

For compatibility with L<Sub::Exporter>, the following longer syntax is
also supported:

   use Exporter::Shiny -setup => {
      exports => [qw( foo bar )],
   };

=head1 DESCRIPTION

This is a very small wrapper to simplify using L<Exporter::Tiny>.

It does the following:

=over

=item * Marks your package as loaded in C<< %INC >>;

=item * Pushes any function names in the import list onto your C<< @EXPORT_OK >>; and

=item * Pushes C<< "Exporter::Tiny" >> onto your C<< @ISA >>.

=back

It doesn't set up C<< %EXPORT_TAGS >> or C<< @EXPORT >>, but there's
nothing stopping you doing that yourself.

=head1 BUGS

Please report any bugs to
L<https://github.com/tobyink/p5-exporter-tiny/issues>.

=head1 SEE ALSO

L<https://exportertiny.github.io/>.

This module is just a wrapper around L<Exporter::Tiny>, so take a look
at L<Exporter::Tiny::Manual::QuickStart> and
L<Exporter::Tiny::Manual::Exporting> for further information on what
features are available.

Other interesting exporters: L<Sub::Exporter>, L<Exporter>.

=head1 AUTHOR

Toby Inkster E<lt>tobyink@cpan.orgE<gt>.

=head1 COPYRIGHT AND LICENCE

This software is copyright (c) 2013-2014, 2017, 2022-2023 by Toby Inkster.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=head1 DISCLAIMER OF WARRANTIES

THIS PACKAGE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.

