package Type::Coercion;

use 5.008001;
use strict;
use warnings;

BEGIN {
	$Type::Coercion::AUTHORITY = 'cpan:TOBYINK';
	$Type::Coercion::VERSION   = '2.000001';
}

$Type::Coercion::VERSION =~ tr/_//d;

use Eval::TypeTiny qw<>;
use Scalar::Util qw< blessed >;
use Types::TypeTiny qw<>;

sub _croak ($;@) { require Error::TypeTiny; goto \&Error::TypeTiny::croak }

require Type::Tiny;

__PACKAGE__->Type::Tiny::_install_overloads(
	q("") => sub {
		caller =~ m{^(Moo::HandleMoose|Sub::Quote)}
			? $_[0]->_stringify_no_magic
			: $_[0]->display_name;
	},
	q(bool) => sub { 1 },
	q(&{})  => "_overload_coderef",
);

__PACKAGE__->Type::Tiny::_install_overloads(
	q(~~) => sub { $_[0]->has_coercion_for_value( $_[1] ) },
) if Type::Tiny::SUPPORT_SMARTMATCH();

sub _overload_coderef {
	my $self = shift;
	
	if ( "Sub::Quote"->can( "quote_sub" ) && $self->can_be_inlined ) {
		$self->{_overload_coderef} =
			Sub::Quote::quote_sub( $self->inline_coercion( '$_[0]' ) )
			if !$self->{_overload_coderef} || !$self->{_sub_quoted}++;
	}
	else {
		Scalar::Util::weaken( my $weak = $self );
		$self->{_overload_coderef} ||= sub { $weak->coerce( @_ ) };
	}
	
	$self->{_overload_coderef};
} #/ sub _overload_coderef

sub new {
	my $class  = shift;
	my %params = ( @_ == 1 ) ? %{ $_[0] } : @_;
	
	$params{name} = '__ANON__' unless exists( $params{name} );
	my $C = delete( $params{type_coercion_map} ) || [];
	my $F = delete( $params{frozen} );
	
	my $self = bless \%params, $class;
	$self->add_type_coercions( @$C ) if @$C;
	$self->_preserve_type_constraint;
	Scalar::Util::weaken( $self->{type_constraint} );    # break ref cycle
	$self->{frozen} = $F if $F;
	
	unless ( $self->is_anon ) {
	
		# First try a fast ASCII-only expression, but fall back to Unicode
		$self->name =~ /^_{0,2}[A-Z][A-Za-z0-9_]+$/sm
			or eval q( use 5.008; $self->name =~ /^_{0,2}\p{Lu}[\p{L}0-9_]+$/sm )
			or _croak '"%s" is not a valid coercion name', $self->name;
	}
	
	return $self;
} #/ sub new

sub _stringify_no_magic {
	sprintf(
		'%s=%s(0x%08x)', blessed( $_[0] ), Scalar::Util::reftype( $_[0] ),
		Scalar::Util::refaddr( $_[0] )
	);
}

sub name         { $_[0]{name} }
sub display_name { $_[0]{display_name} ||= $_[0]->_build_display_name }
sub library      { $_[0]{library} }

sub type_constraint {
	$_[0]{type_constraint} ||= $_[0]->_maybe_restore_type_constraint;
}
sub type_coercion_map { $_[0]{type_coercion_map} ||= [] }
sub moose_coercion { $_[0]{moose_coercion} ||= $_[0]->_build_moose_coercion }

sub compiled_coercion {
	$_[0]{compiled_coercion} ||= $_[0]->_build_compiled_coercion;
}
sub frozen             { $_[0]{frozen} ||= 0 }
sub coercion_generator { $_[0]{coercion_generator} }
sub parameters         { $_[0]{parameters} }
sub parameterized_from { $_[0]{parameterized_from} }

sub has_library            { exists $_[0]{library} }
sub has_type_constraint    { defined $_[0]->type_constraint }     # sic
sub has_coercion_generator { exists $_[0]{coercion_generator} }
sub has_parameters         { exists $_[0]{parameters} }

sub _preserve_type_constraint {
	my $self = shift;
	$self->{_compiled_type_constraint_check} =
		$self->{type_constraint}->compiled_check
		if $self->{type_constraint};
}

