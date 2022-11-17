package Type::Tiny::Role;

use 5.008001;
use strict;
use warnings;

BEGIN {
	$Type::Tiny::Role::AUTHORITY = 'cpan:TOBYINK';
	$Type::Tiny::Role::VERSION   = '2.000001';
}

$Type::Tiny::Role::VERSION =~ tr/_//d;

use Scalar::Util qw< blessed weaken >;

sub _croak ($;@) { require Error::TypeTiny; goto \&Error::TypeTiny::croak }

use Exporter::Tiny 1.004001 ();
use Type::Tiny::ConstrainedObject ();
our @ISA = qw( Type::Tiny::ConstrainedObject Exporter::Tiny );

sub _short_name { 'Role' }

sub _exporter_fail {
	my ( $class, $name, $opts, $globals ) = @_;
	my $caller = $globals->{into};
	
	$opts->{name} = $name unless exists $opts->{name}; $opts->{name} =~ s/:://g;
	$opts->{role} = $name unless exists $opts->{role};
	my $type = $class->new($opts);
	
	$INC{'Type/Registry.pm'}
		? 'Type::Registry'->for_class( $caller )->add_type( $type )
		: ( $Type::Registry::DELAYED{$caller}{$type->name} = $type )
		unless( ref($caller) or $caller eq '-lexical' or $globals->{'lexical'} );
	return map +( $_->{name} => $_->{code} ), @{ $type->exportables };
}

my %cache;

sub new {
	my $proto = shift;
	my %opts  = ( @_ == 1 ) ? %{ $_[0] } : @_;
	_croak "Need to supply role name" unless exists $opts{role};
	return $proto->SUPER::new( %opts );
}

sub role    { $_[0]{role} }
sub inlined { $_[0]{inlined} ||= $_[0]->_build_inlined }

sub has_inlined { !!1 }

sub _is_null_constraint { 0 }

sub _build_constraint {
	my $self = shift;
	my $role = $self->role;
	return sub {
		blessed( $_ ) and do {
			my $method = $_->can( 'DOES' ) || $_->can( 'isa' );
			$_->$method( $role );
		}
	};
} #/ sub _build_constraint

sub _build_inlined {
	my $self = shift;
	my $role = $self->role;
	sub {
		my $var = $_[1];
		my $code =
			qq{Scalar::Util::blessed($var) and do { my \$method = $var->can('DOES')||$var->can('isa'); $var->\$method(q[$role]) }};
		return qq{do { use Scalar::Util (); $code }} if $Type::Tiny::AvoidCallbacks;
		$code;
	};
} #/ sub _build_inlined

sub _build_default_message {
	my $self = shift;
	my $c    = $self->role;
	return sub {
		sprintf '%s did not pass type constraint (not DOES %s)',
			Type::Tiny::_dd( $_[0] ), $c;
		}
		if $self->is_anon;
	my $name = "$self";
	return sub {
		sprintf '%s did not pass type constraint "%s" (not DOES %s)',
			Type::Tiny::_dd( $_[0] ), $name, $c;
	};
} #/ sub _build_default_message

sub validate_explain {
	my $self = shift;
	my ( $value, $varname ) = @_;
	$varname = '$_' unless defined $varname;
	
	return undef if $self->check( $value );
	return ["Not a blessed reference"] unless blessed( $value );
	return ["Reference provides no DOES method to check roles"]
		unless $value->can( 'DOES' );
		
	my $display_var = $varname eq q{$_} ? '' : sprintf( ' (in %s)', $varname );
	
	return [
		sprintf( '"%s" requires that the reference does %s', $self, $self->role ),
		sprintf( "The reference%s doesn't %s", $display_var,        $self->role ),
	];
} #/ sub validate_explain

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Type::Tiny::Role - type constraints based on the "DOES" method

=head1 STATUS

This module is covered by the
L<Type-Tiny stability policy|Type::Tiny::Manual::Policies/"STABILITY">.

=head1 DESCRIPTION

Type constraints of the general form C<< { $_->DOES("Some::Role") } >>.

This package inherits from L<Type::Tiny>; see that for most documentation.
Major differences are listed below:

=head2 Attributes

=over

=item C<role>

The role for the constraint.

Note that this package doesn't subscribe to any particular flavour of roles
(L<Moose::Role>, L<Mouse::Role>, L<Moo::Role>, L<Role::Tiny>, etc). It simply
trusts the object's C<DOES> method (see L<UNIVERSAL>).

=item C<constraint>

Unlike Type::Tiny, you I<cannot> pass a constraint coderef to the constructor.
Instead rely on the default.

=item C<inlined>

Unlike Type::Tiny, you I<cannot> pass an inlining coderef to the constructor.
Instead rely on the default.

=item C<parent>

Parent is always B<Types::Standard::Object>, and cannot be passed to the
constructor.

=back

=head2 Methods

=over

=item C<< stringifies_to($constraint) >>

See L<Type::Tiny::ConstrainedObject>.

=item C<< numifies_to($constraint) >>

See L<Type::Tiny::ConstrainedObject>.

=item C<< with_attribute_values($attr1 => $constraint1, ...) >>

See L<Type::Tiny::ConstrainedObject>.

=back

=head2 Exports

Type::Tiny::Role can be used as an exporter.

  use Type::Tiny::Role 'MyApp::Printable';

This will export the following functions into your namespace:

=over

=item C<< MyAppPrintable >>

=item C<< is_MyAppPrintable( $value ) >>

=item C<< assert_MyAppPrintable( $value ) >>

=item C<< to_MyAppPrintable( $value ) >>

=back

Multiple types can be exported at once:

  use Type::Tiny::Role qw( MyApp::Printable MyApp::Sendable );

=head1 BUGS

Please report any bugs to
L<https://github.com/tobyink/p5-type-tiny/issues>.

=head1 SEE ALSO

L<Type::Tiny::Manual>.

L<Type::Tiny>.

L<Moose::Meta::TypeConstraint::Role>.

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
