package Type::Tiny::Union;

use 5.008001;
use strict;
use warnings;

BEGIN {
	$Type::Tiny::Union::AUTHORITY = 'cpan:TOBYINK';
	$Type::Tiny::Union::VERSION   = '2.000001';
}

$Type::Tiny::Union::VERSION =~ tr/_//d;

use Scalar::Util qw< blessed >;
use Types::TypeTiny ();

sub _croak ($;@) { require Error::TypeTiny; goto \&Error::TypeTiny::croak }

use Type::Tiny ();
our @ISA = 'Type::Tiny';

__PACKAGE__->_install_overloads(
	q[@{}] => sub { $_[0]{type_constraints} ||= [] } );

sub new_by_overload {
	my $proto = shift;
	my %opts  = ( @_ == 1 ) ? %{ $_[0] } : @_;

	my @types = @{ $opts{type_constraints} };
	if ( my @makers = map scalar( blessed($_) && $_->can( 'new_union' ) ), @types ) {
		my $first_maker = shift @makers;
		if ( ref $first_maker ) {
			my $all_same = not grep +( !defined $_ or $_ ne $first_maker ), @makers;
			if ( $all_same ) {
				return ref( $types[0] )->$first_maker( %opts );
			}
		}
	}

	return $proto->new( \%opts );
}

sub new {
	my $proto = shift;
	
	my %opts = ( @_ == 1 ) ? %{ $_[0] } : @_;
	_croak
		"Union type constraints cannot have a parent constraint passed to the constructor"
		if exists $opts{parent};
	_croak
		"Union type constraints cannot have a constraint coderef passed to the constructor"
		if exists $opts{constraint};
	_croak
		"Union type constraints cannot have a inlining coderef passed to the constructor"
		if exists $opts{inlined};
	_croak "Need to supply list of type constraints"
		unless exists $opts{type_constraints};
		
	$opts{type_constraints} = [
		map { $_->isa( __PACKAGE__ ) ? @$_ : $_ }
			map Types::TypeTiny::to_TypeTiny( $_ ),
		@{
			ref $opts{type_constraints} eq "ARRAY"
			? $opts{type_constraints}
			: [ $opts{type_constraints} ]
		}
	];
	
	if ( Type::Tiny::_USE_XS ) {
		my @constraints = @{ $opts{type_constraints} };
		my @known       = map {
			my $known = Type::Tiny::XS::is_known( $_->compiled_check );
			defined( $known ) ? $known : ();
		} @constraints;
		
		if ( @known == @constraints ) {
			my $xsub = Type::Tiny::XS::get_coderef_for(
				sprintf "AnyOf[%s]",
				join( ',', @known )
			);
			$opts{compiled_type_constraint} = $xsub if $xsub;
		}
	} #/ if ( Type::Tiny::_USE_XS)
	
	my $self = $proto->SUPER::new( %opts );
	$self->coercion if grep $_->has_coercion, @$self;
	return $self;
} #/ sub new

sub type_constraints { $_[0]{type_constraints} }
sub constraint       { $_[0]{constraint} ||= $_[0]->_build_constraint }

sub _is_null_constraint { 0 }

sub _build_display_name {
	my $self = shift;
	join q[|], @$self;
}

sub _build_coercion {
	require Type::Coercion::Union;
	my $self = shift;
	return "Type::Coercion::Union"->new( type_constraint => $self );
}

sub _build_constraint {
	my @checks = map $_->compiled_check, @{ +shift };
	return sub {
		my $val = $_;
		$_->( $val ) && return !!1 for @checks;
		return;
	}
}

sub can_be_inlined {
	my $self = shift;
	not grep !$_->can_be_inlined, @$self;
}

sub inline_check {
	my $self = shift;
	
	if ( Type::Tiny::_USE_XS and !exists $self->{xs_sub} ) {
		$self->{xs_sub} = undef;
		
		my @constraints = @{ $self->type_constraints };
		my @known       = map {
			my $known = Type::Tiny::XS::is_known( $_->compiled_check );
			defined( $known ) ? $known : ();
		} @constraints;
		
		if ( @known == @constraints ) {
			$self->{xs_sub} = Type::Tiny::XS::get_subname_for(
				sprintf "AnyOf[%s]",
				join( ',', @known )
			);
		}
	} #/ if ( Type::Tiny::_USE_XS...)
	
	my $code = sprintf '(%s)', join " or ", map $_->inline_check( $_[0] ), @$self;
	
	return "do { $Type::Tiny::SafePackage $code }"
		if $Type::Tiny::AvoidCallbacks;
	return "$self->{xs_sub}\($_[0]\)"
		if $self->{xs_sub};
	return $code;
} #/ sub inline_check

