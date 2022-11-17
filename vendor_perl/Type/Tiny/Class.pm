package Type::Tiny::Class;

use 5.008001;
use strict;
use warnings;

BEGIN {
	$Type::Tiny::Class::AUTHORITY = 'cpan:TOBYINK';
	$Type::Tiny::Class::VERSION   = '2.000001';
}

$Type::Tiny::Class::VERSION =~ tr/_//d;

use Scalar::Util qw< blessed >;

sub _croak ($;@) { require Error::TypeTiny; goto \&Error::TypeTiny::croak }

use Exporter::Tiny 1.004001 ();
use Type::Tiny::ConstrainedObject ();
our @ISA = qw( Type::Tiny::ConstrainedObject Exporter::Tiny );

sub _short_name { 'Class' }

sub _exporter_fail {
	my ( $class, $name, $opts, $globals ) = @_;
	my $caller = $globals->{into};
	
	$opts->{name}  = $name unless exists $opts->{name}; $opts->{name} =~ s/:://g;
	$opts->{class} = $name unless exists $opts->{class};
	my $type = $class->new($opts);
	
	$INC{'Type/Registry.pm'}
		? 'Type::Registry'->for_class( $caller )->add_type( $type )
		: ( $Type::Registry::DELAYED{$caller}{$type->name} = $type )
		unless( ref($caller) or $caller eq '-lexical' or $globals->{'lexical'} );
	return map +( $_->{name} => $_->{code} ), @{ $type->exportables };
}

sub new {
	my $proto = shift;
	return $proto->class->new( @_ ) if blessed $proto;    # DWIM
	
	my %opts = ( @_ == 1 ) ? %{ $_[0] } : @_;
	_croak "Need to supply class name" unless exists $opts{class};
	
	if ( Type::Tiny::_USE_XS ) {
		my $xsub =
			Type::Tiny::XS::get_coderef_for( "InstanceOf[" . $opts{class} . "]" );
		$opts{compiled_type_constraint} = $xsub if $xsub;
	}
	elsif ( Type::Tiny::_USE_MOUSE ) {
		require Mouse::Util::TypeConstraints;
		my $maker = "Mouse::Util::TypeConstraints"->can( "generate_isa_predicate_for" );
		$opts{compiled_type_constraint} = $maker->( $opts{class} ) if $maker;
	}
	
	return $proto->SUPER::new( %opts );
} #/ sub new

sub class   { $_[0]{class} }
sub inlined { $_[0]{inlined} ||= $_[0]->_build_inlined }

sub has_inlined { !!1 }

sub _is_null_constraint { 0 }

sub _build_constraint {
	my $self  = shift;
	my $class = $self->class;
	return sub { blessed( $_ ) and $_->isa( $class ) };
}

sub _build_inlined {
	my $self  = shift;
	my $class = $self->class;
	
	my $xsub;
	$xsub = Type::Tiny::XS::get_subname_for( "InstanceOf[$class]" )
		if Type::Tiny::_USE_XS;
		
	sub {
		my $var = $_[1];
		return
			qq{do { use Scalar::Util (); Scalar::Util::blessed($var) and $var->isa(q[$class]) }}
			if $Type::Tiny::AvoidCallbacks;
		return "$xsub\($var\)"
			if $xsub;
		qq{Scalar::Util::blessed($var) and $var->isa(q[$class])};
	};
} #/ sub _build_inlined

sub _build_default_message {
	no warnings 'uninitialized';
	my $self = shift;
	my $c    = $self->class;
	return sub {
		sprintf '%s did not pass type constraint (not isa %s)',
			Type::Tiny::_dd( $_[0] ), $c;
		}
		if $self->is_anon;
	my $name = "$self";
	return sub {
		sprintf '%s did not pass type constraint "%s" (not isa %s)',
			Type::Tiny::_dd( $_[0] ), $name, $c;
	};
} #/ sub _build_default_message

sub _instantiate_moose_type {
	my $self = shift;
	my %opts = @_;
	delete $opts{parent};
	delete $opts{constraint};
	delete $opts{inlined};
	require Moose::Meta::TypeConstraint::Class;
	return "Moose::Meta::TypeConstraint::Class"
		->new( %opts, class => $self->class );
} #/ sub _instantiate_moose_type

sub plus_constructors {
	my $self = shift;
	
	unless ( @_ ) {
		require Types::Standard;
		push @_, Types::Standard::HashRef(), "new";
	}
	
	require B;
	require Types::TypeTiny;
	
	my $class = B::perlstring( $self->class );
	
	my @r;
	while ( @_ ) {
		my $source = shift;
		Types::TypeTiny::is_TypeTiny( $source )
			or _croak "Expected type constraint; got $source";
			
		my $constructor = shift;
		Types::TypeTiny::is_StringLike( $constructor )
			or _croak "Expected string; got $constructor";
			
		push @r, $source, sprintf( '%s->%s($_)', $class, $constructor );
	} #/ while ( @_ )
	
	return $self->plus_coercions( \@r );
} #/ sub plus_constructors

sub parent {
	$_[0]{parent} ||= $_[0]->_build_parent;
}

