package Type::Tiny::Bitfield;

use 5.008001;
use strict;
use warnings;

BEGIN {
	$Type::Tiny::Bitfield::AUTHORITY = 'cpan:TOBYINK';
	$Type::Tiny::Bitfield::VERSION   = '2.006000';
}

$Type::Tiny::Bitfield::VERSION =~ tr/_//d;

sub _croak ($;@) { require Error::TypeTiny; goto \&Error::TypeTiny::croak }

use Exporter::Tiny 1.004001 ();
use Type::Tiny ();
use Types::Common::Numeric qw( +PositiveOrZeroInt );
use Eval::TypeTiny qw( eval_closure );

our @ISA = qw( Type::Tiny Exporter::Tiny );

__PACKAGE__->_install_overloads(
	q[+] => 'new_combined',
);

sub _is_power_of_two { not $_[0] & $_[0]-1 }

sub _exporter_fail {
	my ( $class, $type_name, $args, $globals ) = @_;
	my $caller = $globals->{into};
	my %values = %$args;
	/^[-]/ && delete( $values{$_} ) for keys %values;
	my $type = $class->new(
		name      => $type_name,
		values    => \%values,
		coercion  => 1,
	);
	$INC{'Type/Registry.pm'}
		? 'Type::Registry'->for_class( $caller )->add_type( $type, $type_name )
		: ( $Type::Registry::DELAYED{$caller}{$type_name} = $type )
		unless( ref($caller) or $caller eq '-lexical' or $globals->{'lexical'} );
	return map +( $_->{name} => $_->{code} ), @{ $type->exportables };
}

sub new {
	my $proto = shift;
	
	my %opts = ( @_ == 1 ) ? %{ $_[0] } : @_;
	_croak
		"Bitfield type constraints cannot have a parent constraint passed to the constructor"
		if exists $opts{parent};
	_croak
		"Bitfield type constraints cannot have a constraint coderef passed to the constructor"
		if exists $opts{constraint};
	_croak
		"Bitfield type constraints cannot have a inlining coderef passed to the constructor"
		if exists $opts{inlined};
	_croak "Need to supply hashref of values"
		unless exists $opts{values};
	
	$opts{parent} = PositiveOrZeroInt;
	
	for my $key ( keys %{ $opts{values} } ) {
		_croak "Not an all-caps name in a bitfield: $key"
			unless $key =~ /^[A-Z][A-Z0-9]*(_[A-Z0-9]+)*/
	}
	my $ALL = 0;
	my %already = ();
	for my $value ( values %{ $opts{values} } ) {
		_croak "Not a positive power of 2 in a bitfield: $value"
			unless is_PositiveOrZeroInt( $value ) && _is_power_of_two( $value );
		_croak "Duplicate value in a bitfield: $value"
			if $already{$value}++;
		$ALL |= ( 0 + $value );
	}
	$opts{ALL} = $ALL;
	
	$opts{constraint} = sub {
		not shift() & ~$ALL;
	};
	
	if ( defined $opts{coercion}
	and !ref $opts{coercion}
	and 1 eq $opts{coercion} ) {
		delete $opts{coercion};
		$opts{_build_coercion} = sub {
			require Types::Standard;
			my $c = shift;
			my $t = $c->type_constraint;
			$c->add_type_coercions(
				Types::Standard::Str(),
				$t->_stringy_coercion,
			);
		};
	} #/ if ( defined $opts{coercion...})
	
	return $proto->SUPER::new( %opts );
} #/ sub new

sub new_combined {
	my ( $self, $other, $swap ) = @_;
	
	Scalar::Util::blessed( $self )
		&& $self->isa( __PACKAGE__ )
		&& Scalar::Util::blessed( $other )
		&& $other->isa( __PACKAGE__ )
		or _croak( "Bad overloaded operation" );
	
	( $other, $self ) = ( $self, $other ) if $swap;
	
	for my $k ( keys %{ $self->values } ) {
		_croak "Conflicting value: $k"
			if exists $other->values->{$k};
	}
	
	my %all_values = ( %{ $self->values }, %{ $other->values } );
	return ref( $self )->new(
		display_name => sprintf( '%s+%s', "$self", "$other" ),
		values       => \%all_values,
		( $self->has_coercion || $other->has_coercion )
			? ( coercion => 1 )
			: (),
	);
}

sub values {
	$_[0]{values};
}

sub _lockdown {
	my ( $self, $callback ) = @_;
	$callback->( $self->{values} );
}