sub _instantiate_moose_type {
	my $self = shift;
	my %opts = @_;
	delete $opts{parent};
	delete $opts{constraint};
	delete $opts{inlined};
	
	my @tc = map $_->moose_type, @{ $self->type_constraints };
	
	require Moose::Meta::TypeConstraint::Union;
	return "Moose::Meta::TypeConstraint::Union"
		->new( %opts, type_constraints => \@tc );
} #/ sub _instantiate_moose_type

sub has_parent {
	defined( shift->parent );
}

sub parent {
	$_[0]{parent} ||= $_[0]->_build_parent;
}

sub _build_parent {
	my $self = shift;
	my ( $first, @rest ) = @$self;
	
	for my $parent ( $first, $first->parents ) {
		return $parent unless grep !$_->is_a_type_of( $parent ), @rest;
	}
	
	return;
} #/ sub _build_parent

sub find_type_for {
	my @types = @{ +shift };
	for my $type ( @types ) {
		return $type if $type->check( @_ );
	}
	return;
}

sub validate_explain {
	my $self = shift;
	my ( $value, $varname ) = @_;
	$varname = '$_' unless defined $varname;
	
	return undef if $self->check( $value );
	
	require Type::Utils;
	return [
		sprintf(
			'"%s" requires that the value pass %s',
			$self,
			Type::Utils::english_list( \"or", map qq["$_"], @$self ),
		),
		map {
			$_->get_message( $value ),
				map( "    $_", @{ $_->validate_explain( $value ) || [] } ),
		} @$self
	];
} #/ sub validate_explain

my $_delegate = sub {
	my ( $self, $method ) = ( shift, shift );
	my @types = @{ $self->type_constraints };
	
	my @unsupported = grep !$_->can( $method ), @types;
	_croak( 'Could not apply method %s to all types within the union', $method )
		if @unsupported;
		
	ref( $self )->new( type_constraints => [ map $_->$method( @_ ), @types ] );
};

sub stringifies_to {
	my $self = shift;
	$self->$_delegate( stringifies_to => @_ );
}

sub numifies_to {
	my $self = shift;
	$self->$_delegate( numifies_to => @_ );
}

sub with_attribute_values {
	my $self = shift;
	$self->$_delegate( with_attribute_values => @_ );
}

