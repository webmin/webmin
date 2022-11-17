package Type::Utils;

use 5.008001;
use strict;
use warnings;

BEGIN {
	$Type::Utils::AUTHORITY = 'cpan:TOBYINK';
	$Type::Utils::VERSION   = '2.000001';
}

$Type::Utils::VERSION =~ tr/_//d;

sub _croak ($;@) { require Error::TypeTiny; goto \&Error::TypeTiny::croak }

use Scalar::Util qw< blessed >;
use Type::Library;
use Type::Tiny;
use Types::TypeTiny qw< TypeTiny is_TypeTiny to_TypeTiny HashLike StringLike >;

our @EXPORT = qw<
	declare as where message inline_as
	class_type role_type duck_type union intersection enum
	coerce from via
	declare_coercion to_type
>;
our @EXPORT_OK = (
	@EXPORT,
	qw<
		extends type subtype
		match_on_type compile_match_on_type
		dwim_type english_list
		classifier assert
		>,
	"is",
);
our %EXPORT_TAGS = (
	default => [@EXPORT],
	all     => [@EXPORT_OK],
);
pop @{ $EXPORT_TAGS{all} };    # remove 'is'

require Exporter::Tiny;
our @ISA = 'Exporter::Tiny';

sub extends {
	_croak "Not a type library" unless caller->isa( "Type::Library" );
	my $caller = caller->meta;
	
	foreach my $lib ( @_ ) {
		eval "use $lib; 1" or _croak "Could not load library '$lib': $@";
		
		if ( $lib->isa( "Type::Library" ) or $lib eq 'Types::TypeTiny' ) {
			$caller->add_type( $lib->get_type( $_ ) ) for sort $lib->meta->type_names;
			$caller->add_coercion( $lib->get_coercion( $_ ) )
				for sort $lib->meta->coercion_names;
		}
		elsif ( $lib->isa( 'MooseX::Types::Base' ) ) {
			require Moose::Util::TypeConstraints;
			my $types = $lib->type_storage;
			for my $name ( sort keys %$types ) {
				my $moose =
					Moose::Util::TypeConstraints::find_type_constraint( $types->{$name} );
				my $tt = Types::TypeTiny::to_TypeTiny( $moose );
				my $c  = $moose->has_coercion && @{ $moose->coercion->type_coercion_map || [] };
				$caller->add_type(
					$tt->create_child_type(
						library => $caller, name => $name, coercion => $c ? 1 : 0
					)
				);
			} #/ for my $name ( sort keys...)
		} #/ elsif ( $lib->isa( 'MooseX::Types::Base'...))
		elsif ( $lib->isa( 'MouseX::Types::Base' ) ) {
			require Mouse::Util::TypeConstraints;
			my $types = $lib->type_storage;
			for my $name ( sort keys %$types ) {
				my $mouse =
					Mouse::Util::TypeConstraints::find_type_constraint( $types->{$name} );
				my $tt = Types::TypeTiny::to_TypeTiny( $mouse );
				$caller->add_type(
					$tt->create_child_type(
						library => $caller, name => $name, coercion => $mouse->has_coercion ? 1 : 0
					)
				);
			} #/ for my $name ( sort keys...)
		} #/ elsif ( $lib->isa( 'MouseX::Types::Base'...))
		elsif ( $lib->isa( 'Specio::Exporter' ) ) {
			my $types = $lib->Specio::Registry::exportable_types_for_package;
			for my $name ( sort keys %$types ) {
				my $specio = $types->{$name};
				my $tt     = Types::TypeTiny::to_TypeTiny( $specio );
				$caller->add_type(
					$tt->create_child_type( library => $caller, name => $name )
				);
			}
		}
		elsif ( $lib->isa( 'Exporter' )
		and my $types = do { no strict 'refs'; ${"$lib\::EXPORT_TAGS"}{'types'} } ) {
			for my $name ( @$types ) {
				my $obj = $lib->$name;
				my $tt  = Types::TypeTiny::to_TypeTiny( $obj );
				$caller->add_type(
					$tt->create_child_type( library => $caller, name => $name )
				);
			}
		}
		else {
			_croak( "'$lib' is not a type constraint library" );
		}
	} #/ foreach my $lib ( @_ )
} #/ sub extends

