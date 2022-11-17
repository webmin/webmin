package Type::Library;

use 5.008001;
use strict;
use warnings;

BEGIN {
	$Type::Library::AUTHORITY = 'cpan:TOBYINK';
	$Type::Library::VERSION   = '2.000001';
}

$Type::Library::VERSION =~ tr/_//d;

use Eval::TypeTiny qw< eval_closure set_subname type_to_coderef NICE_PROTOTYPES >;
use Scalar::Util qw< blessed refaddr >;
use Type::Tiny      ();
use Types::TypeTiny ();

require Exporter::Tiny;
our @ISA = 'Exporter::Tiny';

sub _croak ($;@) { require Error::TypeTiny; goto \&Error::TypeTiny::croak }

####
#### Hooks for Exporter::Tiny
####

# Handling for -base, -extends, and -utils tags.
#
sub _exporter_validate_opts {
	my ( $class, $opts ) = ( shift, @_ );
	
	$class->setup_type_library( @{$opts}{qw/ into utils extends /} )
		if $_[0]{base} || $_[0]{extends};
	
	return $class->SUPER::_exporter_validate_opts( @_ );
}

# In Exporter::Tiny, this method takes a sub name, a 'value' (i.e.
# potentially an options hashref for the export), and some global
# options, and returns a list of name+coderef pairs to actually
# export. We override it to provide some useful features.
#
sub _exporter_expand_sub {
	my $class = shift;
	my ( $name, $value, $globals ) = @_;
	
	# Handle exporting '+Type'.
	#
	# Note that this recurses, so if used in conjunction with the other
	# special cases handled by this method, will still work.
	#
	if ( $name =~ /^\+(.+)/ and $class->has_type( "$1" ) ) {
		my $type     = $class->get_type( "$1" );
		my $exported = $type->exportables;
		return map $class->_exporter_expand_sub(
			$_->{name},
			+{ %{ $value || {} } },
			$globals,
		), @$exported;
	}
	
	# Is the function being exported one which is associated with a
	# type constraint? If so, which one. If not, then forget the rest
	# and just use the superclass method.
	#
	if ( my $f = $class->meta->{'functions'}{$name}
	and  defined $class->meta->{'functions'}{$name}{'type'} ) {
		
		my $type      = $f->{type};
		my $tag       = $f->{tags}[0];
		my $typename  = $type->name;
		
		# If $value has `of` or `where` options, then this is a
		# custom type.
		#
		my $custom_type = 0;
		for my $param ( qw/ of where / ) {
			exists $value->{$param} or next;
			defined $value->{-as} or _croak( "Parameter '-as' not supplied" );
			$type = $type->$param( $value->{$param} );
			$name = $value->{-as};
			++$custom_type;
		}
		
		# If we're exporting a type itself, then export a custom
		# function if they customized the type or want a Moose/Mouse
		# type constraint.
		#
		if ( $tag eq 'types' ) {
			my $post_method = q();
			$post_method = '->mouse_type' if $globals->{mouse};
			$post_method = '->moose_type' if $globals->{moose};
			return ( $name => type_to_coderef( $type, post_method => $post_method ) )
				if $post_method || $custom_type;
		}
		
		# If they're exporting some other type of function, like
		# 'to', 'is', or 'assert', then find the correct exportable
		# by tag name, and return that.
		#
		# XXX: this will fail for tags like 'constants' where there
		# will be multiple exportables which match!
		#
		if ( $custom_type and $tag ne 'types' ) {
			my $exportable = $type->exportables_by_tag( $tag, $typename );
			return ( $value->{-as} || $exportable->{name}, $exportable->{code} );
		}
	}
	
	# In all other cases, the superclass method will work.
	#
	return $class->SUPER::_exporter_expand_sub( @_ );
}