sub _build_parent {
	my $self  = shift;
	my $class = $self->class;
	
	# Some classes (I'm looking at you, Math::BigFloat) include a class in
	# their @ISA to inherit methods, but then override isa() to return false,
	# so that they don't appear to be a subclass.
	#
	# In these cases, we don't want to list the parent class as a parent
	# type constraint.
	#
	my @isa = grep $class->isa( $_ ),
		do { no strict "refs"; no warnings; @{"$class\::ISA"} };
		
	if ( @isa == 0 ) {
		require Types::Standard;
		return Types::Standard::Object();
	}
	
	if ( @isa == 1 ) {
		return ref( $self )->new( class => $isa[0] );
	}
	
	require Type::Tiny::Intersection;
	"Type::Tiny::Intersection"->new(
		type_constraints => [ map ref( $self )->new( class => $_ ), @isa ],
	);
} #/ sub _build_parent

*__get_linear_isa_dfs =
	eval { require mro }
	? \&mro::get_linear_isa
	: sub {
	no strict 'refs';
	
	my $classname = shift;
	my @lin       = ( $classname );
	my %stored;
	
	foreach my $parent ( @{"$classname\::ISA"} ) {
		my $plin = __get_linear_isa_dfs( $parent );
		foreach ( @$plin ) {
			next if exists $stored{$_};
			push( @lin, $_ );
			$stored{$_} = 1;
		}
	}
	
	return \@lin;
	};
	
sub validate_explain {
	my $self = shift;
	my ( $value, $varname ) = @_;
	$varname = '$_' unless defined $varname;
	
	return undef if $self->check( $value );
	return ["Not a blessed reference"] unless blessed( $value );
	
	my @isa = @{ __get_linear_isa_dfs( ref $value ) };
	
	my $display_var = $varname eq q{$_} ? '' : sprintf( ' (in %s)', $varname );
	
	require Type::Utils;
	return [
		sprintf( '"%s" requires that the reference isa %s', $self, $self->class ),
		sprintf(
			'The reference%s isa %s', $display_var, Type::Utils::english_list( @isa )
		),
	];
} #/ sub validate_explain

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Type::Tiny::Class - type constraints based on the "isa" method

=head1 STATUS

This module is covered by the
L<Type-Tiny stability policy|Type::Tiny::Manual::Policies/"STABILITY">.

=head1 DESCRIPTION

Type constraints of the general form C<< { $_->isa("Some::Class") } >>.

This package inherits from L<Type::Tiny>; see that for most documentation.
Major differences are listed below:

=head2 Constructor

=over

=item C<new>

When the constructor is called on an I<instance> of Type::Tiny::Class, it
passes the call through to the constructor of the class for the constraint.
So for example:

   my $type = Type::Tiny::Class->new(class => "Foo::Bar");
   my $obj  = $type->new(hello => "World");
   say ref($obj);   # prints "Foo::Bar"

This little bit of DWIM was borrowed from L<MooseX::Types::TypeDecorator>,
but Type::Tiny doesn't take the idea quite as far.

=back

=head2 Attributes

=over

=item C<class>

The class for the constraint.

=item C<constraint>

Unlike Type::Tiny, you I<cannot> pass a constraint coderef to the constructor.
Instead rely on the default.

=item C<inlined>

Unlike Type::Tiny, you I<cannot> pass an inlining coderef to the constructor.
Instead rely on the default.

=item C<parent>

Parent is automatically calculated, and cannot be passed to the constructor.

=back

=head2 Methods

=over

=item C<< plus_constructors($source, $method_name) >>

Much like C<plus_coercions> but adds coercions that go via a constructor.
(In fact, this is implemented as a wrapper for C<plus_coercions>.)

Example:

   package MyApp::Minion;
   
   use Moose; extends "MyApp::Person";
   
   use Types::Standard qw( HashRef Str );
   use Type::Utils qw( class_type );
   
   my $Person = class_type({ class => "MyApp::Person" });
   
   has boss => (
      is     => "ro",
      isa    => $Person->plus_constructors(
         HashRef,     "new",
         Str,         "_new_from_name",
      ),
      coerce => 1,
   );
   
   package main;
   
   MyApp::Minion->new(
      ...,
      boss => "Bob",  ## via MyApp::Person->_new_from_name
   );
   
   MyApp::Minion->new(
      ...,
      boss => { name => "Bob" },  ## via MyApp::Person->new
   );

Because coercing C<HashRef> via constructor is a common desire, if
you call C<plus_constructors> with no arguments at all, this is the
default.

   $classtype->plus_constructors(HashRef, "new")
   $classtype->plus_constructors()  ## identical to above

This is handy for Moose/Mouse/Moo-based classes.

=item C<< stringifies_to($constraint) >>

See L<Type::Tiny::ConstrainedObject>.

=item C<< numifies_to($constraint) >>

See L<Type::Tiny::ConstrainedObject>.

=item C<< with_attribute_values($attr1 => $constraint1, ...) >>

See L<Type::Tiny::ConstrainedObject>.

=back

=head2 Exports

Type::Tiny::Class can be used as an exporter.

  use Type::Tiny::Class 'HTTP::Tiny';

This will export the following functions into your namespace:

=over

=item C<< HTTPTiny >>

=item C<< is_HTTPTiny( $value ) >>

=item C<< assert_HTTPTiny( $value ) >>

=item C<< to_HTTPTiny( $value ) >>

=back

You will also be able to use C<< HTTPTiny->new(...) >> as a shortcut for
C<< HTTP::Tiny->new(...) >>.

Multiple types can be exported at once:

  use Type::Tiny::Class qw( HTTP::Tiny LWP::UserAgent );

=head1 BUGS

Please report any bugs to
L<https://github.com/tobyink/p5-type-tiny/issues>.

=head1 SEE ALSO

L<Type::Tiny::Manual>.

L<Type::Tiny>.

L<Moose::Meta::TypeConstraint::Class>.

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
