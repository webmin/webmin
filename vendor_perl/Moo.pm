package Moo;
use strict;
use warnings;
no warnings 'once';

use Moo::_Utils qw(
  _check_tracked
  _getglob
  _getstash
  _install_coderef
  _install_modifier
  _install_tracked
  _linear_isa
  _load_module
  _set_loaded
  _unimport_coderefs
);
use Carp qw(croak);
BEGIN {
  our @CARP_NOT = qw(
    Method::Generate::Constructor
    Method::Generate::Accessor
    Moo::sification
    Moo::_Utils
    Moo::Role
  );
}

our $VERSION = '2.005004';
$VERSION =~ tr/_//d;

require Moo::sification;
Moo::sification->import;

our %MAKERS;

sub import {
  my $target = caller;
  my $class = shift;
  if ($INC{'Role/Tiny.pm'} and Role::Tiny->is_role($target)) {
    croak "Cannot import Moo into a role";
  }

  _set_loaded(caller);

  strict->import;
  warnings->import;

  $class->_install_subs($target, @_);
  $class->make_class($target);
  return;
}

sub make_class {
  my ($me, $target) = @_;

  my $makers = $MAKERS{$target} ||= {};
  return $target if $makers->{is_class};

  my $stash = _getstash($target);
  $makers->{non_methods} = {
    map +($_ => \&{"${target}::${_}"}),
    grep exists &{"${target}::${_}"},
    grep !/::\z/ && !/\A\(/,
    keys %$stash
  };

  $makers->{is_class} = 1;
  {
    no strict 'refs';
    @{"${target}::ISA"} = do {
      require Moo::Object; ('Moo::Object');
    } unless @{"${target}::ISA"};
  }
  if ($INC{'Moo/HandleMoose.pm'} && !$Moo::sification::disabled) {
    Moo::HandleMoose::inject_fake_metaclass_for($target);
  }
  return $target;
}

sub is_class {
  my ($me, $class) = @_;
  return $MAKERS{$class} && $MAKERS{$class}{is_class};
}

sub _install_subs {
  my ($me, $target) = @_;
  my %install = $me->_gen_subs($target);
  _install_tracked $target => $_ => $install{$_}
    for sort keys %install;
  return;
}

sub _gen_subs {
  my ($me, $target) = @_;
  return (
    extends => sub {
      $me->_set_superclasses($target, @_);
      $me->_maybe_reset_handlemoose($target);
      return;
    },
    with => sub {
      require Moo::Role;
      Moo::Role->apply_roles_to_package($target, @_);
      $me->_maybe_reset_handlemoose($target);
    },
    has => sub {
      my $name_proto = shift;
      my @name_proto = ref $name_proto eq 'ARRAY' ? @$name_proto : $name_proto;
      if (@_ % 2 != 0) {
        croak "Invalid options for " . join(', ', map "'$_'", @name_proto)
          . " attribute(s): even number of arguments expected, got " . scalar @_;
      }
      my %spec = @_;
      foreach my $name (@name_proto) {
        # Note that when multiple attributes specified, each attribute
        # needs a separate \%specs hashref
        my $spec_ref = @name_proto > 1 ? +{%spec} : \%spec;
        $me->_constructor_maker_for($target)
              ->register_attribute_specs($name, $spec_ref);
        $me->_accessor_maker_for($target)
              ->generate_method($target, $name, $spec_ref);
        $me->_maybe_reset_handlemoose($target);
      }
      return;
    },
    (map {
      my $type = $_;
      (
        $type => sub {
          _install_modifier($target, $type, @_);
          return;
        },
      )
    } qw(before after around)),
  );
}

sub unimport {
  my $target = caller;
  _unimport_coderefs($target);
}

sub _set_superclasses {
  my $class = shift;
  my $target = shift;
  foreach my $superclass (@_) {
    _load_module($superclass);
    if ($INC{'Role/Tiny.pm'} && Role::Tiny->is_role($superclass)) {
      croak "Can't extend role '$superclass'";
    }
  }
  @{*{_getglob("${target}::ISA")}} = @_;
  if (my $old = delete $Moo::MAKERS{$target}{constructor}) {
    $old->assert_constructor;
    delete _getstash($target)->{new};
    Moo->_constructor_maker_for($target)
       ->register_attribute_specs(%{$old->all_attribute_specs});
  }
  elsif (!$target->isa('Moo::Object')) {
    Moo->_constructor_maker_for($target);
  }
  $Moo::HandleMoose::MOUSE{$target} = [
    grep defined, map Mouse::Util::find_meta($_), @_
  ] if Mouse::Util->can('find_meta');
}

sub _maybe_reset_handlemoose {
  my ($class, $target) = @_;
  if ($INC{'Moo/HandleMoose.pm'} && !$Moo::sification::disabled) {
    Moo::HandleMoose::maybe_reinject_fake_metaclass_for($target);
  }
}

sub _accessor_maker_for {
  my ($class, $target) = @_;
  return unless $MAKERS{$target};
  $MAKERS{$target}{accessor} ||= do {
    my $maker_class = do {
      no strict 'refs';
      if (my $m = do {
        my @isa = @{_linear_isa($target)};
        shift @isa;
        if (my ($parent_new) = grep +(defined &{$_.'::new'}), @isa) {
          $MAKERS{$parent_new} && $MAKERS{$parent_new}{accessor};
        }
        else {
          undef;
        }
      }) {
        ref($m);
      } else {
        require Method::Generate::Accessor;
        'Method::Generate::Accessor'
      }
    };
    $maker_class->new;
  }
}

sub _constructor_maker_for {
  my ($class, $target) = @_;
  return unless $MAKERS{$target};
  $MAKERS{$target}{constructor} ||= do {
    require Method::Generate::Constructor;

    my %construct_opts = (
      package => $target,
      accessor_generator => $class->_accessor_maker_for($target),
      subconstructor_handler => (
        '      if ($Moo::MAKERS{$class}) {'."\n"
        .'        if ($Moo::MAKERS{$class}{constructor}) {'."\n"
        .'          package '.$target.';'."\n"
        .'          return $invoker->SUPER::new(@_);'."\n"
        .'        }'."\n"
        .'        '.$class.'->_constructor_maker_for($class);'."\n"
        .'        return $invoker->new(@_)'.";\n"
        .'      } elsif ($INC{"Moose.pm"} and my $meta = Class::MOP::get_metaclass_by_name($class)) {'."\n"
        .'        return $meta->new_object('."\n"
        .'          $class->can("BUILDARGS") ? $class->BUILDARGS(@_)'."\n"
        .'                      : $class->Moo::Object::BUILDARGS(@_)'."\n"
        .'        );'."\n"
        .'      }'."\n"
      ),
    );

    my $con;
    my @isa = @{_linear_isa($target)};
    shift @isa;
    no strict 'refs';
    if (my ($parent_new) = grep +(defined &{$_.'::new'}), @isa) {
      if ($parent_new eq 'Moo::Object') {
        # no special constructor needed
      }
      elsif (my $makers = $MAKERS{$parent_new}) {
        $con = $makers->{constructor};
        $construct_opts{construction_string} = $con->construction_string
          if $con;
      }
      elsif ($parent_new->can('BUILDALL')) {
        $construct_opts{construction_builder} = sub {
          my $inv = $target->can('BUILDARGS') ? '' : 'Moo::Object::';
          'do {'
          .'  my $args = $class->'.$inv.'BUILDARGS(@_);'
          .'  $args->{__no_BUILD__} = 1;'
          .'  $invoker->'.$target.'::SUPER::new($args);'
          .'}'
        };
      }
      else {
        $construct_opts{construction_builder} = sub {
          '$invoker->'.$target.'::SUPER::new('
            .($target->can('FOREIGNBUILDARGS') ?
              '$class->FOREIGNBUILDARGS(@_)' : '@_')
            .')'
        };
      }
    }
    ($con ? ref($con) : 'Method::Generate::Constructor')
      ->new(%construct_opts)
      ->install_delayed
      ->register_attribute_specs(%{$con?$con->all_attribute_specs:{}})
  }
}

sub _concrete_methods_of {
  my ($me, $class) = @_;
  my $makers = $MAKERS{$class};

  my $non_methods = $makers->{non_methods} || {};
  my $stash = _getstash($class);

  my $subs = {
    map {;
      no strict 'refs';
      ${"${class}::${_}"} = ${"${class}::${_}"};
      ($_ => \&{"${class}::${_}"});
    }
    grep exists &{"${class}::${_}"},
    grep !/::\z/,
    keys %$stash
  };

  my %tracked = map +($_ => 1), _check_tracked($class, [ keys %$subs ]);

  return {
    map +($_ => \&{"${class}::${_}"}),
    grep !($non_methods->{$_} && $non_methods->{$_} == $subs->{$_}),
    grep !exists $tracked{$_},
    keys %$subs
  };
}

1;
__END__

=pod

=encoding utf-8

=head1 NAME

Moo - Minimalist Object Orientation (with Moose compatibility)

=head1 SYNOPSIS

  package Cat::Food;

  use Moo;
  use strictures 2;
  use namespace::clean;

  sub feed_lion {
    my $self = shift;
    my $amount = shift || 1;

    $self->pounds( $self->pounds - $amount );
  }

  has taste => (
    is => 'ro',
  );

  has brand => (
    is  => 'ro',
    isa => sub {
      die "Only SWEET-TREATZ supported!" unless $_[0] eq 'SWEET-TREATZ'
    },
  );

  has pounds => (
    is  => 'rw',
    isa => sub { die "$_[0] is too much cat food!" unless $_[0] < 15 },
  );

  1;

And elsewhere:

  my $full = Cat::Food->new(
      taste  => 'DELICIOUS.',
      brand  => 'SWEET-TREATZ',
      pounds => 10,
  );

  $full->feed_lion;

  say $full->pounds;

=head1 DESCRIPTION

C<Moo> is an extremely light-weight Object Orientation system. It allows one to
concisely define objects and roles with a convenient syntax that avoids the
details of Perl's object system.  C<Moo> contains a subset of L<Moose> and is
optimised for rapid startup.

C<Moo> avoids depending on any XS modules to allow for simple deployments.  The
name C<Moo> is based on the idea that it provides almost -- but not quite --
two thirds of L<Moose>.  As such, the L<Moose::Manual> can serve as an effective
guide to C<Moo> aside from the MOP and Types sections.

Unlike L<Mouse> this module does not aim at full compatibility with
L<Moose>'s surface syntax, preferring instead to provide full interoperability
via the metaclass inflation capabilities described in L</MOO AND MOOSE>.

For a full list of the minor differences between L<Moose> and L<Moo>'s surface
syntax, see L</INCOMPATIBILITIES WITH MOOSE>.

=head1 WHY MOO EXISTS

If you want a full object system with a rich Metaprotocol, L<Moose> is
already wonderful.

But if you don't want to use L<Moose>, you may not want "less metaprotocol"
like L<Mouse> offers, but you probably want "no metaprotocol", which is what
Moo provides. C<Moo> is ideal for some situations where deployment or startup
time precludes using L<Moose> and L<Mouse>:

=over 2

=item a command line or CGI script where fast startup is essential

=item code designed to be deployed as a single file via L<App::FatPacker>

=item a CPAN module that may be used by others in the above situations

=back

C<Moo> maintains transparent compatibility with L<Moose> so if you install and
load L<Moose> you can use Moo classes and roles in L<Moose> code without
modification.

Moo -- Minimal Object Orientation -- aims to make it smooth to upgrade to
L<Moose> when you need more than the minimal features offered by Moo.

=head1 MOO AND MOOSE

If L<Moo> detects L<Moose> being loaded, it will automatically register
metaclasses for your L<Moo> and L<Moo::Role> packages, so you should be able
to use them in L<Moose> code without modification.

L<Moo> will also create L<Moose type constraints|Moose::Manual::Types> for
L<Moo> classes and roles, so that in Moose classes C<< isa => 'MyMooClass' >>
and C<< isa => 'MyMooRole' >> work the same as for L<Moose> classes and roles.

Extending a L<Moose> class or consuming a L<Moose::Role> will also work.

Extending a L<Mouse> class or consuming a L<Mouse::Role> will also work. But
note that we don't provide L<Mouse> metaclasses or metaroles so the other way
around doesn't work. This feature exists for L<Any::Moose> users porting to
L<Moo>; enabling L<Mouse> users to use L<Moo> classes is not a priority for us.

This means that there is no need for anything like L<Any::Moose> for Moo
code - Moo and Moose code should simply interoperate without problem. To
handle L<Mouse> code, you'll likely need an empty Moo role or class consuming
or extending the L<Mouse> stuff since it doesn't register true L<Moose>
metaclasses like L<Moo> does.

If you need to disable the metaclass creation, add:

  no Moo::sification;

to your code before Moose is loaded, but bear in mind that this switch is
global and turns the mechanism off entirely so don't put this in library code.

=head1 MOO AND CLASS::XSACCESSOR

If a new enough version of L<Class::XSAccessor> is available, it will be used
to generate simple accessors, readers, and writers for better performance.
Simple accessors are those without lazy defaults, type checks/coercions, or
triggers.  Simple readers are those without lazy defaults. Readers and writers
generated by L<Class::XSAccessor> will behave slightly differently: they will
reject attempts to call them with the incorrect number of parameters.

=head1 MOO VERSUS ANY::MOOSE

L<Any::Moose> will load L<Mouse> normally, and L<Moose> in a program using
L<Moose> - which theoretically allows you to get the startup time of L<Mouse>
without disadvantaging L<Moose> users.

Sadly, this doesn't entirely work, since the selection is load order dependent
- L<Moo>'s metaclass inflation system explained above in L</MOO AND MOOSE> is
significantly more reliable.

So if you want to write a CPAN module that loads fast or has only pure perl
dependencies but is also fully usable by L<Moose> users, you should be using
L<Moo>.

For a full explanation, see the article
L<https://shadow.cat/blog/matt-s-trout/moo-versus-any-moose> which explains
the differing strategies in more detail and provides a direct example of
where L<Moo> succeeds and L<Any::Moose> fails.

=head1 PUBLIC METHODS

Moo provides several methods to any class using it.

=head2 new

  Foo::Bar->new( attr1 => 3 );

or

  Foo::Bar->new({ attr1 => 3 });

The constructor for the class.  By default it will accept attributes either as a
hashref, or a list of key value pairs.  This can be customized with the
L</BUILDARGS> method.

=head2 does

  if ($foo->does('Some::Role1')) {
    ...
  }

Returns true if the object composes in the passed role.

=head2 DOES

  if ($foo->DOES('Some::Role1') || $foo->DOES('Some::Class1')) {
    ...
  }

Similar to L</does>, but will also return true for both composed roles and
superclasses.

=head2 meta

  my $meta = Foo::Bar->meta;
  my @methods = $meta->get_method_list;

Returns an object that will behave as if it is a
L<Moose metaclass|Moose::Meta::Class> object for the class. If you call
anything other than C<make_immutable> on it, the object will be transparently
upgraded to a genuine L<Moose::Meta::Class> instance, loading Moose in the
process if required. C<make_immutable> itself is a no-op, since we generate
metaclasses that are already immutable, and users converting from Moose had
an unfortunate tendency to accidentally load Moose by calling it.

=head1 LIFECYCLE METHODS

There are several methods that you can define in your class to control
construction and destruction of objects.  They should be used rather than trying
to modify C<new> or C<DESTROY> yourself.

=head2 BUILDARGS

  around BUILDARGS => sub {
    my ( $orig, $class, @args ) = @_;

    return { attr1 => $args[0] }
      if @args == 1 && !ref $args[0];

    return $class->$orig(@args);
  };

  Foo::Bar->new( 3 );

This class method is used to transform the arguments to C<new> into a hash
reference of attribute values.

The default implementation accepts a hash or hash reference of named parameters.
If it receives a single argument that isn't a hash reference it will throw an
error.

You can override this method in your class to handle other types of options
passed to the constructor.

This method should always return a hash reference of named options.

=head2 FOREIGNBUILDARGS

  sub FOREIGNBUILDARGS {
    my ( $class, $options ) = @_;
    return $options->{foo};
  }

If you are inheriting from a non-Moo class, the arguments passed to the parent
class constructor can be manipulated by defining a C<FOREIGNBUILDARGS> method.
It will receive the same arguments as L</BUILDARGS>, and should return a list
of arguments to pass to the parent class constructor.

=head2 BUILD

  sub BUILD {
    my ($self, $args) = @_;
    die "foo and bar cannot be used at the same time"
      if exists $args->{foo} && exists $args->{bar};
  }

On object creation, any C<BUILD> methods in the class's inheritance hierarchy
will be called on the object and given the results of L</BUILDARGS>.  They each
will be called in order from the parent classes down to the child, and thus
should not themselves call the parent's method.  Typically this is used for
object validation or possibly logging.

=head2 DEMOLISH

  sub DEMOLISH {
    my ($self, $in_global_destruction) = @_;
    ...
  }

When an object is destroyed, any C<DEMOLISH> methods in the inheritance
hierarchy will be called on the object.  They are given boolean to inform them
if global destruction is in progress, and are called from the child class upwards
to the parent.  This is similar to L</BUILD> methods but in the opposite order.

Note that this is implemented by a C<DESTROY> method, which is only created on
on the first construction of an object of your class.  This saves on overhead for
classes that are never instantiated or those without C<DEMOLISH> methods.  If you
try to define your own C<DESTROY>, this will cause undefined results.

=head1 IMPORTED SUBROUTINES

=head2 extends

  extends 'Parent::Class';

Declares a base class. Multiple superclasses can be passed for multiple
inheritance but please consider using L<roles|Moo::Role> instead.  The class
will be loaded but no errors will be triggered if the class can't be found and
there are already subs in the class.

Calling extends more than once will REPLACE your superclasses, not add to
them like 'use base' would.

=head2 with

  with 'Some::Role1';

or

  with 'Some::Role1', 'Some::Role2';

Composes one or more L<Moo::Role> (or L<Role::Tiny>) roles into the current
class.  An error will be raised if these roles cannot be composed because they
have conflicting method definitions.  The roles will be loaded using the same
mechanism as C<extends> uses.

=head2 has

  has attr => (
    is => 'ro',
  );

Declares an attribute for the class.

  package Foo;
  use Moo;
  has 'attr' => (
    is => 'ro'
  );

  package Bar;
  use Moo;
  extends 'Foo';
  has '+attr' => (
    default => sub { "blah" },
  );

Using the C<+> notation, it's possible to override an attribute.

  has [qw(attr1 attr2 attr3)] => (
    is => 'ro',
  );

Using an arrayref with multiple attribute names, it's possible to declare
multiple attributes with the same options.

The options for C<has> are as follows:

=over 2

=item C<is>

B<required>, may be C<ro>, C<lazy>, C<rwp> or C<rw>.

C<ro> stands for "read-only" and generates an accessor that dies if you attempt
to write to it - i.e.  a getter only - by defaulting C<reader> to the name of
the attribute.

C<lazy> generates a reader like C<ro>, but also sets C<lazy> to 1 and
C<builder> to C<_build_${attribute_name}> to allow on-demand generated
attributes.  This feature was my attempt to fix my incompetence when
originally designing C<lazy_build>, and is also implemented by
L<MooseX::AttributeShortcuts>. There is, however, nothing to stop you
using C<lazy> and C<builder> yourself with C<rwp> or C<rw> - it's just that
this isn't generally a good idea so we don't provide a shortcut for it.

C<rwp> stands for "read-write protected" and generates a reader like C<ro>, but
also sets C<writer> to C<_set_${attribute_name}> for attributes that are
designed to be written from inside of the class, but read-only from outside.
This feature comes from L<MooseX::AttributeShortcuts>.

C<rw> stands for "read-write" and generates a normal getter/setter by
defaulting the C<accessor> to the name of the attribute specified.

=item C<isa>

Takes a coderef which is used to validate the attribute.  Unlike L<Moose>, Moo
does not include a basic type system, so instead of doing C<< isa => 'Num' >>,
one should do

  use Scalar::Util qw(looks_like_number);
  ...
  isa => sub {
    die "$_[0] is not a number!" unless looks_like_number $_[0]
  },

Note that the return value for C<isa> is discarded. Only if the sub dies does
type validation fail.

L<Sub::Quote aware|/SUB QUOTE AWARE>

Since L<Moo> does B<not> run the C<isa> check before C<coerce> if a coercion
subroutine has been supplied, C<isa> checks are not structural to your code
and can, if desired, be omitted on non-debug builds (although if this results
in an uncaught bug causing your program to break, the L<Moo> authors guarantee
nothing except that you get to keep both halves).

If you want L<Moose> compatible or L<MooseX::Types> style named types, look at
L<Type::Tiny>.

To cause your C<isa> entries to be automatically mapped to named
L<Moose::Meta::TypeConstraint> objects (rather than the default behaviour
of creating an anonymous type), set:

  $Moo::HandleMoose::TYPE_MAP{$isa_coderef} = sub {
    require MooseX::Types::Something;
    return MooseX::Types::Something::TypeName();
  };

Note that this example is purely illustrative; anything that returns a
L<Moose::Meta::TypeConstraint> object or something similar enough to it to
make L<Moose> happy is fine.

=item C<coerce>

Takes a coderef which is meant to coerce the attribute.  The basic idea is to
do something like the following:

 coerce => sub {
   $_[0] % 2 ? $_[0] : $_[0] + 1
 },

Note that L<Moo> will always execute your coercion: this is to permit
C<isa> entries to be used purely for bug trapping, whereas coercions are
always structural to your code. We do, however, apply any supplied C<isa>
check after the coercion has run to ensure that it returned a valid value.

L<Sub::Quote aware|/SUB QUOTE AWARE>

If the C<isa> option is a blessed object providing a C<coerce> or
C<coercion> method, then the C<coerce> option may be set to just C<1>.

=item C<handles>

Takes a string

  handles => 'RobotRole'

Where C<RobotRole> is a L<role|Moo::Role> that defines an interface which
becomes the list of methods to handle.

Takes a list of methods

  handles => [ qw( one two ) ]

Takes a hashref

  handles => {
    un => 'one',
  }

=item C<trigger>

Takes a coderef which will get called any time the attribute is set. This
includes the constructor, but not default or built values. The coderef will be
invoked against the object with the new value as an argument.

If you set this to just C<1>, it generates a trigger which calls the
C<_trigger_${attr_name}> method on C<$self>. This feature comes from
L<MooseX::AttributeShortcuts>.

Note that Moose also passes the old value, if any; this feature is not yet
supported.

L<Sub::Quote aware|/SUB QUOTE AWARE>

=item C<default>

Takes a coderef which will get called with $self as its only argument to
populate an attribute if no value for that attribute was supplied to the
constructor. Alternatively, if the attribute is lazy, C<default> executes when
the attribute is first retrieved if no value has yet been provided.

If a simple scalar is provided, it will be inlined as a string. Any non-code
reference (hash, array) will result in an error - for that case instead use
a code reference that returns the desired value.

Note that if your default is fired during new() there is no guarantee that
other attributes have been populated yet so you should not rely on their
existence.

L<Sub::Quote aware|/SUB QUOTE AWARE>

=item C<predicate>

Takes a method name which will return true if an attribute has a value.

If you set this to just C<1>, the predicate is automatically named
C<has_${attr_name}> if your attribute's name does not start with an
underscore, or C<_has_${attr_name_without_the_underscore}> if it does.
This feature comes from L<MooseX::AttributeShortcuts>.

=item C<builder>

Takes a method name which will be called to create the attribute - functions
exactly like default except that instead of calling

  $default->($self);

Moo will call

  $self->$builder;

The following features come from L<MooseX::AttributeShortcuts>:

If you set this to just C<1>, the builder is automatically named
C<_build_${attr_name}>.

If you set this to a coderef or code-convertible object, that variable will be
installed under C<$class::_build_${attr_name}> and the builder set to the same
name.

=item C<clearer>

Takes a method name which will clear the attribute.

If you set this to just C<1>, the clearer is automatically named
C<clear_${attr_name}> if your attribute's name does not start with an
underscore, or C<_clear_${attr_name_without_the_underscore}> if it does.
This feature comes from L<MooseX::AttributeShortcuts>.

B<NOTE:> If the attribute is C<lazy>, it will be regenerated from C<default> or
C<builder> the next time it is accessed. If it is not lazy, it will be C<undef>.

=item C<lazy>

B<Boolean>.  Set this if you want values for the attribute to be grabbed
lazily.  This is usually a good idea if you have a L</builder> which requires
another attribute to be set.

=item C<required>

B<Boolean>.  Set this if the attribute must be passed on object instantiation.

=item C<reader>

The name of the method that returns the value of the attribute.  If you like
Java style methods, you might set this to C<get_foo>

=item C<writer>

The value of this attribute will be the name of the method to set the value of
the attribute.  If you like Java style methods, you might set this to
C<set_foo>.

=item C<weak_ref>

B<Boolean>.  Set this if you want the reference that the attribute contains to
be weakened. Use this when circular references, which cause memory leaks, are
possible.

=item C<init_arg>

Takes the name of the key to look for at instantiation time of the object.  A
common use of this is to make an underscored attribute have a non-underscored
initialization name. C<undef> means that passing the value in on instantiation
is ignored.

=item C<moosify>

Takes either a coderef or array of coderefs which is meant to transform the
given attributes specifications if necessary when upgrading to a Moose role or
class. You shouldn't need this by default, but is provided as a means of
possible extensibility.

=back

=head2 before

  before foo => sub { ... };

See L<< Class::Method::Modifiers/before method(s) => sub { ... }; >> for full
documentation.

=head2 around

  around foo => sub { ... };

See L<< Class::Method::Modifiers/around method(s) => sub { ... }; >> for full
documentation.

=head2 after

  after foo => sub { ... };

See L<< Class::Method::Modifiers/after method(s) => sub { ... }; >> for full
documentation.

=head1 SUB QUOTE AWARE

L<Sub::Quote/quote_sub> allows us to create coderefs that are "inlineable,"
giving us a handy, XS-free speed boost.  Any option that is L<Sub::Quote>
aware can take advantage of this.

To do this, you can write

  use Sub::Quote;

  use Moo;
  use namespace::clean;

  has foo => (
    is => 'ro',
    isa => quote_sub(q{ die "Not <3" unless $_[0] < 3 })
  );

which will be inlined as

  do {
    local @_ = ($_[0]->{foo});
    die "Not <3" unless $_[0] < 3;
  }

or to avoid localizing @_,

  has foo => (
    is => 'ro',
    isa => quote_sub(q{ my ($val) = @_; die "Not <3" unless $val < 3 })
  );

which will be inlined as

  do {
    my ($val) = ($_[0]->{foo});
    die "Not <3" unless $val < 3;
  }

See L<Sub::Quote> for more information, including how to pass lexical
captures that will also be compiled into the subroutine.

=head1 CLEANING UP IMPORTS

L<Moo> will not clean up imported subroutines for you; you will have
to do that manually. The recommended way to do this is to declare your
imports first, then C<use Moo>, then C<use namespace::clean>.
Anything imported before L<namespace::clean> will be scrubbed.
Anything imported or declared after will be still be available.

  package Record;

  use Digest::MD5 qw(md5_hex);

  use Moo;
  use namespace::clean;

  has name => (is => 'ro', required => 1);
  has id => (is => 'lazy');
  sub _build_id {
    my ($self) = @_;
    return md5_hex($self->name);
  }

  1;

For example if you were to import these subroutines after
L<namespace::clean> like this

  use namespace::clean;

  use Digest::MD5 qw(md5_hex);
  use Moo;

then any C<Record> C<$r> would have methods such as C<< $r->md5_hex() >>, 
C<< $r->has() >> and C<< $r->around() >> - almost certainly not what you
intend!

L<Moo::Role>s behave slightly differently.  Since their methods are
composed into the consuming class, they can do a little more for you
automatically.  As long as you declare your imports before calling
C<use Moo::Role>, those imports and the ones L<Moo::Role> itself
provides will not be composed into consuming classes so there's usually
no need to use L<namespace::clean>.

B<On L<namespace::autoclean>:> Older versions of L<namespace::autoclean> would
inflate Moo classes to full L<Moose> classes, losing the benefits of Moo.  If
you want to use L<namespace::autoclean> with a Moo class, make sure you are
using version 0.16 or newer.

=head1 INCOMPATIBILITIES WITH MOOSE

=head2 TYPES

There is no built-in type system.  C<isa> is verified with a coderef; if you
need complex types, L<Type::Tiny> can provide types, type libraries, and
will work seamlessly with both L<Moo> and L<Moose>.  L<Type::Tiny> can be
considered the successor to L<MooseX::Types> and provides a similar API, so
that you can write

  use Types::Standard qw(Int);
  has days_to_live => (is => 'ro', isa => Int);

=head2 API INCOMPATIBILITIES

C<initializer> is not supported in core since the author considers it to be a
bad idea and Moose best practices recommend avoiding it. Meanwhile C<trigger> or
C<coerce> are more likely to be able to fulfill your needs.

No support for C<super>, C<override>, C<inner>, or C<augment> - the author
considers augment to be a bad idea, and override can be translated:

  override foo => sub {
    ...
    super();
    ...
  };

  around foo => sub {
    my ($orig, $self) = (shift, shift);
    ...
    $self->$orig(@_);
    ...
  };

The C<dump> method is not provided by default. The author suggests loading
L<Devel::Dwarn> into C<main::> (via C<perl -MDevel::Dwarn ...> for example) and
using C<< $obj->$::Dwarn() >> instead.

L</default> only supports coderefs and plain scalars, because passing a hash
or array reference as a default is almost always incorrect since the value is
then shared between all objects using that default.

C<lazy_build> is not supported; you are instead encouraged to use the
C<< is => 'lazy' >> option supported by L<Moo> and
L<MooseX::AttributeShortcuts>.

C<auto_deref> is not supported since the author considers it a bad idea and
it has been considered best practice to avoid it for some time.

C<documentation> will show up in a L<Moose> metaclass created from your class
but is otherwise ignored. Then again, L<Moose> ignores it as well, so this
is arguably not an incompatibility.

Since C<coerce> does not require C<isa> to be defined but L<Moose> does
require it, the metaclass inflation for coerce alone is a trifle insane
and if you attempt to subtype the result will almost certainly break.

Handling of warnings: when you C<use Moo> we enable strict and warnings, in a
similar way to Moose. The authors recommend the use of C<strictures>, which
enables FATAL warnings, and several extra pragmas when used in development:
L<indirect>, L<multidimensional>, and L<bareword::filehandles>.

Additionally, L<Moo> supports a set of attribute option shortcuts intended to
reduce common boilerplate.  The set of shortcuts is the same as in the L<Moose>
module L<MooseX::AttributeShortcuts> as of its version 0.009+.  So if you:

  package MyClass;
  use Moo;
  use strictures 2;

The nearest L<Moose> invocation would be:

  package MyClass;

  use Moose;
  use warnings FATAL => "all";
  use MooseX::AttributeShortcuts;

or, if you're inheriting from a non-Moose class,

  package MyClass;

  use Moose;
  use MooseX::NonMoose;
  use warnings FATAL => "all";
  use MooseX::AttributeShortcuts;

=head2 META OBJECT

There is no meta object.  If you need this level of complexity you need
L<Moose> - Moo is small because it explicitly does not provide a metaprotocol.
However, if you load L<Moose>, then

  Class::MOP::class_of($moo_class_or_role)

will return an appropriate metaclass pre-populated by L<Moo>.

=head2 IMMUTABILITY

Finally, Moose requires you to call

  __PACKAGE__->meta->make_immutable;

at the end of your class to get an inlined (i.e. not horribly slow)
constructor. Moo does it automatically the first time ->new is called
on your class. (C<make_immutable> is a no-op in Moo to ease migration.)

An extension L<MooX::late> exists to ease translating Moose packages
to Moo by providing a more Moose-like interface.

=head1 COMPATIBILITY WITH OLDER PERL VERSIONS

Moo is compatible with perl versions back to 5.6.  When running on older
versions, additional prerequisites will be required.  If you are packaging a
script with its dependencies, such as with L<App::FatPacker>, you will need to
be certain that the extra prerequisites are included.

=over 4

=item L<MRO::Compat>

Required on perl versions prior to 5.10.0.

=item L<Devel::GlobalDestruction>

Required on perl versions prior to 5.14.0.

=back

=head1 SUPPORT

IRC: #moose on irc.perl.org

=for :html
L<(click for instant chatroom login)|https://chat.mibbit.com/#moose@irc.perl.org>

Bugtracker: L<https://rt.cpan.org/Public/Dist/Display.html?Name=Moo>

Git repository: L<git://github.com/moose/Moo.git>

Git browser: L<https://github.com/moose/Moo>

=head1 AUTHOR

mst - Matt S. Trout (cpan:MSTROUT) <mst@shadowcat.co.uk>

=head1 CONTRIBUTORS

dg - David Leadbeater (cpan:DGL) <dgl@dgl.cx>

frew - Arthur Axel "fREW" Schmidt (cpan:FREW) <frioux@gmail.com>

hobbs - Andrew Rodland (cpan:ARODLAND) <arodland@cpan.org>

jnap - John Napiorkowski (cpan:JJNAPIORK) <jjn1056@yahoo.com>

ribasushi - Peter Rabbitson (cpan:RIBASUSHI) <ribasushi@cpan.org>

chip - Chip Salzenberg (cpan:CHIPS) <chip@pobox.com>

ajgb - Alex J. G. Burzyński (cpan:AJGB) <ajgb@cpan.org>

doy - Jesse Luehrs (cpan:DOY) <doy at tozt dot net>

perigrin - Chris Prather (cpan:PERIGRIN) <chris@prather.org>

Mithaldu - Christian Walde (cpan:MITHALDU) <walde.christian@googlemail.com>

ilmari - Dagfinn Ilmari Mannsåker (cpan:ILMARI) <ilmari@ilmari.org>

tobyink - Toby Inkster (cpan:TOBYINK) <tobyink@cpan.org>

haarg - Graham Knop (cpan:HAARG) <haarg@cpan.org>

mattp - Matt Phillips (cpan:MATTP) <mattp@cpan.org>

bluefeet - Aran Deltac (cpan:BLUEFEET) <bluefeet@gmail.com>

bubaflub - Bob Kuo (cpan:BUBAFLUB) <bubaflub@cpan.org>

ether = Karen Etheridge (cpan:ETHER) <ether@cpan.org>

=head1 COPYRIGHT

Copyright (c) 2010-2015 the Moo L</AUTHOR> and L</CONTRIBUTORS>
as listed above.

=head1 LICENSE

This library is free software and may be distributed under the same terms
as perl itself. See L<https://dev.perl.org/licenses/>.

=cut