sub declare {
	my %opts;
	if ( @_ % 2 == 0 ) {
		%opts = @_;
		if ( @_ == 2 and $_[0] =~ /^_*[A-Z]/ and $_[1] =~ /^[0-9]+$/ ) {
			require Carp;
			Carp::carp( "Possible missing comma after 'declare $_[0]'" );
		}
	}
	else {
		( my ( $name ), %opts ) = @_;
		_croak "Cannot provide two names for type" if exists $opts{name};
		$opts{name} = $name;
	}
	
	my $caller = caller( $opts{_caller_level} || 0 );
	$opts{library} = $caller;
	
	if ( defined $opts{parent} ) {
		$opts{parent} = to_TypeTiny( $opts{parent} );
		
		unless ( is_TypeTiny( $opts{parent} ) ) {
			$caller->isa( "Type::Library" )
				or _croak(
				"Parent type cannot be a %s",
				ref( $opts{parent} ) || 'non-reference scalar'
				);
			$opts{parent} = $caller->meta->get_type( $opts{parent} )
				or _croak( "Could not find parent type" );
		}
	} #/ if ( defined $opts{parent...})
	
	my $type;
	if ( defined $opts{parent} ) {
		$type = delete( $opts{parent} )->create_child_type( %opts );
	}
	else {
		my $bless = delete( $opts{bless} ) || "Type::Tiny";
		eval "require $bless";
		$type = $bless->new( %opts );
	}
	
	if ( not $type->is_anon ) {
		
		$caller->meta->add_type( $type )
			if $caller->isa( 'Type::Library' );
		
		$INC{'Type/Registry.pm'}
			? 'Type::Registry'->for_class( $caller )->add_type( $type, $opts{name} )
			: ( $Type::Registry::DELAYED{$caller}{$opts{name}} = $type );
	}
	
	return $type;
} #/ sub declare

*subtype = \&declare;
*type    = \&declare;

sub as (@) {
	parent => @_;
}

sub where (&;@) {
	constraint => @_;
}

sub message (&;@) {
	message => @_;
}

sub inline_as (&;@) {
	inlined => @_;
}

sub class_type {
	my $name = ref( $_[0] ) eq 'HASH' ? undef : shift;
	my %opts = %{ shift or {} };
	
	if ( defined $name ) {
		$opts{name}  = $name unless exists $opts{name};
		$opts{class} = $name unless exists $opts{class};
		
		$opts{name} =~ s/:://g;
	}
	
	$opts{bless} = "Type::Tiny::Class";
	
	{ no warnings "numeric"; $opts{_caller_level}++ }
	declare( %opts );
} #/ sub class_type

sub role_type {
	my $name = ref( $_[0] ) eq 'HASH' ? undef : shift;
	my %opts = %{ shift or {} };
	
	if ( defined $name ) {
		$opts{name} = $name unless exists $opts{name};
		$opts{role} = $name unless exists $opts{role};
		
		$opts{name} =~ s/:://g;
	}
	
	$opts{bless} = "Type::Tiny::Role";
	
	{ no warnings "numeric"; $opts{_caller_level}++ }
	declare( %opts );
} #/ sub role_type

sub duck_type {
	my $name    = ref( $_[0] ) eq 'ARRAY' ? undef : shift;
	my @methods = @{ shift or [] };
	
	my %opts;
	$opts{name}    = $name if defined $name;
	$opts{methods} = \@methods;
	
	$opts{bless} = "Type::Tiny::Duck";
	
	{ no warnings "numeric"; $opts{_caller_level}++ }
	declare( %opts );
} #/ sub duck_type

sub enum {
	my $name   = ref( $_[0] ) eq 'ARRAY' ? undef : shift;
	my @values = @{ shift or [] };
	
	my %opts;
	$opts{name}   = $name if defined $name;
	$opts{values} = \@values;
	
	$opts{bless} = "Type::Tiny::Enum";
	
	{ no warnings "numeric"; $opts{_caller_level}++ }
	declare( %opts );
} #/ sub enum

sub union {
	my $name = ref( $_[0] ) eq 'ARRAY' ? undef : shift;
	my @tcs  = @{ shift or [] };
	
	my %opts;
	$opts{name}             = $name if defined $name;
	$opts{type_constraints} = \@tcs;
	
	$opts{bless} = "Type::Tiny::Union";
	
	{ no warnings "numeric"; $opts{_caller_level}++ }
	declare( %opts );
} #/ sub union

sub intersection {
	my $name = ref( $_[0] ) eq 'ARRAY' ? undef : shift;
	my @tcs  = @{ shift or [] };
	
	my %opts;
	$opts{name}             = $name if defined $name;
	$opts{type_constraints} = \@tcs;
	
	$opts{bless} = "Type::Tiny::Intersection";
	
	{ no warnings "numeric"; $opts{_caller_level}++ }
	declare( %opts );
} #/ sub intersection