sub _maybe_restore_type_constraint {
	my $self = shift;
	if ( my $check = $self->{_compiled_type_constraint_check} ) {
		return Type::Tiny->new( constraint => $check );
	}
	return;    # uncoverable statement
}

sub add {
	my $class = shift;
	my ( $x, $y, $swap ) = @_;
	
	Types::TypeTiny::is_TypeTiny( $x ) and return $x->plus_fallback_coercions( $y );
	Types::TypeTiny::is_TypeTiny( $y ) and return $y->plus_coercions( $x );
	
	_croak "Attempt to add $class to something that is not a $class"
		unless blessed( $x )
		&& blessed( $y )
		&& $x->isa( $class )
		&& $y->isa( $class );
		
	( $y, $x ) = ( $x, $y ) if $swap;
	
	my %opts;
	if ( $x->has_type_constraint
		and $y->has_type_constraint
		and $x->type_constraint == $y->type_constraint )
	{
		$opts{type_constraint} = $x->type_constraint;
	}
	elsif ( $x->has_type_constraint and $y->has_type_constraint ) {
	
		#		require Type::Tiny::Union;
		#		$opts{type_constraint} = "Type::Tiny::Union"->new(
		#			type_constraints => [ $x->type_constraint, $y->type_constraint ],
		#		);
	}
	$opts{display_name} ||= "$x+$y";
	delete $opts{display_name} if $opts{display_name} eq '__ANON__+__ANON__';
	
	my $new = $class->new( %opts );
	$new->add_type_coercions( @{ $x->type_coercion_map } );
	$new->add_type_coercions( @{ $y->type_coercion_map } );
	return $new;
} #/ sub add

sub _build_display_name {
	shift->name;
}

sub qualified_name {
	my $self = shift;
	
	if ( $self->has_library and not $self->is_anon ) {
		return sprintf( "%s::%s", $self->library, $self->name );
	}
	
	return $self->name;
}

sub is_anon {
	my $self = shift;
	$self->name eq "__ANON__";
}

sub _clear_compiled_coercion {
	delete $_[0]{_overload_coderef};
	delete $_[0]{compiled_coercion};
}

sub freeze                    { $_[0]{frozen} = 1; $_[0] }
sub i_really_want_to_unfreeze { $_[0]{frozen} = 0; $_[0] }

sub coerce {
	my $self = shift;
	return $self->compiled_coercion->( @_ );
}

sub assert_coerce {
	my $self = shift;
	my $r    = $self->coerce( @_ );
	$self->type_constraint->assert_valid( $r )
		if $self->has_type_constraint;
	return $r;
}

sub has_coercion_for_type {
	my $self = shift;
	my $type = Types::TypeTiny::to_TypeTiny( $_[0] );
	
	return "0 but true"
		if $self->has_type_constraint
		&& $type->is_a_type_of( $self->type_constraint );
		
	my $c = $self->type_coercion_map;
	for ( my $i = 0 ; $i <= $#$c ; $i += 2 ) {
		return !!1 if $type->is_a_type_of( $c->[$i] );
	}
	return;
} #/ sub has_coercion_for_type

sub has_coercion_for_value {
	my $self = shift;
	local $_ = $_[0];
	
	return "0 but true"
		if $self->has_type_constraint
		&& $self->type_constraint->check( @_ );
		
	my $c = $self->type_coercion_map;
	for ( my $i = 0 ; $i <= $#$c ; $i += 2 ) {
		return !!1 if $c->[$i]->check( @_ );
	}
	return;
} #/ sub has_coercion_for_value

sub add_type_coercions {
	my $self = shift;
	my @args = @_;
	
	_croak "Attempt to add coercion code to a Type::Coercion which has been frozen"
		if $self->frozen;
		
	while ( @args ) {
		my $type = Types::TypeTiny::to_TypeTiny( shift @args );
		
		if ( blessed $type and my $method = $type->can( 'type_coercion_map' ) ) {
			push @{ $self->type_coercion_map }, @{ $method->( $type ) };
		}
		else {
			my $coercion = shift @args;
			_croak "Types must be blessed Type::Tiny objects"
				unless Types::TypeTiny::is_TypeTiny( $type );
			_croak "Coercions must be code references or strings"
				unless Types::TypeTiny::is_StringLike( $coercion )
				|| Types::TypeTiny::is_CodeLike( $coercion );
			push @{ $self->type_coercion_map }, $type, $coercion;
		}
	} #/ while ( @args )
	
	$self->_clear_compiled_coercion;
	return $self;
} #/ sub add_type_coercions

