package Error::TypeTiny::Assertion;

use 5.008001;
use strict;
use warnings;

BEGIN {
	$Error::TypeTiny::Assertion::AUTHORITY = 'cpan:TOBYINK';
	$Error::TypeTiny::Assertion::VERSION   = '2.000001';
}

$Error::TypeTiny::Assertion::VERSION =~ tr/_//d;

require Error::TypeTiny;
our @ISA = 'Error::TypeTiny';

sub type           { $_[0]{type} }
sub value          { $_[0]{value} }
sub varname        { $_[0]{varname} ||= '$_' }
sub attribute_step { $_[0]{attribute_step} }
sub attribute_name { $_[0]{attribute_name} }

sub has_type           { defined $_[0]{type} };           # sic
sub has_attribute_step { exists $_[0]{attribute_step} }
sub has_attribute_name { exists $_[0]{attribute_name} }

sub new {
	my $class = shift;
	my $self  = $class->SUPER::new( @_ );
	
	# Supported but undocumented parameter is `mgaca`.
	# This indicates whether Error::TypeTiny::Assertion
	# should attempt to figure out which attribute caused
	# the error from Method::Generate::Accessor's info.
	# Can be set to true/false or not set. If not set,
	# the current behaviour is true, but this may change
	# in the future. If set to false, will ignore the
	# $Method::Generate::Accessor::CurrentAttribute hashref.
	#
	
	if ( ref $Method::Generate::Accessor::CurrentAttribute
		and $self->{mgaca} || !exists $self->{mgaca} )
	{
		require B;
		my %d = %{$Method::Generate::Accessor::CurrentAttribute};
		$self->{attribute_name} = $d{name} if defined $d{name};
		$self->{attribute_step} = $d{step} if defined $d{step};
		
		if ( defined $d{init_arg} ) {
			$self->{varname} = sprintf( '$args->{%s}', B::perlstring( $d{init_arg} ) );
		}
		elsif ( defined $d{name} ) {
			$self->{varname} = sprintf( '$self->{%s}', B::perlstring( $d{name} ) );
		}
	} #/ if ( ref $Method::Generate::Accessor::CurrentAttribute...)
	
	return $self;
} #/ sub new

sub message {
	my $e = shift;
	$e->varname eq '$_'
		? $e->SUPER::message
		: sprintf( '%s (in %s)', $e->SUPER::message, $e->varname );
}

sub _build_message {
	my $e = shift;
	$e->has_type
		? sprintf(
		'%s did not pass type constraint "%s"',
		Type::Tiny::_dd( $e->value ), $e->type
		)
		: sprintf(
		'%s did not pass type constraint',
		Type::Tiny::_dd( $e->value )
		);
} #/ sub _build_message

*to_string = sub {
	my $e   = shift;
	my $msg = $e->message;
	
	my $c = $e->context;
	$msg .= sprintf( " at %s line %s", $c->{file} || 'file?', $c->{line} || 'NaN' )
		if $c;
		
	my $explain = $e->explain;
	return "$msg\n" unless @{ $explain || [] };
	
	$msg .= "\n";
	for my $line ( @$explain ) {
		$msg .= "    $line\n";
	}
	
	return $msg;
	}
	if $] >= 5.008;
	
sub explain {
	my $e = shift;
	return undef unless $e->has_type;
	$e->type->validate_explain( $e->value, $e->varname );
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Error::TypeTiny::Assertion - exception when a value fails a type constraint

=head1 STATUS

This module is covered by the
L<Type-Tiny stability policy|Type::Tiny::Manual::Policies/"STABILITY">.

=head1 DESCRIPTION

This exception is thrown when a value fails a type constraint assertion.

This package inherits from L<Error::TypeTiny>; see that for most
documentation. Major differences are listed below:

=head2 Attributes

=over

=item C<type>

The type constraint that was checked against. Weakened links are involved,
so this may end up being C<undef>.

=item C<value>

The value that was tested.

=item C<varname>

The name of the variable that was checked, if known. Defaults to C<< '$_' >>.

=item C<attribute_name>

If this exception was thrown as the result of an isa check or a failed
coercion for a Moo attribute, then this will tell you which attribute (if
your Moo is new enough).

(Hopefully one day this will support other OO frameworks.)

=item C<attribute_step>

If this exception was thrown as the result of an isa check or a failed
coercion for a Moo attribute, then this will contain either C<< "isa check" >>
or C<< "coercion" >> to indicate which went wrong (if your Moo is new enough).

(Hopefully one day this will support other OO frameworks.)

=back

=head2 Methods

=over

=item C<has_type>, C<has_attribute_name>, C<has_attribute_step>

Predicate methods.

=item C<message>

Overridden to add C<varname> to the message if defined.

=item C<explain>

Attempts to explain why the value did not pass the type constraint. Returns
an arrayref of strings providing step-by-step reasoning; or returns undef if
no explanation is possible.

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