sub declare_coercion {
	my %opts;
	$opts{name} = shift if !ref( $_[0] );
	
	# I don't like this; it is a hack
	if ( ref( $_[0] ) eq 'Type::Tiny::_DeclaredType' ) {
		$opts{name} = '' . shift;
	}
	
	while ( Types::TypeTiny::is_HashLike( $_[0] ) and not is_TypeTiny( $_[0] ) ) {
		%opts = ( %opts, %{ +shift } );
	}
	
	my $caller = caller( $opts{_caller_level} || 0 );
	$opts{library} = $caller;
	
	my $bless = delete( $opts{bless} ) || "Type::Coercion";
	eval "require $bless";
	my $c = $bless->new( %opts );
	
	my @C;
	
	if ( $caller->isa( "Type::Library" ) ) {
		my $meta = $caller->meta;
		$meta->add_coercion( $c ) unless $c->is_anon;
		while ( @_ ) {
			push @C,
				map { ref( $_ ) ? to_TypeTiny( $_ ) : $meta->get_type( $_ ) || $_ } shift;
			push @C, shift;
		}
	}
	else {
		@C = @_;
	}
	
	$c->add_type_coercions( @C );
	
	return $c->freeze;
} #/ sub declare_coercion

sub coerce {
	if ( ( scalar caller )->isa( "Type::Library" ) ) {
		my $meta = ( scalar caller )->meta;
		my ( $type ) =
			map { ref( $_ ) ? to_TypeTiny( $_ ) : $meta->get_type( $_ ) || $_ } shift;
		my @opts;
		while ( @_ ) {
			push @opts,
				map { ref( $_ ) ? to_TypeTiny( $_ ) : $meta->get_type( $_ ) || $_ } shift;
			push @opts, shift;
		}
		return $type->coercion->add_type_coercions( @opts );
	} #/ if ( ( scalar caller )...)
	
	my ( $type, @opts ) = @_;
	$type = to_TypeTiny( $type );
	return $type->coercion->add_type_coercions( @opts );
} #/ sub coerce

sub from (@) {
	return @_;
}

sub to_type (@) {
	my $type = shift;
	unless ( is_TypeTiny( $type ) ) {
		caller->isa( "Type::Library" )
			or _croak "Target type cannot be a string";
		$type = caller->meta->get_type( $type )
			or _croak "Could not find target type";
	}
	return +{ type_constraint => $type }, @_;
} #/ sub to_type (@)

sub via (&;@) {
	return @_;
}

sub match_on_type {
	my $value = shift;
	
	while ( @_ ) {
		my $code;
		if ( @_ == 1 ) {
			$code = shift;
		}
		else {
			( my ( $type ), $code ) = splice( @_, 0, 2 );
			Types::TypeTiny::assert_TypeTiny( $type )->check( $value ) or next;
		}
		
		if ( Types::TypeTiny::is_StringLike( $code ) ) {
			local $_ = $value;
			if ( wantarray ) {
				my @r = eval "$code";
				die $@ if $@;
				return @r;
			}
			if ( defined wantarray ) {
				my $r = eval "$code";
				die $@ if $@;
				return $r;
			}
			eval "$code";
			die $@ if $@;
			return;
		} #/ if ( Types::TypeTiny::is_StringLike...)
		else {
			Types::TypeTiny::assert_CodeLike( $code );
			local $_ = $value;
			return $code->( $value );
		}
	} #/ while ( @_ )
	
	_croak( "No cases matched for %s", Type::Tiny::_dd( $value ) );
} #/ sub match_on_type