sub _build_compiled_coercion {
	my $self = shift;
	
	my @mishmash = @{ $self->type_coercion_map };
	return sub { $_[0] }
		unless @mishmash;
		
	if ( $self->can_be_inlined ) {
		return Eval::TypeTiny::eval_closure(
			source      => sprintf( 'sub ($) { %s }', $self->inline_coercion( '$_[0]' ) ),
			description => sprintf( "compiled coercion '%s'", $self ),
		);
	}
	
	# These arrays will be closed over.
	my ( @types, @codes );
	while ( @mishmash ) {
		push @types, shift @mishmash;
		push @codes, shift @mishmash;
	}
	if ( $self->has_type_constraint ) {
		unshift @types, $self->type_constraint;
		unshift @codes, undef;
	}
	
	my @sub;
	
	for my $i ( 0 .. $#types ) {
		push @sub,
			$types[$i]->can_be_inlined
			? sprintf( 'if (%s)',                $types[$i]->inline_check( '$_[0]' ) )
			: sprintf( 'if ($checks[%d]->(@_))', $i );
		push @sub,
			!defined( $codes[$i] )
			? sprintf( '  { return $_[0] }' )
			: Types::TypeTiny::is_StringLike( $codes[$i] ) ? sprintf(
			'  { local $_ = $_[0]; return scalar(%s); }',
			$codes[$i]
			)
			: sprintf( '  { local $_ = $_[0]; return scalar($codes[%d]->(@_)) }', $i );
	} #/ for my $i ( 0 .. $#types)
	
	push @sub, 'return $_[0];';
	
	return Eval::TypeTiny::eval_closure(
		source      => sprintf( 'sub ($) { %s }', join qq[\n], @sub ),
		description => sprintf( "compiled coercion '%s'", $self ),
		environment => {
			'@checks' => [ map $_->compiled_check, @types ],
			'@codes'  => \@codes,
		},
	);
} #/ sub _build_compiled_coercion

sub can_be_inlined {
	my $self = shift;
	
	return unless $self->frozen;
	
	return
		if $self->has_type_constraint
		&& !$self->type_constraint->can_be_inlined;
		
	my @mishmash = @{ $self->type_coercion_map };
	while ( @mishmash ) {
		my ( $type, $converter ) = splice( @mishmash, 0, 2 );
		return unless $type->can_be_inlined;
		return unless Types::TypeTiny::is_StringLike( $converter );
	}
	return !!1;
} #/ sub can_be_inlined

sub _source_type_union {
	my $self = shift;
	
	my @r;
	push @r, $self->type_constraint if $self->has_type_constraint;
	
	my @mishmash = @{ $self->type_coercion_map };
	while ( @mishmash ) {
		my ( $type ) = splice( @mishmash, 0, 2 );
		push @r, $type;
	}
	
	require Type::Tiny::Union;
	return "Type::Tiny::Union"->new( type_constraints => \@r, tmp => 1 );
} #/ sub _source_type_union

sub inline_coercion {
	my $self    = shift;
	my $varname = $_[0];
	
	_croak "This coercion cannot be inlined" unless $self->can_be_inlined;
	
	my @mishmash = @{ $self->type_coercion_map };
	return "($varname)" unless @mishmash;
	
	my ( @types, @codes );
	while ( @mishmash ) {
		push @types, shift @mishmash;
		push @codes, shift @mishmash;
	}
	if ( $self->has_type_constraint ) {
		unshift @types, $self->type_constraint;
		unshift @codes, undef;
	}
	
	my @sub;
	
	for my $i ( 0 .. $#types ) {
		push @sub, sprintf( '(%s) ?', $types[$i]->inline_check( $varname ) );
		push @sub,
			( defined( $codes[$i] ) && ( $varname eq '$_' ) )
			? sprintf( 'scalar(do { %s }) :', $codes[$i] )
			: defined( $codes[$i] ) ? sprintf(
			'scalar(do { local $_ = %s; %s }) :', $varname,
			$codes[$i]
			)
			: sprintf( '%s :', $varname );
	} #/ for my $i ( 0 .. $#types)
	
	push @sub, "$varname";
	
	"@sub";
} #/ sub inline_coercion