# Mostly just rely on superclass to do the actual export, but add
# a couple of useful behaviours.
#
sub _exporter_install_sub {
	my $class = shift;
	my ( $name, $value, $globals, $sym ) = @_;
	
	my $into = $globals->{into};
	my $type = $class->meta->{'functions'}{$name}{'type'};
	my $tags = $class->meta->{'functions'}{$name}{'tags'};
	
	# Issue a warning if exporting a deprecated type constraint.
	# 
	Exporter::Tiny::_carp(
		"Exporting deprecated type %s to %s",
		$type->qualified_name,
		ref( $into ) ? "reference" : "package $into",
	) if ( defined $type and $type->deprecated and not $globals->{allow_deprecated} );
	
	# If exporting a type constraint into a real package, then
	# add it to the package's type registry.
	# 
	if ( !ref $into
	and  $into ne '-lexical'
	and  defined $type
	and  grep $_ eq 'types', @$tags ) {
		
		# If they're renaming it, figure out what name, and use that.
		# XXX: `-as` can be a coderef, and can be in $globals in that case.
		my ( $prefix ) = grep defined, $value->{-prefix}, $globals->{prefix}, q();
		my ( $suffix ) = grep defined, $value->{-suffix}, $globals->{suffix}, q();
		my $as         = $prefix . ( $value->{-as} || $name ) . $suffix;
		
		$INC{'Type/Registry.pm'}
			? 'Type::Registry'->for_class( $into )->add_type( $type, $as )
			: ( $Type::Registry::DELAYED{$into}{$as} = $type );
	}
	
	$class->SUPER::_exporter_install_sub( @_ );
} #/ sub _exporter_install_sub

sub _exporter_fail {
	my $class = shift;
	my ( $name, $value, $globals ) = @_;
	
	# Passing the `-declare` flag means that if a type isn't found, then
	# we export a placeholder function instead of failing.
	if ( $globals->{declare} ) {
		return (
			$name,
			type_to_coderef(
				undef,
				type_name    => $name,
				type_library => $globals->{into} || _croak( "Parameter 'into' not supplied" ),
			),
		);
	} #/ if ( $globals->{declare...})
	
	return $class->SUPER::_exporter_fail( @_ );
} #/ sub _exporter_fail

####
#### Type library functionality
####

sub setup_type_library {
	my ( $class, $type_library, $install_utils, $extends ) = @_;
	
	my @extends = ref( $extends ) ? @$extends : $extends ? $extends : ();
	unshift @extends, $class if $class ne __PACKAGE__;
	
	if ( not ref $type_library ) {
		no strict "refs";
		push @{"$type_library\::ISA"}, $class;
		( my $file = $type_library ) =~ s{::}{/}g;
		$INC{"$file.pm"} ||= __FILE__;
	}
	
	if ( $install_utils ) {
		require Type::Utils;
		'Type::Utils'->import( { into => $type_library }, '-default' );
	}
	
	if ( @extends and not ref $type_library ) {
		require Type::Utils;
		my $wrapper = eval "sub { package $type_library; &Type::Utils::extends; }";
		$wrapper->( @extends );
	}
}

sub meta {
	no strict "refs";
	no warnings "once";
	return $_[0] if blessed $_[0];
	${"$_[0]\::META"} ||= bless {}, $_[0];
}

sub add_type {
	my $meta  = shift->meta;
	my $class = blessed( $meta ) ;
	
	_croak( 'Type library is immutable' ) if $meta->{immutable};
	
	my $type =
		ref( $_[0] ) =~ /^Type::Tiny\b/ ? $_[0] :
		blessed( $_[0] )                ? Types::TypeTiny::to_TypeTiny( $_[0] ) :
		ref( $_[0] ) eq q(HASH)         ? 'Type::Tiny'->new( library => $class, %{ $_[0] } ) :
		"Type::Tiny"->new( library => $class, @_ );
	my $name = $type->{name};
	
	_croak( 'Type %s already exists in this library', $name )       if $meta->has_type( $name );
	_croak( 'Type %s conflicts with coercion of same name', $name ) if $meta->has_coercion( $name );
	_croak( 'Cannot add anonymous type to a library' )              if $type->is_anon;
	$meta->{types} ||= {};
	$meta->{types}{$name} = $type;
	
	no strict "refs";
	no warnings "redefine", "prototype";
	
	for my $exportable ( @{ $type->exportables } ) {
		my $name = $exportable->{name};
		my $code = $exportable->{code};
		my $tags = $exportable->{tags};
		*{"$class\::$name"} = set_subname( "$class\::$name", $code );
		push @{"$class\::EXPORT_OK"}, $name;
		push @{ ${"$class\::EXPORT_TAGS"}{$_} ||= [] }, $name for @$tags;
		$meta->{'functions'}{$name} = { type => $type, tags => $tags };
	}
	
	$INC{'Type/Registry.pm'}
		? 'Type::Registry'->for_class( $class )->add_type( $type, $name )
		: ( $Type::Registry::DELAYED{$class}{$name} = $type );
	
	return $type;
} #/ sub add_type

