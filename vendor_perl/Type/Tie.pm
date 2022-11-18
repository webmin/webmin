use 5.008001;
use strict;
use warnings;

use Carp ();
use Exporter::Tiny ();
use Scalar::Util ();

++$Carp::CarpInternal{"Type::Tie::$_"} for qw( BASE SCALAR ARRAY HASH );

{
	package Type::Tie;
	our $AUTHORITY = 'cpan:TOBYINK';
	our $VERSION   = '2.000001';
	our @ISA       = qw( Exporter::Tiny );
	our @EXPORT    = qw( ttie );
	
	$VERSION =~ tr/_//d;
	
	sub ttie (\[$@%]@)#>&%*/&<%\$[]^!@;@)
	{
		my ( $ref, $type, @vals ) = @_;
		
		if ( 'HASH' eq ref $ref ) {
			tie %$ref, "Type::Tie::HASH", $type;
			%$ref = @vals if @vals;
		}
		elsif ( 'ARRAY' eq ref $ref ) {
			tie @$ref, "Type::Tie::ARRAY", $type;
			@$ref = @vals if @vals;
		}
		else {
			tie $$ref, "Type::Tie::SCALAR", $type;
			$$ref = $vals[-1] if @vals;
		}
		return $ref;
	}
};

{
	package Type::Tie::BASE;
	our $AUTHORITY = 'cpan:TOBYINK';
	our $VERSION   = '2.000001';
	
	$VERSION =~ tr/_//d;
	
	# Type::Tie::BASE is an array-based object. If you need to subclass it
	# and store more attributes, use $yourclass->SUPER::_NEXT_SLOT to find
	# the next available slot, then override _NEXT_SLOT so that other people
	# can subclass your class too.
	#
	sub _REF       { $_[0][0] }                                      # ro
	sub _TYPE      { ( @_ == 2 ) ? ( $_[0][1] = $_[1] ) : $_[0][1] } # rw
	sub _CHECK     { ( @_ == 2 ) ? ( $_[0][2] = $_[1] ) : $_[0][2] } # rw
	sub _COERCE    { ( @_ == 2 ) ? ( $_[0][3] = $_[1] ) : $_[0][3] } # rw
	sub _NEXT_SLOT { 4 }
	
	sub type       { shift->_TYPE }
	sub _INIT_REF  { $_[0][0] ||= $_[0]->_DEFAULT }
	
	{
		my $try_xs =
			exists( $ENV{PERL_TYPE_TINY_XS} ) ? !!$ENV{PERL_TYPE_TINY_XS} :
			exists( $ENV{PERL_ONLY} )         ? !$ENV{PERL_ONLY} :
			!!1;
		eval {
			require Class::XSAccessor::Array;
			'Class::XSAccessor::Array'->import(
				replace   => !!1,
				getters   => { _REF => 0, type => 1 },
				accessors => { _TYPE => 1, _CHECK => 2, _COERCE => 3 },
			);
		} if $try_xs;
	}
	
	sub _set_type {
		my $self = shift;
		my $type = $_[0];
		
		$self->_TYPE( $type );
		
		if ( Scalar::Util::blessed( $type ) and $type->isa( 'Type::Tiny' ) ) {
			$self->_CHECK( $type->compiled_check );
			$self->_COERCE(
				$type->has_coercion
					? $type->coercion->compiled_coercion
					: undef
			);
		}
		else {
			$self->_CHECK(
				$type->can( 'compiled_check' )
					? $type->compiled_check
					: sub { $type->check( $_[0] ) }
			);
			$self->_COERCE(
				$type->can( 'has_coercion' ) && $type->can( 'coerce' ) && $type->has_coercion
					? sub { $type->coerce( $_[0] ) }
					: undef
			);
		}
	}
	
	# Only used if the type has no get_message method
	sub _dd {
		require Type::Tiny;
		goto \&Type::Tiny::_dd;
	}
	
	sub coerce_and_check_value {
		my $self   = shift;
		my $check  = $self->_CHECK;
		my $coerce = $self->_COERCE;
		
		my @vals = map {
			my $val = $coerce ? $coerce->( $_ ) : $_;
			if ( not $check->( $val ) ) {
				my $type = $self->_TYPE;
				Carp::croak(
					$type && $type->can( 'get_message' )
						? $type->get_message( $val )
						: sprintf( '%s does not meet type constraint %s', _dd($_), $type || 'Unknown' )
				);
			}
			$val;
		} ( my @cp = @_ );  # need to copy @_ for Perl < 5.14
		
		wantarray ? @vals : $vals[0];
	}
	
	# store the $type for the exiting instances so the type can be set
	# (uncloned) in the clone too. A clone process could be cloning several
	# instances of this class, so use a hash to hold the types during
	# cloning. These types are reference counted, so the last reference to
	# a particular type deletes its key.
	my %tmp_clone_types;
	sub STORABLE_freeze {
		my ( $o, $cloning ) = @_;
		Carp::croak( "Storable::freeze only supported for dclone-ing" )
			unless $cloning;
		
		my $type = $o->_TYPE;
		my $refaddr = Scalar::Util::refaddr( $type );
		$tmp_clone_types{$refaddr} ||= [ $type, 0 ];
		++$tmp_clone_types{$refaddr}[1];
		
		return ( pack( 'j', $refaddr ), $o->_REF );
	}
	
	sub STORABLE_thaw {
		my ( $o, $cloning, $packedRefaddr, $o2 ) = @_;
		Carp::croak( "Storable::thaw only supported for dclone-ing" )
			unless $cloning;
		
		$o->_THAW( $o2 ); # implement in child classes
		
		my $refaddr = unpack( 'j', $packedRefaddr );
		my $type = $tmp_clone_types{$refaddr}[0];
		--$tmp_clone_types{$refaddr}[1]
			or delete $tmp_clone_types{$refaddr};
		$o->_set_type($type);
	}
};