sub compile_match_on_type {
	require Eval::TypeTiny::CodeAccumulator;
	my $coderef = 'Eval::TypeTiny::CodeAccumulator'->new(
		description => 'compiled match',
	);
	$coderef->add_line( 'sub {' );
	$coderef->increase_indent;
	$coderef->add_line( 'local $_ = $_[0];' );
	
	my $els = '';
	
	while ( @_ ) {
		my ( $type, $code );
		if ( @_ == 1 ) {
			require Types::Standard;
			( $type, $code ) = ( Types::Standard::Any(), shift );
		}
		else {
			( $type, $code ) = splice( @_, 0, 2 );
			Types::TypeTiny::assert_TypeTiny( $type );
		}
		
		if ( $type->can_be_inlined ) {
			$coderef->add_line( sprintf(
				'%sif ( %s ) {',
				$els,
				$type->inline_check( '$_' ),
			) );
		}
		else {
			my $varname = $coderef->add_variable( '$type', \$type );
			$coderef->add_line( sprintf(
				'%sif ( %s->check($_) ) {',
				$els,
				$varname,
			) );
		}
		$coderef->increase_indent;
		
		$els = 'els';
		
		if ( Types::TypeTiny::is_StringLike( $code ) ) {
			$coderef->add_line( $code );
		}
		else {
			Types::TypeTiny::assert_CodeLike( $code );
			my $varname = $coderef->add_variable( '$action', \$code );
			$coderef->add_line( sprintf(
				'%s->( @_ )',
				$varname,
			) );
		}
		$coderef->decrease_indent;
		$coderef->add_line( '}' );
	} #/ while ( @_ )
	
	$coderef->add_line( 'else {' );
	$coderef->increase_indent;
	$coderef->add_line( 'Type::Utils::_croak( "No cases matched for %s", Type::Tiny::_dd( $_ ) );' );
	$coderef->decrease_indent;
	$coderef->add_line( '}' );
	
	$coderef->decrease_indent;
	$coderef->add_line( '}' );
	
	return $coderef->compile;
} #/ sub compile_match_on_type

sub classifier {
	my $i;
	compile_match_on_type(
		+(
			map {
				my $type = $_->[0];
				$type => sub { $type };
				}
				sort { $b->[1] <=> $a->[1] or $a->[2] <=> $b->[2] }
				map [ $_, scalar( my @parents = $_->parents ), ++$i ],
			@_
		),
		q[ undef ],
	);
} #/ sub classifier

{
	package    #hide
		Type::Registry::DWIM;
		
	our @ISA = qw(Type::Registry);
	
	sub foreign_lookup {
		my $self = shift;
		my $r    = $self->SUPER::foreign_lookup( @_ );
		return $r if $r;
		
		if ( my $assume = $self->{"~~assume"}
			and $_[0] =~ /[A-Z_a-z][0-9A-Z_a-z]*(?:::[0-9A-Z_a-z]+)*/ )
		{
			my @methods = ref( $assume ) ? @$assume : $assume;
			
			for my $method ( @methods ) {
				$r = $self->$method( @_ );
				return $r if $r;
			}
		} #/ if ( my $assume = $self...)
		
		return;
	} #/ sub foreign_lookup
	
	sub lookup_via_moose {
		my $self = shift;
		
		if ( $INC{'Moose.pm'} ) {
			require Moose::Util::TypeConstraints;
			require Types::TypeTiny;
			my $r = Moose::Util::TypeConstraints::find_type_constraint( $_[0] );
			return Types::TypeTiny::to_TypeTiny( $r ) if defined $r;
		}
		
		return;
	} #/ sub lookup_via_moose
	
	sub lookup_via_mouse {
		my $self = shift;
		
		if ( $INC{'Mouse.pm'} ) {
			require Mouse::Util::TypeConstraints;
			require Types::TypeTiny;
			my $r = Mouse::Util::TypeConstraints::find_type_constraint( $_[0] );
			return Types::TypeTiny::to_TypeTiny( $r ) if defined $r;
		}
		
		return;
	} #/ sub lookup_via_mouse
	
	sub simple_lookup {
		my $self = shift;
		my $r;
		
		# If the lookup is chained to a class, then the class' own
		# type registry gets first refusal.
		#
		if ( defined $self->{"~~chained"} ) {
			my $chained = "Type::Registry"->for_class( $self->{"~~chained"} );
			$r = eval { $chained->simple_lookup( @_ ) } unless $self == $chained;
			return $r if defined $r;
		}
		
		# Fall back to types in Types::Standard.
		require Types::Standard;
		return 'Types::Standard'->get_type( $_[0] )
			if 'Types::Standard'->has_type( $_[0] );
			
		# Only continue any further if we've been called from Type::Parser.
		return unless $_[1];
		
		my $meta;
		if ( defined $self->{"~~chained"} ) {
			$meta ||= Moose::Util::find_meta( $self->{"~~chained"} ) if $INC{'Moose.pm'};
			$meta ||= Mouse::Util::find_meta( $self->{"~~chained"} ) if $INC{'Mouse.pm'};
		}
		
		if ( $meta and $meta->isa( 'Class::MOP::Module' ) ) {
			$r = $self->lookup_via_moose( @_ );
			return $r if $r;
		}
		
		elsif ( $meta and $meta->isa( 'Mouse::Meta::Module' ) ) {
			$r = $self->lookup_via_mouse( @_ );
			return $r if $r;
		}
		
		return $self->foreign_lookup( @_ );
	} #/ sub simple_lookup
}