sub get_type {
	my $meta = shift->meta;
	$meta->{types}{ $_[0] };
}

sub has_type {
	my $meta = shift->meta;
	exists $meta->{types}{ $_[0] };
}

sub type_names {
	my $meta = shift->meta;
	keys %{ $meta->{types} };
}

sub add_coercion {
	my $meta  = shift->meta;
	my $class = blessed( $meta );
	
	_croak( 'Type library is immutable' ) if $meta->{immutable};
	
	require Type::Coercion;
	my $c     = blessed( $_[0] ) ? $_[0] : "Type::Coercion"->new( @_ );
	my $name  = $c->name;
	
	_croak( 'Coercion %s already exists in this library', $name )   if $meta->has_coercion( $name );
	_croak( 'Coercion %s conflicts with type of same name', $name ) if $meta->has_type( $name );
	_croak( 'Cannot add anonymous type to a library' )              if $c->is_anon;
	
	$meta->{coercions} ||= {};
	$meta->{coercions}{$name} = $c;
	
	no strict "refs";
	no warnings "redefine", "prototype";
	
	*{"$class\::$name"} = type_to_coderef( $c );
	push @{"$class\::EXPORT_OK"}, $name;
	push @{ ${"$class\::EXPORT_TAGS"}{'coercions'} ||= [] }, $name;
	$meta->{'functions'}{$name} = { coercion => $c, tags => [ 'coercions' ] };

	return $c;
} #/ sub add_coercion

sub get_coercion {
	my $meta = shift->meta;
	$meta->{coercions}{ $_[0] };
}

sub has_coercion {
	my $meta = shift->meta;
	exists $meta->{coercions}{ $_[0] };
}

sub coercion_names {
	my $meta = shift->meta;
	keys %{ $meta->{coercions} };
}

sub make_immutable {
	my $meta  = shift->meta;
	my $class = ref( $meta );
	
	no strict "refs";
	no warnings "redefine", "prototype";
	
	for my $type ( values %{ $meta->{types} } ) {
		$type->coercion->freeze;
		next unless $type->has_coercion && $type->coercion->frozen;
		for my $e ( $type->exportables_by_tag( 'to' ) ) {
			my $qualified_name = $class . '::' . $e->{name};
			*$qualified_name = set_subname( $qualified_name, $e->{code} );
		}
	}
	
	$meta->{immutable} = 1;
}

1;

__END__

=pod

=encoding utf-8

=for stopwords Moo(se)-compatible MooseX::Types-like

=head1 NAME

Type::Library - tiny, yet Moo(se)-compatible type libraries

=head1 SYNOPSIS

=for test_synopsis
BEGIN { die "SKIP: crams multiple modules into single example" };

   package Types::Mine {
      use Scalar::Util qw(looks_like_number);
      use Type::Library -base;
      use Type::Tiny;
      
      my $NUM = "Type::Tiny"->new(
         name       => "Number",
         constraint => sub { looks_like_number($_) },
         message    => sub { "$_ ain't a number" },
      );
      
      __PACKAGE__->meta->add_type($NUM);
      
      __PACKAGE__->meta->make_immutable;
   }
      
   package Ermintrude {
      use Moo;
      use Types::Mine qw(Number);
      has favourite_number => (is => "ro", isa => Number);
   }
   
   package Bullwinkle {
      use Moose;
      use Types::Mine qw(Number);
      has favourite_number => (is => "ro", isa => Number);
   }
   
   package Maisy {
      use Mouse;
      use Types::Mine qw(Number);
      has favourite_number => (is => "ro", isa => Number);
   }

=head1 STATUS

This module is covered by the
L<Type-Tiny stability policy|Type::Tiny::Manual::Policies/"STABILITY">.

=head1 DESCRIPTION

L<Type::Library> is a tiny class for creating MooseX::Types-like type
libraries which are compatible with Moo, Moose and Mouse.

If you're reading this because you want to create a type library, then
you're probably better off reading L<Type::Tiny::Manual::Libraries>.

=head2 Type library methods

A type library is a singleton class. Use the C<meta> method to get a blessed
object which other methods can get called on. For example:

   Types::Mine->meta->add_type($foo);

=begin trustme

=item meta