{
	package Type::Tie::ARRAY;
	our $AUTHORITY = 'cpan:TOBYINK';
	our $VERSION   = '2.000001';
	our @ISA       = qw( Type::Tie::BASE );
	
	$VERSION =~ tr/_//d;
	
	sub TIEARRAY   {
		my $class = shift;
		my $self  = bless( [ $class->_DEFAULT ], $class );
		$self->_set_type( $_[0] );
		$self;
	}
	sub _DEFAULT   { [] }
	sub FETCHSIZE  { scalar @{ $_[0]->_REF } }
	sub STORESIZE  { $#{ $_[0]->_REF } = $_[1] }
	sub STORE      { $_[0]->_REF->[ $_[1] ] = $_[0]->coerce_and_check_value( $_[2] ) }
	sub FETCH      { $_[0]->_REF->[ $_[1] ] }
	sub CLEAR      { @{ $_[0]->_REF } = () }
	sub POP        { pop @{ $_[0]->_REF } }
	sub PUSH       { my $s = shift; push @{$s->_REF}, $s->coerce_and_check_value( @_ ) }
	sub SHIFT      { shift @{ $_[0]->_REF } }
	sub UNSHIFT    { my $s = shift; unshift @{$s->_REF}, $s->coerce_and_check_value( @_ ) }
	sub EXISTS     { exists $_[0]->_REF->[ $_[1] ] }
	sub DELETE     { delete $_[0]->_REF->[ $_[1] ] }
	sub EXTEND     {}
	sub SPLICE     {
		my $o   = shift;
		my $sz  = scalar @{$o->_REF};
		my $off = @_ ? shift : 0;
		$off   += $sz if $off < 0;
		my $len = @_ ? shift : $sz-$off;
		splice @{$o->_REF}, $off, $len, $o->coerce_and_check_value( @_ );
	}
	sub _THAW      { @{ $_[0]->_INIT_REF } = @{ $_[1] } }
};

{
	package Type::Tie::HASH;
	our $AUTHORITY = 'cpan:TOBYINK';
	our $VERSION   = '2.000001';
	our @ISA       = qw( Type::Tie::BASE );
	
	$VERSION =~ tr/_//d;
	
	sub TIEHASH    {
		my $class = shift;
		my $self  = bless( [ $class->_DEFAULT ], $class );
		$self->_set_type( $_[0] );
		$self;
	}
	sub _DEFAULT   { +{} }
	sub STORE      { $_[0]->_REF->{ $_[1] } = $_[0]->coerce_and_check_value( $_[2] ) }
	sub FETCH      { $_[0]->_REF->{ $_[1] } }
	sub FIRSTKEY   { my $a = scalar keys %{ $_[0]->_REF }; each %{ $_[0]->_REF } }
	sub NEXTKEY    { each %{ $_[0]->_REF } }
	sub EXISTS     { exists $_[0]->_REF->{ $_[1] } }
	sub DELETE     { delete $_[0]->_REF->{ $_[1] } }
	sub CLEAR      { %{ $_[0]->_REF } = () }
	sub SCALAR     { scalar %{ $_[0]->_REF } }
	sub _THAW      { %{ $_[0]->_INIT_REF } = %{ $_[1] } }
};

{
	package Type::Tie::SCALAR;
	our $AUTHORITY = 'cpan:TOBYINK';
	our $VERSION   = '2.000001';
	our @ISA       = qw( Type::Tie::BASE );
	
	$VERSION =~ tr/_//d;
	
	sub TIESCALAR  {
		my $class = shift;
		my $self  = bless( [ $class->_DEFAULT ], $class );
		$self->_set_type($_[0]);
		$self;
	}
	sub _DEFAULT   { my $x; \$x }
	sub STORE      { ${ $_[0]->_REF } = $_[0]->coerce_and_check_value( $_[1] ) }
	sub FETCH      { ${ $_[0]->_REF } }
	sub _THAW      { ${ $_[0]->_INIT_REF } = ${ $_[1] } }
};

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Type::Tie - tie a variable to a type constraint

=head1 SYNOPSIS

Type::Tie is a response to this sort of problem...

   use strict;
   use warnings;
   
   {
      package Local::Testing;
      use Moose;
      has numbers => ( is => "ro", isa => "ArrayRef[Num]" );
   }
   
   # Nice list of numbers.
   my @N = ( 1, 2, 3, 3.14159 );
   
   # Create an object with a reference to that list.
   my $object = Local::Testing->new(numbers => \@N);
   
   # Everything OK so far...
   
   # Now watch this!
   push @N, "Monkey!";
   print $object->dump;
   
   # Houston, we have a problem!

Just declare C<< @N >> like this:

   use Type::Tie;
   use Types::Standard qw( Num );
   
   ttie my @N, Num, ( 1, 2, 3, 3.14159 );

Now any attempt to add a non-numeric value to C<< @N >> will die.

=head1 DESCRIPTION

This module exports a single function: C<ttie>. C<ttie> ties a variable
to a type constraint, ensuring that whatever values stored in the variable
will conform to the type constraint. If the type constraint has coercions,
these will be used if necessary to ensure values assigned to the variable
conform.

   use Type::Tie;
   use Types::Standard qw( Int Num );
   
   ttie my $count, Int->plus_coercions(Num, 'int $_'), 0;
   
   print tied($count)->type, "\n";   # 'Int'
   
   $count++;            # ok
   $count = 2;          # ok
   $count = 3.14159;    # ok, coerced to 3
   $count = "Monkey!";  # dies

While the examples in documentation (and the test suite) show type
constraints from L<Types::Standard>, any type constraint objects
supporting the L<Type::API> interfaces should work. This includes:

=over

=item *

L<Moose::Meta::TypeConstraint> / L<MooseX::Types>

=item *

L<Mouse::Meta::TypeConstraint> / L<MouseX::Types>

=item *

L<Specio>

=item *

L<Type::Tiny|Type::Tiny::Manual>

=back

However, with Type::Tiny, you don't even need to C<< use Type::Tie >>.

   use Types::Standard qw( Int Num );
   
   tie my $count, Int->plus_coercions(Num, 'int $_'), 0;
   
   print tied($count)->type, "\n";   # 'Int'
   
   $count++;            # ok
   $count = 2;          # ok
   $count = 3.14159;    # ok, coerced to 3
   $count = "Monkey!";  # dies

=head2 Cloning tied variables

If you clone tied variables with C<dclone> from L<Storable>, the clone
will also be tied. The L<Clone> module is also able to successfully clone
tied variables. With other cloning techniques, your level of success may vary.

=begin trustme

=item ttie

=end trustme

=head1 BUGS

Please report any bugs to
L<http://rt.cpan.org/Dist/Display.html?Queue=Type-Tiny>.

=head1 SEE ALSO

L<Type::API>,
L<Type::Tiny>,
L<Type::Utils>,
L<Moose::Manual::Types>,
L<MooseX::Lexical::Types>.

=head1 AUTHOR

Toby Inkster E<lt>tobyink@cpan.orgE<gt>.

=head1 COPYRIGHT AND LICENCE

This software is copyright (c) 2013-2014, 2018-2019, 2022 by Toby Inkster.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=head1 DISCLAIMER OF WARRANTIES

THIS PACKAGE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.

