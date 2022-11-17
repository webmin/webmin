package Type::Tiny::ConstrainedObject;

use 5.008001;
use strict;
use warnings;

BEGIN {
	$Type::Tiny::ConstrainedObject::AUTHORITY = 'cpan:TOBYINK';
	$Type::Tiny::ConstrainedObject::VERSION   = '2.000001';
}

$Type::Tiny::ConstrainedObject::VERSION =~ tr/_//d;

sub _croak ($;@) { require Error::TypeTiny; goto \&Error::TypeTiny::croak }

use Type::Tiny ();
our @ISA = 'Type::Tiny';

my %errlabel = (
	parent     => 'a parent',
	constraint => 'a constraint coderef',
	inlined    => 'an inlining coderef',
);

sub new {
	my $proto = shift;
	my %opts  = ( @_ == 1 ) ? %{ $_[0] } : @_;
	for my $key ( qw/ parent constraint inlined / ) {
		next unless exists $opts{$key};
		_croak(
			'%s type constraints cannot have %s passed to the constructor',
			$proto->_short_name,
			$errlabel{$key},
		);
	}
	$proto->SUPER::new( %opts );
} #/ sub new

sub has_parent {
	!!1;
}

sub parent {
	require Types::Standard;
	Types::Standard::Object();
}

sub _short_name {
	die "subclasses must implement this";    # uncoverable statement
}

my $i                  = 0;
my $_where_expressions = sub {
	my $self = shift;
	my $name = shift;
	$name ||= "where expression check";
	my ( %env, @codes );
	while ( @_ ) {
		my $expr       = shift;
		my $constraint = shift;
		if ( !ref $constraint ) {
			push @codes, sprintf( 'do { local $_ = %s; %s }', $expr, $constraint );
		}
		else {
			require Types::Standard;
			my $type =
				Types::Standard::is_RegexpRef( $constraint )
				? Types::Standard::StrMatch()->of( $constraint )
				: Types::TypeTiny::to_TypeTiny( $constraint );
			if ( $type->can_be_inlined ) {
				push @codes,
					sprintf(
					'do { my $tmp = %s; %s }', $expr,
					$type->inline_check( '$tmp' )
					);
			}
			else {
				++$i;
				$env{ '$chk' . $i } = do { my $chk = $type->compiled_check; \$chk };
				push @codes, sprintf( '$chk%d->(%s)', $i, $expr );
			}
		} #/ else [ if ( !ref $constraint )]
	} #/ while ( @_ )
	
	if ( keys %env ) {
	
		# cannot inline
		my $sub = Eval::TypeTiny::eval_closure(
			source =>
				sprintf( 'sub ($) { local $_ = shift; %s }', join( q( and ), @codes ) ),
			description => sprintf( '%s for %s', $name, $self->name ),
			environment => \%env,
		);
		return $self->where( $sub );
	} #/ if ( keys %env )
	else {
		return $self->where( join( q( and ), @codes ) );
	}
};

sub stringifies_to {
	my $self = shift;
	my ( $constraint ) = @_;
	$self->$_where_expressions( "stringification check", q{"$_"}, $constraint );
}

sub numifies_to {
	my $self = shift;
	my ( $constraint ) = @_;
	$self->$_where_expressions( "numification check", q{0+$_}, $constraint );
}

sub with_attribute_values {
	my $self       = shift;
	my %constraint = @_;
	$self->$_where_expressions(
		"attributes check",
		map { my $attr = $_; qq{\$_->$attr} => $constraint{$attr} }
			sort keys %constraint,
	);
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Type::Tiny::ConstrainedObject - shared behavour for Type::Tiny::Class, etc

=head1 STATUS

This module is considered experiemental.

=head1 DESCRIPTION

=head2 Methods

The following methods exist for L<Type::Tiny::Class>, L<Type::Tiny::Role>,
L<Type::Tiny::Duck>, and any type constraints that inherit from
C<Object> or C<Overload> in L<Types::Standard>.

These methods will also work for L<Type::Tiny::Intersection> if at least
one of the types in the intersection provides these methods.

These methods will also work for L<Type::Tiny::Union> if all of the types
in the union provide these methods.

=over

=item C<< stringifies_to($constraint) >>

Generates a new child type constraint which checks the object's
stringification against a constraint. For example:

   my $type  = Type::Tiny::Class->new(class => 'URI');
   my $child = $type->stringifies_to( StrMatch[qr/^http:/] );
   
   $child->assert_valid( URI->new("http://example.com/") );

In the above example, C<< $child >> is a type constraint that
checks objects are blessed into (or inherit from) the URI class,
and when stringified (e.g. though overloading) the result
matches the regular expression C<< qr/^http:/ >>.

C<< $constraint >> may be a type constraint, something that
can be coerced to a type constraint (such as a coderef returning
a boolean), a string of Perl code operating on C<< $_ >>, or
a reference to a regular expression.

So the following would work:

   my $child = $type->stringifies_to( sub { qr/^http:/ } );
   my $child = $type->stringifies_to(       qr/^http:/   );
   my $child = $type->stringifies_to(       'm/^http:/'  );
   
   my $child = $type->where('"$_" =~ /^http:/');

=item C<< numifies_to($constraint) >>

The same as C<stringifies_to> but checks numification.

The following might be useful:

   use Types::Standard qw(Int Overload);
   my $IntLike = Int | Overload->numifies_to(Int)

=item C<< with_attribute_values($attr1 => $constraint1, ...) >>

This is best explained with an example:

   use Types::Common qw( InstanceOf StrMatch IntRange );
   
   my $person = InstanceOf['Local::Human'];
   my $woman  = $person->with_attribute_values(
      gender   => StrMatch[ qr/^F/i  ],
      age      => IntRange[ 18 => () ],
   );
   
   $woman->assert_valid($alice);

This assertion will firstly check that C<< $alice >> is a
Local::Human, then check that C<< $alice->gender >> starts
with an "F", and lastly check that C<< $alice->age >> is
an integer at least 18.

Again, constraints can be type constraints, coderefs,
strings of Perl code, or regular expressions.

Technically the "attributes" don't need to be Moo/Moose/Mouse
attributes, but any methods which can be called with no
parameters and return a scalar.

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

This software is copyright (c) 2019-2022 by Toby Inkster.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=head1 DISCLAIMER OF WARRANTIES

THIS PACKAGE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.