our $dwimmer;

sub dwim_type {
	my ( $string, %opts ) = @_;
	$opts{for} = caller unless defined $opts{for};
	
	$dwimmer ||= do {
		require Type::Registry;
		'Type::Registry::DWIM'->new;
	};
	
	local $dwimmer->{'~~chained'} = $opts{for};
	local $dwimmer->{'~~assume'}  = $opts{fallback} || [
		qw/ lookup_via_moose lookup_via_mouse /,
		$opts{does} ? 'make_role_type' : 'make_class_type',
	];
	
	local $@ = undef;
	my $type;
	unless ( eval { $type = $dwimmer->lookup( $string ); 1 } ) {
		my $e = $@;
		die( $e ) unless $e =~ /not a known type constraint/;
	}
	
	$type;
} #/ sub dwim_type

my $TEMPLATE = <<'SUBTEMPLATE';
sub SUBNAME
{
	require Types::TypeTiny;
	no warnings 'uninitialized';
	
	my ($type, $value) = @_;
	my $caller = caller;
	
	my $uniq = Types::TypeTiny::is_TypeTiny($type) ? $type->{uniq} : "$type";
	
	if (not Types::TypeTiny::is_TypeTiny $type) {
		my $orig = $type;
		
		$type = $is_cache{$caller}{$uniq} || do {
			Types::TypeTiny::is_StringLike($type)
				? eval { dwim_type("$type", for => $caller) }
				: undef;
		};
		
		if (blessed $type) {
			$is_cache{$caller}{$uniq} ||= $type;
		}
		else {
			my $thing = Type::Tiny::_dd($orig);
			substr($thing, 0, 1) = lc substr($thing, 0, 1);
			require Carp;
			FAILURE
		}
	}
	
	my $check = ( $is_cache_coderef{$caller}{$uniq} ||= $type->compiled_check );
	
	BODY
}
SUBTEMPLATE

my %is_cache;
my %is_cache_coderef;

{
	my $code = $TEMPLATE;
	$code =~ s/SUBNAME/is/g;
	$code =~
		s/FAILURE/Carp::carp("Expected type, but got \$thing; returning false"); return undef;/g;
	$code =~ s/BODY/0+!! \$check->(\$value)/;
	eval $code;
}

{
	my $code = $TEMPLATE;
	$code =~ s/SUBNAME/assert/g;
	$code =~
		s/FAILURE/Carp::croak("Expected type, but got \$thing; stopping"); return undef;/g;
	$code =~
		s/BODY/\$check->(\$value) ? \$value : \$type->_failed_check("\$type", \$value)/;
	eval $code;
}

sub english_list {
	my $conjunction = ref( $_[0] ) eq 'SCALAR' ? ${ +shift } : 'and';
	my @items       = sort @_;
	
	return $items[0]                          if @items == 1;
	return "$items[0] $conjunction $items[1]" if @items == 2;
	
	my $tail = pop @items;
	join( ', ', @items, "$conjunction $tail" );
} #/ sub english_list

1;

__END__

=pod

=encoding utf-8

=for stopwords smush smushed

=head1 NAME

Type::Utils - utility functions to make defining and using type constraints a little easier

=head1 SYNOPSIS

   package Types::Mine;
   
   use Type::Library -base;
   use Type::Utils -all;
   
   BEGIN { extends "Types::Standard" };
   
   declare "AllCaps",
      as "Str",
      where { uc($_) eq $_ },
      inline_as { my $varname = $_[1]; "uc($varname) eq $varname" };
   
   coerce "AllCaps",
      from "Str", via { uc($_) };

=head1 STATUS

This module is covered by the
L<Type-Tiny stability policy|Type::Tiny::Manual::Policies/"STABILITY">.

=head1 DESCRIPTION

This module provides utility functions to make defining and using type
constraints a little easier. 

=head2 Type declaration functions

Many of the following are similar to the similarly named functions described
in L<Moose::Util::TypeConstraints>.

=over

=item C<< declare $name, %options >>

=item C<< declare %options >>