sub _build_moose_coercion {
	my $self = shift;
	
	my %options = ();
	$options{type_coercion_map} =
		[ $self->freeze->_codelike_type_coercion_map( 'moose_type' ) ];
	$options{type_constraint} = $self->type_constraint
		if $self->has_type_constraint;
		
	require Moose::Meta::TypeCoercion;
	my $r = "Moose::Meta::TypeCoercion"->new( %options );
	
	return $r;
} #/ sub _build_moose_coercion

sub _codelike_type_coercion_map {
	my $self     = shift;
	my $modifier = $_[0];
	
	my @orig = @{ $self->type_coercion_map };
	my @new;
	
	while ( @orig ) {
		my ( $type, $converter ) = splice( @orig, 0, 2 );
		
		push @new, $modifier ? $type->$modifier : $type;
		
		if ( Types::TypeTiny::is_CodeLike( $converter ) ) {
			push @new, $converter;
		}
		else {
			push @new, Eval::TypeTiny::eval_closure(
				source      => sprintf( 'sub { local $_ = $_[0]; %s }',           $converter ),
				description => sprintf( "temporary compiled converter from '%s'", $type ),
			);
		}
	} #/ while ( @orig )
	
	return @new;
} #/ sub _codelike_type_coercion_map

sub is_parameterizable {
	shift->has_coercion_generator;
}

sub is_parameterized {
	shift->has_parameters;
}

sub parameterize {
	my $self = shift;
	return $self unless @_;
	$self->is_parameterizable
		or _croak "Constraint '%s' does not accept parameters", "$self";
		
	@_ = map Types::TypeTiny::to_TypeTiny( $_ ), @_;
	
	return ref( $self )->new(
		type_constraint   => $self->type_constraint,
		type_coercion_map =>
			[ $self->coercion_generator->( $self, $self->type_constraint, @_ ) ],
		parameters         => \@_,
		frozen             => 1,
		parameterized_from => $self,
	);
} #/ sub parameterize

sub _reparameterize {
	my $self = shift;
	my ( $target_type ) = @_;
	
	$self->is_parameterized or return $self;
	my $parent = $self->parameterized_from;
	
	return ref( $self )->new(
		type_constraint   => $target_type,
		type_coercion_map => [
			$parent->coercion_generator->( $parent, $target_type, @{ $self->parameters } )
		],
		parameters         => \@_,
		frozen             => 1,
		parameterized_from => $parent,
	);
} #/ sub _reparameterize

sub isa {
	my $self = shift;
	
	if ( $INC{"Moose.pm"}
		and blessed( $self )
		and $_[0] eq 'Moose::Meta::TypeCoercion' )
	{
		return !!1;
	}
	
	if ( $INC{"Moose.pm"}
		and blessed( $self )
		and $_[0] =~ /^(Class::MOP|MooseX?)::/ )
	{
		my $r = $self->moose_coercion->isa( @_ );
		return $r if $r;
	}
	
	$self->SUPER::isa( @_ );
} #/ sub isa

sub can {
	my $self = shift;
	
	my $can = $self->SUPER::can( @_ );
	return $can if $can;
	
	if ( $INC{"Moose.pm"}
		and blessed( $self )
		and my $method = $self->moose_coercion->can( @_ ) )
	{
		return sub { $method->( shift->moose_coercion, @_ ) };
	}
	
	return;
} #/ sub can