sub exportables {
	my ( $self, $base_name ) = @_;
	if ( not $self->is_anon ) {
		$base_name ||= $self->name;
	}
	
	my $exportables = $self->SUPER::exportables( $base_name );
	
	require Eval::TypeTiny;
	require B;
	
	for my $key ( keys %{ $self->values } ) {
		my $value = $self->values->{$key};
		push @$exportables, {
			name => uc( sprintf '%s_%s', $base_name, $key ),
			tags => [ 'constants' ],
			code => Eval::TypeTiny::eval_closure(
				source      => sprintf( 'sub () { %d }', $value ),
				environment => {},
			),
		};
	}
	
	my $weak = $self;
	require Scalar::Util;
	Scalar::Util::weaken( $weak );
	push @$exportables, {
		name => sprintf( '%s_to_Str', $base_name ),
		tags => [ 'from' ],
		code => sub { $weak->to_string( @_ ) },
	};
	
	return $exportables;
}

sub constant_names {
	my $self = shift;
	return map { $_->{name} }
		grep { my $tags = $_->{tags}; grep $_ eq 'constants', @$tags; }
		@{ $self->exportables || [] };
}

sub can_be_inlined {
	!!1;
}

sub inline_check {
	my ( $self, $var ) = @_;
	
	return sprintf(
		'( %s and not %s & ~%d )',
		PositiveOrZeroInt->inline_check( $var ),
		$var,
		$self->{ALL},
	);
}