Declare a named or anonymous type constraint. Use C<as> and C<where> to
specify the parent type (if any) and (possibly) refine its definition.

   declare EvenInt, as Int, where { $_ % 2 == 0 };

   my $EvenInt = declare as Int, where { $_ % 2 == 0 };

I<< NOTE: >>
Named types will be automatically added to the caller's type registry.
(See L<Type::Registry>.) If the caller package inherits from L<Type::Library>
named types will also be automatically installed into the library and
made available as exports.

Hidden gem: if you're inheriting from a type constraint that includes some
coercions, you can include C<< coercion => 1 >> in the C<< %options >> hash
to inherit the coercions.

=item C<< subtype $name, %options >>

=item C<< subtype %options >>

Declare a named or anonymous type constraint which is descended from an
existing type constraint. Use C<as> and C<where> to specify the parent
type and refine its definition.

Actually, you should use C<declare> instead; this is just an alias.

This function is not exported by default.

=item C<< type $name, %options >>

=item C<< type %options >>

Declare a named or anonymous type constraint which is not descended from
an existing type constraint. Use C<where> to provide a coderef that
constrains values.

Actually, you should use C<declare> instead; this is just an alias.

This function is not exported by default.

=item C<< as $parent >>

Used with C<declare> to specify a parent type constraint:

   declare EvenInt, as Int, where { $_ % 2 == 0 };

=item C<< where { BLOCK } >>

Used with C<declare> to provide the constraint coderef:

   declare EvenInt, as Int, where { $_ % 2 == 0 };

The coderef operates on C<< $_ >>, which is the value being tested.

=item C<< message { BLOCK } >>

Generate a custom error message when a value fails validation.

   declare EvenInt,
      as Int,
      where { $_ % 2 == 0 },
      message {
         Int->validate($_) or "$_ is not divisible by two";
      };

Without a custom message, the messages generated by Type::Tiny are along
the lines of I<< Value "33" did not pass type constraint "EvenInt" >>,
which is usually reasonable.

=item C<< inline_as { BLOCK } >>

Generate a string of Perl code that can be used to inline the type check into
other functions. If your type check is being used within a L<Moose> or L<Moo>
constructor or accessor methods, or used by L<Type::Params>, this can lead to
significant performance improvements.

   declare EvenInt,
      as Int,
      where { $_ % 2 == 0 },
      inline_as {
         my ($constraint, $varname) = @_;
         my $perlcode = 
            $constraint->parent->inline_check($varname)
            . "&& ($varname % 2 == 0)";
         return $perlcode;
      };
   
   warn EvenInt->inline_check('$xxx');  # demonstration

Your C<inline_as> block can return a list, in which case
these will be smushed together with "&&". The first item on the list may
be undef, in which case the undef will be replaced by the inlined parent
type constraint. (And will throw an exception if there is no parent.)

   declare EvenInt,
      as Int,
      where { $_ % 2 == 0 },
      inline_as {
         return (undef, "($_ % 2 == 0)");
      };

=item C<< class_type $name, { class => $package, %options } >>

=item C<< class_type { class => $package, %options } >>

=item C<< class_type $name >>

Shortcut for declaring a L<Type::Tiny::Class> type constraint.

If C<< $package >> is omitted, is assumed to be the same as C<< $name >>.
If C<< $name >> contains "::" (which would be an invalid name as far as
L<Type::Tiny> is concerned), this will be removed.

So for example, C<< class_type("Foo::Bar") >> declares a L<Type::Tiny::Class>
type constraint named "FooBar" which constrains values to objects blessed
into the "Foo::Bar" package.

=item C<< role_type $name, { role => $package, %options } >>

=item C<< role_type { role => $package, %options } >>

=item C<< role_type $name >>

Shortcut for declaring a L<Type::Tiny::Role> type constraint.

If C<< $package >> is omitted, is assumed to be the same as C<< $name >>.
If C<< $name >> contains "::" (which would be an invalid name as far as
L<Type::Tiny> is concerned), this will be removed.

=item C<< duck_type $name, \@methods >>

=item C<< duck_type \@methods >>

Shortcut for declaring a L<Type::Tiny::Duck> type constraint.

=item C<< union $name, \@constraints >>

=item C<< union \@constraints >>

Shortcut for declaring a L<Type::Tiny::Union> type constraint.

=item C<< enum $name, \@values >>

=item C<< enum \@values >>

Shortcut for declaring a L<Type::Tiny::Enum> type constraint.

=item C<< intersection $name, \@constraints >>

=item C<< intersection \@constraints >>