=end trustme

=over

=item C<< add_type($type) >> or C<< add_type(%opts) >>

Add a type to the library. If C<< %opts >> is given, then this method calls
C<< Type::Tiny->new(%opts) >> first, and adds the resultant type.

Adding a type named "Foo" to the library will automatically define four
functions in the library's namespace:

=over

=item C<< Foo >>

Returns the Type::Tiny object.

=item C<< is_Foo($value) >>

Returns true iff $value passes the type constraint.

=item C<< assert_Foo($value) >>

Returns $value iff $value passes the type constraint. Dies otherwise.

=item C<< to_Foo($value) >>

Coerces the value to the type.

=back

=item C<< get_type($name) >>

Gets the C<Type::Tiny> object corresponding to the name.

=item C<< has_type($name) >>

Boolean; returns true if the type exists in the library.

=item C<< type_names >>

List all types defined by the library.

=item C<< add_coercion($c) >> or C<< add_coercion(%opts) >>

Add a standalone coercion to the library. If C<< %opts >> is given, then
this method calls C<< Type::Coercion->new(%opts) >> first, and adds the
resultant coercion.

Adding a coercion named "FooFromBar" to the library will automatically
define a function in the library's namespace:

=over

=item C<< FooFromBar >>

Returns the Type::Coercion object.

=back

=item C<< get_coercion($name) >>

Gets the C<Type::Coercion> object corresponding to the name.

=item C<< has_coercion($name) >>

Boolean; returns true if the coercion exists in the library.

=item C<< coercion_names >>

List all standalone coercions defined by the library.

=item C<< import(@args) >>

Type::Library-based libraries are exporters.

=item C<< make_immutable >>

Prevents new type constraints and coercions from being added to the
library, and also calls C<< $type->coercion->freeze >> on every
type constraint in the library.

=back

=head2 Type library exported functions

Type libraries are exporters. For the purposes of the following examples,
assume that the C<Types::Mine> library defines types C<Number> and C<String>.

   # Exports nothing.
   # 
   use Types::Mine;
   
   # Exports a function "String" which is a constant returning
   # the String type constraint.
   #
   use Types::Mine qw( String );
   
   # Exports both String and Number as above.
   #
   use Types::Mine qw( String Number );
   
   # Same.
   #
   use Types::Mine qw( :types );
   
   # Exports "coerce_String" and "coerce_Number", as well as any other
   # coercions
   #
   use Types::Mine qw( :coercions );
   
   # Exports a sub "is_String" so that "is_String($foo)" is equivalent
   # to "String->check($foo)".
   #
   use Types::Mine qw( is_String );
   
   # Exports "is_String" and "is_Number".
   #
   use Types::Mine qw( :is );
   
   # Exports a sub "assert_String" so that "assert_String($foo)" is
   # equivalent to "String->assert_return($foo)".
   #
   use Types::Mine qw( assert_String );
   
   # Exports "assert_String" and "assert_Number".
   #
   use Types::Mine qw( :assert );
   
   # Exports a sub "to_String" so that "to_String($foo)" is equivalent
   # to "String->coerce($foo)".
   #
   use Types::Mine qw( to_String );
   
   # Exports "to_String" and "to_Number".
   #
   use Types::Mine qw( :to );
   
   # Exports "String", "is_String", "assert_String" and "coerce_String".
   #
   use Types::Mine qw( +String );
   
   # Exports everything.
   #
   use Types::Mine qw( :all );

Type libraries automatically inherit from L<Exporter::Tiny>; see the
documentation of that module for tips and tricks importing from libraries.

=head2 Type::Library's methods

The above sections describe the characteristics of libraries built with
Type::Library. The following methods are available on Type::Library itself.

=over

=item C<< setup_type_library( $package, $utils, \@extends ) >>

Sets up a package to be a type library. C<< $utils >> is a boolean
indicating whether to import L<Type::Utils> into the package.
C<< @extends >> is a list of existing type libraries the package
should extend.

=back

=head1 BUGS

Please report any bugs to
L<https://github.com/tobyink/p5-type-tiny/issues>.

=head1 SEE ALSO

L<Type::Tiny::Manual>.

L<Type::Tiny>, L<Type::Utils>, L<Types::Standard>, L<Type::Coercion>.

L<Moose::Util::TypeConstraints>,
L<Mouse::Util::TypeConstraints>.

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