sub _stringy_coercion {
	my ( $self, $varname ) = @_;
	$varname ||= '$_';
	my %vals = %{ $self->values };
	my $pfx  = uc( "$self" );
	my $pfxl = length $pfx;
	my $hash = sprintf(
		'( %s )',
		join(
			q{, },
			map sprintf( '%s => %d', B::perlstring($_), $vals{$_} ),
			sort keys %vals,
		),
	);
	return qq{do { my \$bits = 0; my \%lookup = $hash; for my \$tok ( grep /\\w/, split /[\\s|+]+/, uc( $varname ) ) { if ( substr( \$tok, 0, $pfxl) eq "$pfx" ) { \$tok = substr( \$tok, $pfxl ); \$tok =~ s/^_//; } if ( exists \$lookup{\$tok} ) { \$bits |= \$lookup{\$tok}; next; } require Carp; Carp::carp("Unknown token: \$tok"); } \$bits; }};
}

sub from_string {
	my ( $self, $str ) = @_;
	$self->{from_string} ||= eval_closure(
		environment => {},
		source      => sprintf( 'sub { my $STR = shift; %s }', $self->_stringy_coercion( '$STR' ) ),
	);
	$self->{from_string}->( $str );
}

sub to_string {
	my ( $self, $int ) = @_;
	$self->check( $int ) or return undef;
	my %values = %{ $self->values };
	$self->{all_names} ||= [ sort { $values{$a} <=> $values{$b} } keys %values ];
	$int += 0;
	my @names;
	for my $n ( @{ $self->{all_names} } ) {
		push @names, $n if $int & $values{$n};
	}
	return join q{|}, @names;
}

sub AUTOLOAD {
	our $AUTOLOAD;
	my $self = shift;
	my ( $m ) = ( $AUTOLOAD =~ /::(\w+)$/ );
	return if $m eq 'DESTROY';
	if ( ref $self and exists $self->{values}{$m} ) {
		return 0 + $self->{values}{$m};
	}
	local $Type::Tiny::AUTOLOAD = $AUTOLOAD;
	return $self->SUPER::AUTOLOAD( @_ );
}

sub can {
	my ( $self, $m ) = ( shift, @_ );
	if ( ref $self and exists $self->{values}{$m} ) {
		return sub () { 0 + $self->{values}{$m} };
	}
	return $self->SUPER::can( @_ );
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Type::Tiny::Bitfield - bitfield/bitflag type constraints

=head1 SYNOPSIS

Using Type::Tiny::Bitfield's export feature:

  package LightSource {
    use Moo;
    
    use Type::Tiny::Bitfield LedSet => {
      RED   => 1,
      GREEN => 2,
      BLUE  => 4,
    };
    
    has leds => ( is => 'ro', isa => LedSet, default => 0, coerce => 1 );
    
    sub new_red {
      my $class = shift;
      return $class->new( leds => LEDSET_RED );
    }
    
    sub new_green {
      my $class = shift;
      return $class->new( leds => LEDSET_GREEN );
    }
    
    sub new_yellow {
      my $class = shift;
      return $class->new( leds => LEDSET_RED | LEDSET_GREEN );
    }
  }

Using Type::Tiny::Bitfield's object-oriented interface:

  package LightSource {
    use Moo;
    use Type::Tiny::Bitfield;
    
    my $LedSet = Type::Tiny::Bitfield->new(
      name   => 'LedSet',
      values => {
        RED   => 1,
        GREEN => 2,
        BLUE  => 4,
      },
      coercion => 1,
    );
    
    has leds => ( is => 'ro', isa => $LedSet, default => 0, coerce => 1 );
    
    sub new_red {
      my $class = shift;
      return $class->new( leds => $LedSet->RED );
    }
    
    sub new_green {
      my $class = shift;
      return $class->new( leds => $LedSet->GREEN );
    }
    
    sub new_yellow {
      my $class = shift;
      return $class->new( leds => $LedSet->coerce('red|green') );
    }
  }

=head1 STATUS

This module is covered by the
L<Type-Tiny stability policy|Type::Tiny::Manual::Policies/"STABILITY">.

=head1 DESCRIPTION

Bitfield type constraints.

This package inherits from L<Type::Tiny>; see that for most documentation.
Major differences are listed below:

=head2 Attributes

=over

=item C<values>

Hashref of bits allowed in the bitfield. Keys must be UPPER_SNAKE_CASE strings.
Values must be positive integers which are powers of two. The same number
cannot be used multiple times.

=item C<constraint>

Unlike Type::Tiny, you I<cannot> pass a constraint coderef to the constructor.
Instead rely on the default.

=item C<inlined>

Unlike Type::Tiny, you I<cannot> pass an inlining coderef to the constructor.
Instead rely on the default.

=item C<parent>

Parent is always B<Types::Common::Numeric::PositiveOrZeroInt>, and cannot be
passed to the constructor.

=item C<coercion>

If C<< coercion => 1 >> is passed to the constructor, the type will have an
automatic coercion from B<Str>. Types built by the C<import> method will
always have C<< coercion => 1 >>.

In the SYNOPSIS example, the coercion from B<Str> will accept strings like:

  "RED"
  "red"
  "Red Green"
  "Red+Blue"
  "blue | GREEN"
  "LEDSET_RED + LeDsEt_green"

=back

=head2 Methods

This class uses C<AUTOLOAD> to allow the names of each bit in the bitfield
to be used as methods. These method names will always be UPPER_SNAKE_CASE.

For example, in the synopsis, C<< LedSet->GREEN >> would return 2.

Other methods it provides:

=over

=item C<< from_string( $str ) >>

Provides the standard coercion from a string, even if this type constraint
doesn't have a coercion.

=item C<< to_string( $int ) >>

Does the reverse coercion.

=item C<< constant_names() >>

This is a convenience to allow for:

  use base 'Exporter::Tiny';
  push our @EXPORT_OK, LineStyle->constant_names;

=back

=head2 Exports

Type::Tiny::Bitfield can be used as an exporter.

  use Type::Tiny::Bitfield LedSet => {
    RED    => 1,
    GREEN  => 2,
    BLUE   => 4,
  };

This will export the following functions into your namespace:

=over

=item C<< LedSet >>

=item C<< is_LedSet( $value ) >>

=item C<< assert_LedSet( $value ) >>

=item C<< to_LedSet( $string ) >>

=item C<< LedSet_to_Str( $value ) >>

=item C<< LEDSET_RED >>

=item C<< LEDSET_GREEN >>

=item C<< LEDSET_BLUE >>

=back

Multiple bitfield types can be exported at once:

  use Type::Tiny::Enum (
    LedSet     => { RED => 1, GREEN => 2, BLUE => 4 },
    LedPattern => { FLASHING => 1 },
  );

=head2 Overloading

It is possible to combine two Bitfield types using the C<< + >> operator.

  use Type::Tiny::Enum (
    LedSet     => { RED => 1, GREEN => 2, BLUE => 4 },
    LedPattern => { FLASHING => 8 },
  );
  
  has leds => (
    is      => 'ro',
    isa     => LedSet + LedPattern,
    default => 0,
    coerce  => 1
  );

This will allow values like "11" (LEDSET_RED|LEDSET_GREEN|LEDPATTERN_FLASHING).

An exception will be thrown if any of the names in the two types being combined
conflict.

=head1 BUGS

Please report any bugs to
L<https://github.com/tobyink/p5-type-tiny/issues>.

=head1 SEE ALSO

L<Type::Tiny::Manual>.

L<Type::Tiny>.

=head1 AUTHOR

Toby Inkster E<lt>tobyink@cpan.orgE<gt>.

=head1 COPYRIGHT AND LICENCE

This software is copyright (c) 2023-2024 by Toby Inkster.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=head1 DISCLAIMER OF WARRANTIES

THIS PACKAGE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.