Shortcut for declaring a L<Type::Tiny::Intersection> type constraint.

=back

=head2 Coercion declaration functions

Many of the following are similar to the similarly named functions described
in L<Moose::Util::TypeConstraints>.

=over

=item C<< coerce $target, @coercions >>

Add coercions to the target type constraint. The list of coercions is a
list of type constraint, conversion code pairs. Conversion code can be
either a string of Perl code or a coderef; in either case the value to
be converted is C<< $_ >>.

=item C<< from $source >>

Sugar to specify a type constraint in a list of coercions:

   coerce EvenInt, from Int, via { $_ * 2 };  # As a coderef...
   coerce EvenInt, from Int, q { $_ * 2 };    # or as a string!

=item C<< via { BLOCK } >>

Sugar to specify a coderef in a list of coercions.

=item C<< declare_coercion $name, \%opts, $type1, $code1, ... >>

=item C<< declare_coercion \%opts, $type1, $code1, ... >>

Declares a coercion that is not explicitly attached to any type in the
library. For example:

   declare_coercion "ArrayRefFromAny", from "Any", via { [$_] };

This coercion will be exportable from the library as a L<Type::Coercion>
object, but the ArrayRef type exported by the library won't automatically
use it.

Coercions declared this way are immutable (frozen).

=item C<< to_type $type >>

Used with C<declare_coercion> to declare the target type constraint for
a coercion, but still without explicitly attaching the coercion to the
type constraint:

   declare_coercion "ArrayRefFromAny",
      to_type "ArrayRef",
      from "Any", via { [$_] };

You should pretty much always use this when declaring an unattached
coercion because it's exceedingly useful for a type coercion to know what
it will coerce to - this allows it to skip coercion when no coercion is
needed (e.g. avoiding coercing C<< [] >> to C<< [ [] ] >>) and allows
C<assert_coerce> to work properly.

=back

=head2 Type library management

=over

=item C<< extends @libraries >>

Indicates that this type library extends other type libraries, importing
their type constraints.

Should usually be executed in a C<< BEGIN >> block.

This is not exported by default because it's not fun to export it to Moo,
Moose or Mouse classes! C<< use Type::Utils -all >> can be used to import
it into your type library.

=back

=head2 Other

=over

=item C<< match_on_type $value => ($type => \&action, ..., \&default?) >>

Something like a C<switch>/C<case> or C<given>/C<when> construct. Dispatches
along different code paths depending on the type of the incoming value.
Example blatantly stolen from the Moose documentation:

   sub to_json
   {
      my $value = shift;
      
      return match_on_type $value => (
         HashRef() => sub {
            my $hash = shift;
            '{ '
               . (
               join ", " =>
               map { '"' . $_ . '" : ' . to_json( $hash->{$_} ) }
               sort keys %$hash
            ) . ' }';
         },
         ArrayRef() => sub {
            my $array = shift;
            '[ '.( join ", " => map { to_json($_) } @$array ).' ]';
         },
         Num()   => q {$_},
         Str()   => q { '"' . $_ . '"' },
         Undef() => q {'null'},
         => sub { die "$_ is not acceptable json type" },
      );
   }

Note that unlike Moose, code can be specified as a string instead of a
coderef. (e.g. for C<Num>, C<Str> and C<Undef> above.)

For improved performance, try C<compile_match_on_type>.

This function is not exported by default.

=item C<< my $coderef = compile_match_on_type($type => \&action, ..., \&default?) >>

Compile a C<match_on_type> block into a coderef. The following JSON
converter is about two orders of magnitude faster than the previous
example:

   sub to_json;
   *to_json = compile_match_on_type(
      HashRef() => sub {
         my $hash = shift;
         '{ '
            . (
            join ", " =>
            map { '"' . $_ . '" : ' . to_json( $hash->{$_} ) }
            sort keys %$hash
         ) . ' }';
      },
      ArrayRef() => sub {
         my $array = shift;
         '[ '.( join ", " => map { to_json($_) } @$array ).' ]';
      },
      Num()   => q {$_},
      Str()   => q { '"' . $_ . '"' },
      Undef() => q {'null'},
      => sub { die "$_ is not acceptable json type" },
   );

Remember to store the coderef somewhere fairly permanent so that you
don't compile it over and over. C<state> variables (in Perl >= 5.10)
are good for this. (Same sort of idea as L<Type::Params>.)

This function is not exported by default.

=item C<< my $coderef = classifier(@types) >>