sub AUTOLOAD {
	my $self = shift;
	my ( $m ) = ( our $AUTOLOAD =~ /::(\w+)$/ );
	return if $m eq 'DESTROY';
	
	if ( $INC{"Moose.pm"}
		and blessed( $self )
		and my $method = $self->moose_coercion->can( $m ) )
	{
		return $method->( $self->moose_coercion, @_ );
	}
	
	_croak q[Can't locate object method "%s" via package "%s"], $m,
		ref( $self ) || $self;
} #/ sub AUTOLOAD

# Private Moose method, but Moo uses this...
sub _compiled_type_coercion {
	my $self = shift;
	if ( @_ ) {
		my $thing = $_[0];
		if ( blessed( $thing ) and $thing->isa( "Type::Coercion" ) ) {
			$self->add_type_coercions( @{ $thing->type_coercion_map } );
		}
		elsif ( Types::TypeTiny::is_CodeLike( $thing ) ) {
			require Types::Standard;
			$self->add_type_coercions( Types::Standard::Any(), $thing );
		}
	} #/ if ( @_ )
	$self->compiled_coercion;
} #/ sub _compiled_type_coercion

*compile_type_coercion = \&compiled_coercion;
sub meta { _croak( "Not really a Moose::Meta::TypeCoercion. Sorry!" ) }

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Type::Coercion - a set of coercions to a particular target type constraint

=head1 STATUS

This module is covered by the
L<Type-Tiny stability policy|Type::Tiny::Manual::Policies/"STABILITY">.

=head1 DESCRIPTION

=head2 Constructors

=over

=item C<< new(%attributes) >>

Moose-style constructor function.

=item C<< add($c1, $c2) >>

Create a Type::Coercion from two existing Type::Coercion objects.

=back

=head2 Attributes

Attributes are named values that may be passed to the constructor. For
each attribute, there is a corresponding reader method. For example:

   my $c = Type::Coercion->new( type_constraint => Int );
   my $t = $c->type_constraint;  # Int

=head3 Important attributes

These are the attributes you are likely to be most interested in
providing when creating your own type coercions, and most interested
in reading when dealing with coercion objects.

=over

=item C<type_constraint>

Weak reference to the target type constraint (i.e. the type constraint which
the output of coercion coderefs is expected to conform to).

=item C<type_coercion_map>

Arrayref of source-type/code pairs.

=item C<frozen>

Boolean; default false. A frozen coercion cannot have C<add_type_coercions>
called upon it.

=item C<name>

A name for the coercion. These need to conform to certain naming
rules (they must begin with an uppercase letter and continue using only
letters, digits 0-9 and underscores).

Optional; if not supplied will be an anonymous coercion.

=item C<display_name>

A name to display for the coercion when stringified. These don't have
to conform to any naming rules. Optional; a default name will be
calculated from the C<name>.

=item C<library>

The package name of the type library this coercion is associated with.
Optional. Informational only: setting this attribute does not install
the coercion into the package.

=back

=head3 Attributes related to parameterizable and parameterized coercions

The following attributes are used for parameterized coercions, but are not
fully documented because they may change in the near future:

=over

=item C<< coercion_generator >>

=item C<< parameters >>

=item C<< parameterized_from >>

=back

=head3 Lazy generated attributes

The following attributes should not be usually passed to the constructor;
unless you're doing something especially unusual, you should rely on the
default lazily-built return values.

=over

=item C<< compiled_coercion >>

Coderef to coerce a value (C<< $_[0] >>).

The general point of this attribute is that you should not set it, but
rely on the lazily-built default. Type::Coerce will usually generate a
pretty fast coderef, inlining all type constraint checks, etc.

=item C<moose_coercion>

A L<Moose::Meta::TypeCoercion> object equivalent to this one. Don't set this
manually; rely on the default built one.

=back

=head2 Methods

=head3 Predicate methods

These methods return booleans indicating information about the coercion.
They are each tightly associated with a particular attribute.
(See L</"Attributes">.)

=over

=item C<has_type_constraint>, C<has_library>

Simple Moose-style predicate methods indicating the presence or
absence of an attribute.

=item C<is_anon>

Returns true iff the coercion does not have a C<name>.

=back

The following predicates are used for parameterized coercions, but are not
fully documented because they may change in the near future:

=over

=item C<< has_coercion_generator >>

=item C<< has_parameters >>

=item C<< is_parameterizable >>

=item C<< is_parameterized >>

=back

=head3 Coercion

The following methods are used for coercing values to a type constraint:

=over

=item C<< coerce($value) >>

Coerce the value to the target type.

Returns the coerced value, or the original value if no coercion was
possible.

=item C<< assert_coerce($value) >>

Coerce the value to the target type, and throw an exception if the result
does not validate against the target type constraint.

Returns the coerced value.

=back

=head3 Coercion code definition methods

These methods all return C<< $self >> so are suitable for chaining.

=over

=item C<< add_type_coercions($type1, $code1, ...) >>

Takes one or more pairs of L<Type::Tiny> constraints and coercion code,
creating an ordered list of source types and coercion codes.

Coercion codes can be expressed as either a string of Perl code (this
includes objects which overload stringification), or a coderef (or object
that overloads coderefification). In either case, the value to be coerced
is C<< $_ >>.

C<< add_type_coercions($coercion_object) >> also works, and can be used
to copy coercions from another type constraint:

   $type->coercion->add_type_coercions($othertype->coercion)->freeze;

=item C<< freeze >>

Sets the C<frozen> attribute to true. Called automatically by L<Type::Tiny>
sometimes.

=item C<< i_really_want_to_unfreeze >>

If you really want to unfreeze a coercion, call this method.

Don't call this method. It will potentially lead to subtle bugs.

This method is considered unstable; future versions of Type::Tiny may
alter its behaviour (e.g. to throw an exception if it has been detected
that unfreezing this particular coercion will cause bugs).

=back

=head3 Parameterization

The following method is used for parameterized coercions, but is not
fully documented because it may change in the near future:

=over

=item C<< parameterize(@params) >>

=back

=head3 Type coercion introspection methods

These methods allow you to determine a coercion's relationship to type
constraints:

=over

=item C<< has_coercion_for_type($source_type) >>

Returns true iff this coercion has a coercion from the source type.

Returns the special string C<< "0 but true" >> if no coercion should
actually be necessary for this type. (For example, if a coercion coerces
to a theoretical "Number" type, there is probably no coercion necessary
for values that already conform to the "Integer" type.)

=item C<< has_coercion_for_value($value) >>

Returns true iff the value could be coerced by this coercion.

Returns the special string C<< "0 but true" >> if no coercion would be
actually be necessary for this value (due to it already meeting the target
type constraint).

=back

The C<type_constraint> attribute provides a type constraint object for the
target type constraint of the coercion. See L</"Attributes">.

=head3 Inlining methods

=for stopwords uated

The following methods are used to generate strings of Perl code which
may be pasted into stringy C<eval>uated subs to perform type coercions:

=over

=item C<< can_be_inlined >>

Returns true iff the coercion can be inlined.

=item C<< inline_coercion($varname) >>

Much like C<inline_coerce> from L<Type::Tiny>.

=back

=head3 Other methods

=over

=item C<< qualified_name >>

For non-anonymous coercions that have a library, returns a qualified
C<< "MyLib::MyCoercion" >> sort of name. Otherwise, returns the same
as C<name>.

=item C<< isa($class) >>, C<< can($method) >>, C<< AUTOLOAD(@args) >>

If Moose is loaded, then the combination of these methods is used to mock
a Moose::Meta::TypeCoercion.

=back

The following methods exist for Moose/Mouse compatibility, but do not do
anything useful.

=over

=item C<< compile_type_coercion >>

=item C<< meta >>

=back

=head2 Overloading

=over

=item *

Boolification is overloaded to always return true.

=item *

Coderefification is overloaded to call C<coerce>.

=item *

On Perl 5.10.1 and above, smart match is overloaded to call C<has_coercion_for_value>.

=back

Previous versions of Type::Coercion would overload the C<< + >> operator
to call C<add>. Support for this was dropped after 0.040.

=head1 DIAGNOSTICS

=over

=item I<< Attempt to add coercion code to a Type::Coercion which has been frozen >>

Type::Tiny type constraints are designed as immutable objects. Once you've
created a constraint, rather than modifying it you generally create child
constraints to do what you need.

Type::Coercion objects, on the other hand, are mutable. Coercion routines
can be added at any time during the object's lifetime.

Sometimes Type::Tiny needs to freeze a Type::Coercion object to prevent this.
In L<Moose> and L<Mouse> code this is likely to happen as soon as you use a
type constraint in an attribute.

Workarounds:

=over

=item *

Define as many of your coercions as possible within type libraries, not
within the code that uses the type libraries. The type library will be
evaluated relatively early, likely before there is any reason to freeze
a coercion.

=item *

If you do need to add coercions to a type within application code outside
the type library, instead create a subtype and add coercions to that. The
C<plus_coercions> method provided by L<Type::Tiny> should make this simple.

=back

=back

=head1 BUGS

Please report any bugs to
L<https://github.com/tobyink/p5-type-tiny/issues>.

=head1 SEE ALSO

L<Type::Tiny::Manual>.

L<Type::Tiny>, L<Type::Library>, L<Type::Utils>, L<Types::Standard>.

L<Type::Coercion::Union>.

L<Moose::Meta::TypeCoercion>.

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
