package Type::Tiny::Enum;

use 5.008001;
use strict;
use warnings;

BEGIN {
	$Type::Tiny::Enum::AUTHORITY = 'cpan:TOBYINK';
	$Type::Tiny::Enum::VERSION   = '2.000001';
}

$Type::Tiny::Enum::VERSION =~ tr/_//d;

sub _croak ($;@) { require Error::TypeTiny; goto \&Error::TypeTiny::croak }

use Exporter::Tiny 1.004001 ();
use Type::Tiny ();
our @ISA = qw( Type::Tiny Exporter::Tiny );

__PACKAGE__->_install_overloads(
	q[@{}] => sub { shift->values },
);

sub _exporter_fail {
	my ( $class, $type_name, $values, $globals ) = @_;
	my $caller = $globals->{into};
	my $type = $class->new(
		name      => $type_name,
		values    => [ @$values ],
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
		"Enum type constraints cannot have a parent constraint passed to the constructor"
		if exists $opts{parent};
	_croak
		"Enum type constraints cannot have a constraint coderef passed to the constructor"
		if exists $opts{constraint};
	_croak
		"Enum type constraints cannot have a inlining coderef passed to the constructor"
		if exists $opts{inlined};
	_croak "Need to supply list of values" unless exists $opts{values};
	
	no warnings 'uninitialized';
	$opts{values} = [
		map "$_",
		@{ ref $opts{values} eq 'ARRAY' ? $opts{values} : [ $opts{values} ] }
	];
	
	my %tmp;
	undef $tmp{$_} for @{ $opts{values} };
	$opts{unique_values} = [ sort keys %tmp ];
	
	my $xs_encoding = _xs_encoding( $opts{unique_values} );
	if ( defined $xs_encoding ) {
		my $xsub = Type::Tiny::XS::get_coderef_for( $xs_encoding );
		$opts{compiled_type_constraint} = $xsub if $xsub;
	}
	
	if ( defined $opts{coercion} and !ref $opts{coercion} and 1 eq $opts{coercion} )
	{
		delete $opts{coercion};
		$opts{_build_coercion} = sub {
			require Types::Standard;
			my $c = shift;
			my $t = $c->type_constraint;
			$c->add_type_coercions(
				Types::Standard::Str(),
				sub { $t->closest_match( @_ ? $_[0] : $_ ) }
			);
		};
	} #/ if ( defined $opts{coercion...})
	
	return $proto->SUPER::new( %opts );
} #/ sub new

sub new_union {
	my $proto  = shift;
	my %opts   = ( @_ == 1 ) ? %{ $_[0] } : @_;
	my @types  = @{ delete $opts{type_constraints} };
	my @values = map @$_, @types;
	$proto->new( %opts, values => \@values );
}

sub new_intersection {
	my $proto  = shift;
	my %opts   = ( @_ == 1 ) ? %{ $_[0] } : @_;
	my @types  = @{ delete $opts{type_constraints} };
	my %values; ++$values{$_} for map @$_, @types;
	my @values = sort grep $values{$_}==@types, keys %values;
	$proto->new( %opts, values => \@values );
}

sub values        { $_[0]{values} }
sub unique_values { $_[0]{unique_values} }
sub constraint    { $_[0]{constraint} ||= $_[0]->_build_constraint }

sub _is_null_constraint { 0 }

sub _build_display_name {
	my $self = shift;
	sprintf( "Enum[%s]", join q[,], @{ $self->unique_values } );
}

sub is_word_safe {
	my $self = shift;
	return not grep /\W/, @{ $self->unique_values };
}

sub exportables {
	my ( $self, $base_name ) = @_;
	if ( not $self->is_anon ) {
		$base_name ||= $self->name;
	}
	
	my $exportables = $self->SUPER::exportables( $base_name );
	
	if ( $self->is_word_safe ) {
		require Eval::TypeTiny;
		require B;
		for my $value ( @{ $self->unique_values } ) {
			push @$exportables, {
				name => uc( sprintf '%s_%s', $base_name, $value ),
				tags => [ 'constants' ],
				code => Eval::TypeTiny::eval_closure(
					source      => sprintf( 'sub () { %s }', B::perlstring($value) ),
					environment => {},
				),
			};
		}
	}
	
	return $exportables;
}

{
	my $new_xs;
	
	#
	# Note the fallback code for older Type::Tiny::XS cannot be tested as
	# part of the coverage tests because they use the latest Type::Tiny::XS.
	#
	
	sub _xs_encoding {
		my $unique_values = shift;
		
		return undef unless Type::Tiny::_USE_XS;
		
		return undef if @$unique_values > 50;    # RT 121957
		
		$new_xs = eval { Type::Tiny::XS->VERSION( "0.020" ); 1 } ? 1 : 0
			unless defined $new_xs;
		if ( $new_xs ) {
			require B;
			return sprintf(
				"Enum[%s]",
				join( ",", map B::perlstring( $_ ), @$unique_values )
			);
		}
		else {                                   # uncoverable statement
			return undef if grep /\W/, @$unique_values;                    # uncoverable statement
			return sprintf( "Enum[%s]", join( ",", @$unique_values ) );    # uncoverable statement
		}    # uncoverable statement
	} #/ sub _xs_encoding
}

{
	my %cached;
	
	sub _build_constraint {
		my $self = shift;
		
		my $regexp = $self->_regexp;
		return $cached{$regexp} if $cached{$regexp};
		my $coderef = ( $cached{$regexp} = sub { defined and m{\A(?:$regexp)\z} } );
		Scalar::Util::weaken( $cached{$regexp} );
		return $coderef;
	}
}

{
	my %cached;
	
	sub _build_compiled_check {
		my $self   = shift;
		my $regexp = $self->_regexp;
		return $cached{$regexp} if $cached{$regexp};
		my $coderef = ( $cached{$regexp} = $self->SUPER::_build_compiled_check( @_ ) );
		Scalar::Util::weaken( $cached{$regexp} );
		return $coderef;
	}
}

sub _regexp {
	my $self = shift;
	$self->{_regexp} ||= 'Type::Tiny::Enum::_Trie'->handle( $self->unique_values );
}

sub as_regexp {
	my $self = shift;
	
	my $flags = @_ ? $_[0] : '';
	unless ( defined $flags and $flags =~ /^[i]*$/ ) {
		_croak(
			"Unknown regexp flags: '$flags'; only 'i' currently accepted; stopped" );
	}
	
	my $regexp = $self->_regexp;
	$flags ? qr/\A(?:$regexp)\z/i : qr/\A(?:$regexp)\z/;
} #/ sub as_regexp

sub can_be_inlined {
	!!1;
}

sub inline_check {
	my $self = shift;
	
	my $xsub;
	if ( my $xs_encoding = _xs_encoding( $self->unique_values ) ) {
		$xsub = Type::Tiny::XS::get_subname_for( $xs_encoding );
		return "$xsub\($_[0]\)" if $xsub && !$Type::Tiny::AvoidCallbacks;
	}
	
	my $regexp = $self->_regexp;
	my $code =
		$_[0] eq '$_'
		? "(defined and !ref and m{\\A(?:$regexp)\\z})"
		: "(defined($_[0]) and !ref($_[0]) and $_[0] =~ m{\\A(?:$regexp)\\z})";
		
	return "do { $Type::Tiny::SafePackage $code }"
		if $Type::Tiny::AvoidCallbacks;
	return $code;
} #/ sub inline_check

sub _instantiate_moose_type {
	my $self = shift;
	my %opts = @_;
	delete $opts{parent};
	delete $opts{constraint};
	delete $opts{inlined};
	require Moose::Meta::TypeConstraint::Enum;
	return "Moose::Meta::TypeConstraint::Enum"
		->new( %opts, values => $self->values );
} #/ sub _instantiate_moose_type

sub has_parent {
	!!1;
}

sub parent {
	require Types::Standard;
	Types::Standard::Str();
}

sub validate_explain {
	my $self = shift;
	my ( $value, $varname ) = @_;
	$varname = '$_' unless defined $varname;
	
	return undef if $self->check( $value );
	
	require Type::Utils;
	!defined( $value )
		? [
		sprintf(
			'"%s" requires that the value is defined',
			$self,
		),
		]
		: @$self < 13 ? [
		sprintf(
			'"%s" requires that the value is equal to %s',
			$self,
			Type::Utils::english_list( \"or", map B::perlstring( $_ ), @$self ),
		),
		]
		: [
		sprintf(
			'"%s" requires that the value is one of an enumerated list of strings',
			$self,
		),
		];
} #/ sub validate_explain

sub has_sorter {
	!!1;
}

sub _enum_order_hash {
	my $self = shift;
	my %hash;
	my $i = 0;
	for my $value ( @{ $self->values } ) {
		next if exists $hash{$value};
		$hash{$value} = $i++;
	}
	return %hash;
} #/ sub _enum_order_hash

sub sorter {
	my $self = shift;
	my %hash = $self->_enum_order_hash;
	return [
		sub { $_[0] <=> $_[1] },
		sub { exists( $hash{ $_[0] } ) ? $hash{ $_[0] } : 2_100_000_000 },
	];
}

my $canon;

sub closest_match {
	require Types::Standard;
	
	my ( $self, $given ) = ( shift, @_ );
	
	return unless Types::Standard::is_Str $given;
	
	return $given if $self->check( $given );
	
	$canon ||= eval(
		$] lt '5.016'
		? q< sub { ( my $var = lc($_[0]) ) =~ s/(^\s+)|(\s+$)//g; $var } >
		: q< sub { CORE::fc($_[0]) =~ s/(^\s+)|(\s+$)//gr; } >
	);
	
	$self->{_lookups} ||= do {
		my %lookups;
		for ( @{ $self->values } ) {
			my $key = $canon->( $_ );
			next if exists $lookups{$key};
			$lookups{$key} = $_;
		}
		\%lookups;
	};
	
	my $cgiven = $canon->( $given );
	return $self->{_lookups}{$cgiven}
		if $self->{_lookups}{$cgiven};
		
	my $best;
	VALUE: for my $possible ( @{ $self->values } ) {
		my $stem = substr( $possible, 0, length $cgiven );
		if ( $cgiven eq $canon->( $stem ) ) {
			if ( defined( $best ) and length( $best ) >= length( $possible ) ) {
				next VALUE;
			}
			$best = $possible;
		}
	}
	
	return $best if defined $best;
	
	return $self->values->[$given]
		if Types::Standard::is_Int $given;
		
	return $given;
} #/ sub closest_match

push @Type::Tiny::CMP, sub {
	my $A = shift->find_constraining_type;
	my $B = shift->find_constraining_type;
	return Type::Tiny::CMP_UNKNOWN
		unless $A->isa( __PACKAGE__ ) && $B->isa( __PACKAGE__ );
		
	my %seen;
	for my $word ( @{ $A->unique_values } ) {
		$seen{$word} += 1;
	}
	for my $word ( @{ $B->unique_values } ) {
		$seen{$word} += 2;
	}
	
	my $values = join( '', CORE::values %seen );
	if ( $values =~ /^3*$/ ) {
		return Type::Tiny::CMP_EQUIVALENT;
	}
	elsif ( $values !~ /2/ ) {
		return Type::Tiny::CMP_SUPERTYPE;
	}
	elsif ( $values !~ /1/ ) {
		return Type::Tiny::CMP_SUBTYPE;
	}
	
	return Type::Tiny::CMP_UNKNOWN;
};

package    # stolen from Regexp::Trie
	Type::Tiny::Enum::_Trie;
sub new { bless {} => shift }

sub add {
	my $self = shift;
	my $str  = shift;
	my $ref  = $self;
	for my $char ( split //, $str ) {
		$ref->{$char} ||= {};
		$ref = $ref->{$char};
	}
	$ref->{''} = 1;    # { '' => 1 } as terminator
	$self;
} #/ sub add

sub _regexp {
	my $self = shift;
	return if $self->{''} and scalar keys %$self == 1;    # terminator
	my ( @alt, @cc );
	my $q = 0;
	for my $char ( sort keys %$self ) {
		my $qchar = quotemeta $char;
		if ( ref $self->{$char} ) {
			if ( defined( my $recurse = _regexp( $self->{$char} ) ) ) {
				push @alt, $qchar . $recurse;
			}
			else {
				push @cc, $qchar;
			}
		}
		else {
			$q = 1;
		}
	} #/ for my $char ( sort keys...)
	my $cconly = !@alt;
	@cc and push @alt, @cc == 1 ? $cc[0] : '[' . join( '', @cc ) . ']';
	my $result = @alt == 1 ? $alt[0] : '(?:' . join( '|', @alt ) . ')';
	$q and $result = $cconly ? "$result?" : "(?:$result)?";
	return $result;
} #/ sub _regexp

sub handle {
	my $class = shift;
	my ( $vals ) = @_;
	return '(?!)' unless @$vals;
	my $self = $class->new;
	$self->add( $_ ) for @$vals;
	$self->_regexp;
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Type::Tiny::Enum - string enum type constraints

=head1 STATUS

This module is covered by the
L<Type-Tiny stability policy|Type::Tiny::Manual::Policies/"STABILITY">.

=head1 DESCRIPTION

Enum type constraints.

This package inherits from L<Type::Tiny>; see that for most documentation.
Major differences are listed below:

=head2 Constructors

The C<new> constructor from L<Type::Tiny> still works, of course. But there
is also:

=over

=item C<< new_union( type_constraints => \@enums, %opts ) >>

Creates a new enum type constraint which is the union of existing enum
type constraints.

=item C<< new_intersection( type_constraints => \@enums, %opts ) >>

Creates a new enum type constraint which is the intersection of existing enum
type constraints.

=back

=head2 Attributes

=over

=item C<values>

Arrayref of allowable value strings. Non-string values (e.g. objects with
overloading) will be stringified in the constructor.

=item C<constraint>

Unlike Type::Tiny, you I<cannot> pass a constraint coderef to the constructor.
Instead rely on the default.

=item C<inlined>

Unlike Type::Tiny, you I<cannot> pass an inlining coderef to the constructor.
Instead rely on the default.

=item C<parent>

Parent is always B<Types::Standard::Str>, and cannot be passed to the
constructor.

=item C<unique_values>

The list of C<values> but sorted and with duplicates removed. This cannot
be passed to the constructor.

=item C<coercion>

If C<< coercion => 1 >> is passed to the constructor, the type will have a
coercion using the C<closest_match> method.

=back

=head2 Methods

=over

=item C<as_regexp>

Returns the enum as a regexp which strings can be checked against. If you're
checking I<< a lot >> of strings, then using this regexp might be faster than
checking each string against 

  my $enum  = Type::Tiny::Enum->new(...);
  my $check = $enum->compiled_check;
  my $re    = $enum->as_regexp;
  
  # fast
  my @valid_tokens = grep $enum->check($_), @all_tokens;
  
  # faster
  my @valid_tokens = grep $check->($_), @all_tokens;
  
  # fastest
  my @valid_tokens = grep /$re/, @all_tokens;

You can get a case-insensitive regexp using C<< $enum->as_regexp('i') >>.

=item C<closest_match>

Returns the closest match in the enum for a string.

  my $enum = Type::Tiny::Enum->new(
    values => [ qw( foo bar baz quux ) ],
  );
  
  say $enum->closest_match("FO");   # ==> foo

It will try to find an exact match first, fall back to a case-insensitive
match, if it still can't find one, will try to find a head substring match,
and finally, if given an integer, will use that as an index.

  my $enum = Type::Tiny::Enum->new(
    values => [ qw( foo bar baz quux ) ],
  );
  
  say $enum->closest_match(  0 );  # ==> foo
  say $enum->closest_match(  1 );  # ==> bar
  say $enum->closest_match(  2 );  # ==> baz
  say $enum->closest_match( -1 );  # ==> quux

=item C<< is_word_safe >>

Returns true if none of the values in the enumeration contain a non-word
character. Word characters include letters, numbers, and underscores, but
not most punctuation or whitespace.

=back

=head2 Exports

Type::Tiny::Enum can be used as an exporter.

  use Type::Tiny::Enum Status => [ 'dead', 'alive' ];

This will export the following functions into your namespace:

=over

=item C<< Status >>

=item C<< is_Status( $value ) >>

=item C<< assert_Status( $value ) >>

=item C<< to_Status( $value ) >>

=item C<< STATUS_DEAD >>

=item C<< STATUS_ALIVE >>

=back

Multiple enumerations can be exported at once:

  use Type::Tiny::Enum (
    Status    => [ 'dead', 'alive' ],
    TaxStatus => [ 'paid', 'pending' ],
  );

=head2 Overloading

=over

=item *

Arrayrefification calls C<values>.

=back

=head1 BUGS

Please report any bugs to
L<https://github.com/tobyink/p5-type-tiny/issues>.

=head1 SEE ALSO

L<Type::Tiny::Manual>.

L<Type::Tiny>.

L<Moose::Meta::TypeConstraint::Enum>.

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