Returns a coderef that can be used to classify values according to their
type constraint. The coderef, when passed a value, returns a type
constraint which the value satisfies.

   use feature qw( say );
   use Type::Utils qw( classifier );
   use Types::Standard qw( Int Num Str Any );
   
   my $classifier = classifier(Str, Int, Num, Any);
   
   say $classifier->( "42"  )->name;   # Int
   say $classifier->( "4.2" )->name;   # Num
   say $classifier->( []    )->name;   # Any

Note that, for example, "42" satisfies Int, but it would satisfy the
type constraints Num, Str, and Any as well. In this case, the
classifier has picked the most specific type constraint that "42"
satisfies.

If no type constraint is satisfied by the value, then the classifier
will return undef.

=item C<< dwim_type($string, %options) >>

Given a string like "ArrayRef[Int|CodeRef]", turns it into a type constraint
object, hopefully doing what you mean.

It uses the syntax of L<Type::Parser>. Firstly the L<Type::Registry>
for the caller package is consulted; if that doesn't have a match,
L<Types::Standard> is consulted for standard type constraint names.

If none of the above yields a type constraint, and the caller class
is a Moose-based class, then C<dwim_type> attempts to look the type
constraint up in the Moose type registry. If it's a Mouse-based class,
then the Mouse type registry is used instead.

If no type constraint can be found via these normal methods, several
fallbacks are available:

=over

=item C<lookup_via_moose>

Lookup in Moose registry even if caller is non-Moose class.

=item C<lookup_via_mouse>

Lookup in Mouse registry even if caller is non-Mouse class.

=item C<make_class_type>

Create a new Type::Tiny::Class constraint.

=item C<make_role_type>

Create a new Type::Tiny::Role constraint.

=back

You can alter which should be attempted, and in which order, by passing
an option to C<dwim_type>:

   my $type = Type::Utils::dwim_type(
      "ArrayRef[Int]",
      fallback      => [ "lookup_via_mouse" , "make_role_type" ],
   );

For historical reasons, by default the fallbacks attempted are:

   lookup_via_moose, lookup_via_mouse, make_class_type

You may set C<fallback> to an empty arrayref to avoid using any of
these fallbacks.

You can specify an alternative for the caller using the C<for> option.

   my $type = dwim_type("ArrayRef", for => "Moose::Object");

While it's probably better overall to use the proper L<Type::Registry>
interface for resolving type constraint strings, this function often does
what you want.

It should never die if it fails to find a type constraint (but may die
if the type constraint string is syntactically malformed), preferring to
return undef.

This function is not exported by default.

=item C<< is($type, $value) >>

Shortcut for C<< $type->check($value) >> but also if $type is a string,
will look it up via C<dwim_type>.

This function is not exported by default.
This function is not even exported by C<< use Type::Utils -all >>.
You must request it explicitly.

  use Type::Utils "is";

Beware using this in test scripts because it has the same name as a function
exported by L<Test::More>. Note that you can rename this function if
C<is> will cause conflicts:

   use Type::Utils "is" => { -as => "isntnt" };

=item C<< assert($type, $value) >>

Like C<is> but instead of returning a boolean, returns C<< $value >> and
dies if the value fails the type check.

This function is not exported by default, but it is exported by
C<< use Type::Utils -all >>.

=item C<< english_list(\$conjunction, @items) >>

Joins the items with commas, placing a conjunction before the final item.
The conjunction is optional, defaulting to "and".

   english_list(qw/foo bar baz/);       # "foo, bar, and baz"
   english_list(\"or", qw/quux quuux/); # "quux or quuux"

This function is not exported by default.

=back

=head1 EXPORT

By default, all of the functions documented above are exported, except
C<subtype> and C<type> (prefer C<declare> instead), C<extends>, C<dwim_type>,
C<match_on_type>/C<compile_match_on_type>, C<classifier>, and
C<english_list>.

This module uses L<Exporter::Tiny>; see the documentation of that module
for tips and tricks importing from Type::Utils.

=head1 BUGS

Please report any bugs to
L<https://github.com/tobyink/p5-type-tiny/issues>.

=head1 SEE ALSO

L<Type::Tiny::Manual>.

L<Type::Tiny>, L<Type::Library>, L<Types::Standard>, L<Type::Coercion>.

L<Type::Tiny::Class>, L<Type::Tiny::Role>, L<Type::Tiny::Duck>,
L<Type::Tiny::Enum>, L<Type::Tiny::Union>.

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