push @Type::Tiny::CMP, sub {
	my $A = shift->find_constraining_type;
	my $B = shift->find_constraining_type;
	
	if ( $A->isa( __PACKAGE__ ) and $B->isa( __PACKAGE__ ) ) {
		my @A_constraints = @{ $A->type_constraints };
		my @B_constraints = @{ $B->type_constraints };
		
		# If everything in @A_constraints is equal to something in @B_constraints and vice versa, then $A equiv to $B
		EQUALITY: {
			my $everything_in_a_is_equal = 1;
			OUTER: for my $A_child ( @A_constraints ) {
				INNER: for my $B_child ( @B_constraints ) {
					if ( $A_child->equals( $B_child ) ) {
						next OUTER;
					}
				}
				$everything_in_a_is_equal = 0;
				last OUTER;
			}
			
			my $everything_in_b_is_equal = 1;
			OUTER: for my $B_child ( @B_constraints ) {
				INNER: for my $A_child ( @A_constraints ) {
					if ( $B_child->equals( $A_child ) ) {
						next OUTER;
					}
				}
				$everything_in_b_is_equal = 0;
				last OUTER;
			}
			
			return Type::Tiny::CMP_EQUIVALENT
				if $everything_in_a_is_equal && $everything_in_b_is_equal;
		} #/ EQUALITY:
		
		# If everything in @A_constraints is a subtype of something in @B_constraints, then $A is subtype of $B
		SUBTYPE: {
			OUTER: for my $A_child ( @A_constraints ) {
				my $a_child_is_subtype_of_something = 0;
				INNER: for my $B_child ( @B_constraints ) {
					if ( $A_child->is_a_type_of( $B_child ) ) {
						++$a_child_is_subtype_of_something;
						last INNER;
					}
				}
				if ( not $a_child_is_subtype_of_something ) {
					last SUBTYPE;
				}
			} #/ OUTER: for my $A_child ( @A_constraints)
			return Type::Tiny::CMP_SUBTYPE;
		} #/ SUBTYPE:
		
		# If everything in @B_constraints is a subtype of something in @A_constraints, then $A is supertype of $B
		SUPERTYPE: {
			OUTER: for my $B_child ( @B_constraints ) {
				my $b_child_is_subtype_of_something = 0;
				INNER: for my $A_child ( @A_constraints ) {
					if ( $B_child->is_a_type_of( $A_child ) ) {
						++$b_child_is_subtype_of_something;
						last INNER;
					}
				}
				if ( not $b_child_is_subtype_of_something ) {
					last SUPERTYPE;
				}
			} #/ OUTER: for my $B_child ( @B_constraints)
			return Type::Tiny::CMP_SUPERTYPE;
		} #/ SUPERTYPE:
	} #/ if ( $A->isa( __PACKAGE__...))
	
	# I think it might be possible to merge this into the first bit by treating $B as union[$B].
	# Test cases first though.
	if ( $A->isa( __PACKAGE__ ) ) {
		my @A_constraints = @{ $A->type_constraints };
		if ( @A_constraints == 1 ) {
			my $result = Type::Tiny::cmp( $A_constraints[0], $B );
			return $result unless $result eq Type::Tiny::CMP_UNKNOWN;
		}
		my $subtype = 1;
		for my $child ( @A_constraints ) {
			if ( $B->is_a_type_of( $child ) ) {
				return Type::Tiny::CMP_SUPERTYPE;
			}
			if ( $subtype and not $B->is_supertype_of( $child ) ) {
				$subtype = 0;
			}
		}
		if ( $subtype ) {
			return Type::Tiny::CMP_SUBTYPE;
		}
	} #/ if ( $A->isa( __PACKAGE__...))
	
	# I think it might be possible to merge this into the first bit by treating $A as union[$A].
	# Test cases first though.
	if ( $B->isa( __PACKAGE__ ) ) {
		my @B_constraints = @{ $B->type_constraints };
		if ( @B_constraints == 1 ) {
			my $result = Type::Tiny::cmp( $A, $B_constraints[0] );
			return $result unless $result eq Type::Tiny::CMP_UNKNOWN;
		}
		my $supertype = 1;
		for my $child ( @B_constraints ) {
			if ( $A->is_a_type_of( $child ) ) {
				return Type::Tiny::CMP_SUBTYPE;
			}
			if ( $supertype and not $A->is_supertype_of( $child ) ) {
				$supertype = 0;
			}
		}
		if ( $supertype ) {
			return Type::Tiny::CMP_SUPERTYPE;
		}
	} #/ if ( $B->isa( __PACKAGE__...))
	
	return Type::Tiny::CMP_UNKNOWN;
};

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Type::Tiny::Union - union type constraints

=head1 STATUS

This module is covered by the
L<Type-Tiny stability policy|Type::Tiny::Manual::Policies/"STABILITY">.

=head1 DESCRIPTION

Union type constraints.

This package inherits from L<Type::Tiny>; see that for most documentation.
Major differences are listed below:

=head2 Constructor

The C<new> constructor from L<Type::Tiny> still works, of course. But there
is also:

=over

=item C<< new_by_overload(%attributes) >>

Like the C<new> constructor, but will sometimes return another type
constraint which is not strictly an instance of L<Type::Tiny::Union>, but
still encapsulates the same meaning. This constructor is used by
Type::Tiny's overloading of the C<< | >> operator.

=back

=head2 Attributes

=over

=item C<type_constraints>

Arrayref of type constraints.

When passed to the constructor, if any of the type constraints in the union
is itself a union type constraint, this is "exploded" into the new union.

=item C<constraint>

Unlike Type::Tiny, you I<cannot> pass a constraint coderef to the constructor.
Instead rely on the default.

=item C<inlined>

Unlike Type::Tiny, you I<cannot> pass an inlining coderef to the constructor.
Instead rely on the default.

=item C<parent>

Unlike Type::Tiny, you I<cannot> pass an inlining coderef to the constructor.
A parent will instead be automatically calculated.

=item C<coercion>

You probably do not pass this to the constructor. (It's not currently
disallowed, as there may be a use for it that I haven't thought of.)

The auto-generated default will be a L<Type::Coercion::Union> object.

=back

=head2 Methods

=over

=item C<< find_type_for($value) >>

Returns the first individual type constraint in the union which
C<< $value >> passes.

=item C<< stringifies_to($constraint) >>

See L<Type::Tiny::ConstrainedObject>.

=item C<< numifies_to($constraint) >>

See L<Type::Tiny::ConstrainedObject>.

=item C<< with_attribute_values($attr1 => $constraint1, ...) >>

See L<Type::Tiny::ConstrainedObject>.

=back

=head2 Overloading

=over

=item *

Arrayrefification calls C<type_constraints>.

=back

=head1 BUGS

Please report any bugs to
L<https://github.com/tobyink/p5-type-tiny/issues>.

=head1 SEE ALSO

L<Type::Tiny::Manual>.

L<Type::Tiny>.

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
