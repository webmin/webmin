package Moo::Role;
use strict;
use warnings;

use Moo::_Utils qw(
  _check_tracked
  _getglob
  _getstash
  _install_coderef
  _install_modifier
  _install_tracked
  _load_module
  _name_coderef
  _set_loaded
  _unimport_coderefs
);
use Carp qw(croak);
use Role::Tiny ();
BEGIN { our @ISA = qw(Role::Tiny) }
BEGIN {
  our @CARP_NOT = qw(
    Method::Generate::Accessor
    Method::Generate::Constructor
    Moo::sification
    Moo::_Utils
    Role::Tiny
  );
}

our $VERSION = '2.005004';
$VERSION =~ tr/_//d;

require Moo::sification;
Moo::sification->import;

BEGIN {
    *INFO = \%Role::Tiny::INFO;
    *APPLIED_TO = \%Role::Tiny::APPLIED_TO;
    *COMPOSED = \%Role::Tiny::COMPOSED;
    *ON_ROLE_CREATE = \@Role::Tiny::ON_ROLE_CREATE;
}

our %INFO;
our %APPLIED_TO;
our %APPLY_DEFAULTS;
our %COMPOSED;
our @ON_ROLE_CREATE;

sub import {
  my $target = caller;
  if ($Moo::MAKERS{$target} and $Moo::MAKERS{$target}{is_class}) {
    croak "Cannot import Moo::Role into a Moo class";
  }
  _set_loaded(caller);
  goto &Role::Tiny::import;
}

sub _accessor_maker_for {
  my ($class, $target) = @_;
  ($INFO{$target}{accessor_maker} ||= do {
    require Method::Generate::Accessor;
    Method::Generate::Accessor->new
  });
}

sub _install_subs {
  my ($me, $target) = @_;
  my %install = $me->_gen_subs($target);
  _install_tracked $target => $_ => $install{$_}
    for sort keys %install;
  *{_getglob("${target}::meta")} = $me->can('meta');
  return;
}

sub _require_module {
  _load_module($_[1]);
}

sub _gen_subs {
  my ($me, $target) = @_;
  return (
    has => sub {
      my $name_proto = shift;
      my @name_proto = ref $name_proto eq 'ARRAY' ? @$name_proto : $name_proto;
      if (@_ % 2 != 0) {
        croak("Invalid options for " . join(', ', map "'$_'", @name_proto)
          . " attribute(s): even number of arguments expected, got " . scalar @_)
      }
      my %spec = @_;
      foreach my $name (@name_proto) {
        my $spec_ref = @name_proto > 1 ? +{%spec} : \%spec;
        $me->_accessor_maker_for($target)
          ->generate_method($target, $name, $spec_ref);
        push @{$INFO{$target}{attributes}||=[]}, $name, $spec_ref;
        $me->_maybe_reset_handlemoose($target);
      }
    },
    (map {
      my $type = $_;
      (
        $type => sub {
          push @{$INFO{$target}{modifiers}||=[]}, [ $type => @_ ];
          $me->_maybe_reset_handlemoose($target);
        },
      )
    } qw(before after around)),
    requires => sub {
      push @{$INFO{$target}{requires}||=[]}, @_;
      $me->_maybe_reset_handlemoose($target);
    },
    with => sub {
      $me->apply_roles_to_package($target, @_);
      $me->_maybe_reset_handlemoose($target);
    },
  );
}

push @ON_ROLE_CREATE, sub {
  my $target = shift;
  if ($INC{'Moo/HandleMoose.pm'} && !$Moo::sification::disabled) {
    Moo::HandleMoose::inject_fake_metaclass_for($target);
  }
};

# duplicate from Moo::Object
sub meta {
  require Moo::HandleMoose::FakeMetaClass;
  my $class = ref($_[0])||$_[0];
  bless({ name => $class }, 'Moo::HandleMoose::FakeMetaClass');
}

sub unimport {
  my $target = caller;
  _unimport_coderefs($target);
}

sub _maybe_reset_handlemoose {
  my ($class, $target) = @_;
  if ($INC{'Moo/HandleMoose.pm'} && !$Moo::sification::disabled) {
    Moo::HandleMoose::maybe_reinject_fake_metaclass_for($target);
  }
}

sub _non_methods {
  my $self = shift;
  my ($role) = @_;

  my $non_methods = $self->SUPER::_non_methods(@_);

  my $all_subs = $self->_all_subs($role);
  $non_methods->{$_} = $all_subs->{$_}
    for _check_tracked($role, [ keys %$all_subs ]);

  return $non_methods;
}

sub is_role {
  my ($self, $role) = @_;
  $self->_inhale_if_moose($role);
  $self->SUPER::is_role($role);
}

sub _inhale_if_moose {
  my ($self, $role) = @_;
  my $meta;
  if (!$self->SUPER::is_role($role)
      and (
        $INC{"Moose.pm"}
        and $meta = Class::MOP::class_of($role)
        and ref $meta ne 'Moo::HandleMoose::FakeMetaClass'
        and $meta->isa('Moose::Meta::Role')
      )
      or (
        Mouse::Util->can('find_meta')
        and $meta = Mouse::Util::find_meta($role)
        and $meta->isa('Mouse::Meta::Role')
     )
  ) {
    my $is_mouse = $meta->isa('Mouse::Meta::Role');
    $INFO{$role}{methods} = {
      map +($_ => $role->can($_)),
        grep $role->can($_),
        grep !($is_mouse && $_ eq 'meta'),
        grep !$meta->get_method($_)->isa('Class::MOP::Method::Meta'),
          $meta->get_method_list
    };
    $APPLIED_TO{$role} = {
      map +($_->name => 1), $meta->calculate_all_roles
    };
    $INFO{$role}{requires} = [ $meta->get_required_method_list ];
    $INFO{$role}{attributes} = [
      map +($_ => do {
        my $attr = $meta->get_attribute($_);
        my $spec = { %{ $is_mouse ? $attr : $attr->original_options } };

        if ($spec->{isa}) {
          require Sub::Quote;

          my $get_constraint = do {
            my $pkg = $is_mouse
                        ? 'Mouse::Util::TypeConstraints'
                        : 'Moose::Util::TypeConstraints';
            _load_module($pkg);
            $pkg->can('find_or_create_isa_type_constraint');
          };

          my $tc = $get_constraint->($spec->{isa});
          my $check = $tc->_compiled_type_constraint;
          my $tc_var = '$_check_for_'.Sub::Quote::sanitize_identifier($tc->name);

          $spec->{isa} = Sub::Quote::quote_sub(
            qq{
              &${tc_var} or Carp::croak "Type constraint failed for \$_[0]"
            },
            { $tc_var => \$check },
            {
              package => $role,
            },
          );

          if ($spec->{coerce}) {

             # Mouse has _compiled_type_coercion straight on the TC object
             $spec->{coerce} = $tc->${\(
               $tc->can('coercion')||sub { $_[0] }
             )}->_compiled_type_coercion;
          }
        }
        $spec;
      }), $meta->get_attribute_list
    ];
    my $mods = $INFO{$role}{modifiers} = [];
    foreach my $type (qw(before after around)) {
      # Mouse pokes its own internals so we have to fall back to doing
      # the same thing in the absence of the Moose API method
      my $map = $meta->${\(
        $meta->can("get_${type}_method_modifiers_map")
        or sub { shift->{"${type}_method_modifiers"} }
      )};
      foreach my $method (keys %$map) {
        foreach my $mod (@{$map->{$method}}) {
          push @$mods, [ $type => $method => $mod ];
        }
      }
    }
    $INFO{$role}{inhaled_from_moose} = 1;
    $INFO{$role}{is_role} = 1;
  }
}

sub _maybe_make_accessors {
  my ($self, $target, $role) = @_;
  my $m;
  if ($INFO{$role} && $INFO{$role}{inhaled_from_moose}
      or $INC{"Moo.pm"}
      and $m = Moo->_accessor_maker_for($target)
      and ref($m) ne 'Method::Generate::Accessor') {
    $self->_make_accessors($target, $role);
  }
}

sub _make_accessors_if_moose {
  my ($self, $target, $role) = @_;
  if ($INFO{$role} && $INFO{$role}{inhaled_from_moose}) {
    $self->_make_accessors($target, $role);
  }
}

sub _make_accessors {
  my ($self, $target, $role) = @_;
  my $acc_gen = ($Moo::MAKERS{$target}{accessor} ||= do {
    require Method::Generate::Accessor;
    Method::Generate::Accessor->new
  });
  my $con_gen = $Moo::MAKERS{$target}{constructor};
  my @attrs = @{$INFO{$role}{attributes}||[]};
  while (my ($name, $spec) = splice @attrs, 0, 2) {
    # needed to ensure we got an index for an arrayref based generator
    if ($con_gen) {
      $spec = $con_gen->all_attribute_specs->{$name};
    }
    $acc_gen->generate_method($target, $name, $spec);
  }
}

sub _undefer_subs {
  my ($self, $target, $role) = @_;
  if ($INC{'Sub/Defer.pm'}) {
    Sub::Defer::undefer_package($role);
  }
}

sub role_application_steps {
  qw(_handle_constructor _undefer_subs _maybe_make_accessors),
    $_[0]->SUPER::role_application_steps;
}

sub _build_class_with_roles {
  my ($me, $new_name, $superclass, @roles) = @_;
  $Moo::MAKERS{$new_name} = {is_class => 1};
  $me->SUPER::_build_class_with_roles($new_name, $superclass, @roles);

  if ($INC{'Moo/HandleMoose.pm'} && !$Moo::sification::disabled) {
    Moo::HandleMoose::inject_fake_metaclass_for($new_name);
  }

  my $lvl = 0;
  my $file;
  while ((my $pack, $file) = caller($lvl++)) {
    if ($pack ne __PACKAGE__ && $pack ne 'Role::Tiny' && !$pack->isa($me)) {
      last;
    }
  }
  _set_loaded($new_name, $file || (caller)[1]);

  return $new_name;
}

sub _gen_apply_defaults_for {
  my ($me, $class, @roles) = @_;

  my @attrs = map @{$INFO{$_}{attributes}||[]}, @roles;

  my $con_gen;
  my $m;

  return undef
    unless $INC{'Moo.pm'}
    and @attrs
    and $con_gen = Moo->_constructor_maker_for($class)
    and $m = Moo->_accessor_maker_for($class);

  my $specs = $con_gen->all_attribute_specs;

  my %seen;
  my %captures;
  my @set;
  while (my ($name, $spec) = splice @attrs, 0, 2) {
    next
      if $seen{$name}++;

    next
      unless $m->has_eager_default($name, $spec);

    my ($has, $has_cap)
      = $m->generate_simple_has('$_[0]', $name, $spec);
    my ($set, $pop_cap)
      = $m->generate_use_default('$_[0]', $name, $spec, $has);

    @captures{keys %$has_cap, keys %$pop_cap}
      = (values %$has_cap, values %$pop_cap);

    push @set, $set;
  }

  return undef
    if !@set;

  my $code = join '', map "($_),", @set;
  no warnings 'void';
  require Sub::Quote;
  return Sub::Quote::quote_sub(
    "${class}::_apply_defaults",
    $code,
    \%captures,
    {
      package => $class,
      no_install => 1,
      no_defer => 1,
    }
  );
}

sub apply_roles_to_object {
  my ($me, $object, @roles) = @_;
  my $new = $me->SUPER::apply_roles_to_object($object, @roles);
  my $class = ref $new;
  _set_loaded($class, (caller)[1]);

  if (!exists $APPLY_DEFAULTS{$class}) {
    $APPLY_DEFAULTS{$class} = $me->_gen_apply_defaults_for($class, @roles);
  }
  if (my $apply_defaults = $APPLY_DEFAULTS{$class}) {
    local $Carp::Internal{+__PACKAGE__} = 1;
    local $Carp::Internal{$class} = 1;
    $new->$apply_defaults;
  }
  return $new;
}

sub _install_single_modifier {
  my ($me, @args) = @_;
  _install_modifier(@args);
}

sub _install_does {
    my ($me, $to) = @_;

    # If Role::Tiny actually installed the DOES, give it a name
    my $new = $me->SUPER::_install_does($to) or return;
    return _name_coderef("${to}::DOES", $new);
}

sub does_role {
  my ($proto, $role) = @_;
  return 1
    if Role::Tiny::does_role($proto, $role);
  my $meta;
  if ($INC{'Moose.pm'}
      and $meta = Class::MOP::class_of($proto)
      and ref $meta ne 'Moo::HandleMoose::FakeMetaClass'
      and $meta->can('does_role')
  ) {
    return $meta->does_role($role);
  }
  return 0;
}

sub _handle_constructor {
  my ($me, $to, $role) = @_;
  my $attr_info = $INFO{$role} && $INFO{$role}{attributes};
  return unless $attr_info && @$attr_info;
  my $info = $INFO{$to};
  my $con = $INC{"Moo.pm"} && Moo->_constructor_maker_for($to);
  my %existing
    = $info ? @{$info->{attributes} || []}
    : $con  ? %{$con->all_attribute_specs || {}}
    : ();

  my @attr_info =
    map { @{$attr_info}[$_, $_+1] }
    grep { ! $existing{$attr_info->[$_]} }
    map { 2 * $_ } 0..@$attr_info/2-1;

  if ($info) {
    push @{$info->{attributes}||=[]}, @attr_info;
  }
  elsif ($con) {
    # shallow copy of the specs since the constructor will assign an index
    $con->register_attribute_specs(map ref() ? { %$_ } : $_, @attr_info);
  }
}

1;
__END__

=head1 NAME

Moo::Role - Minimal Object Orientation support for Roles

=head1 SYNOPSIS

  package My::Role;

  use Moo::Role;
  use strictures 2;

  sub foo { ... }

  sub bar { ... }

  has baz => (
    is => 'ro',
  );

  1;

And elsewhere:

  package Some::Class;

  use Moo;
  use strictures 2;

  # bar gets imported, but not foo
  with 'My::Role';

  sub foo { ... }

  1;

=head1 DESCRIPTION

C<Moo::Role> builds upon L<Role::Tiny>, so look there for most of the
documentation on how this works (in particular, using C<Moo::Role> also
enables L<strict> and L<warnings>).  The main addition here is extra bits to
make the roles more "Moosey;" which is to say, it adds L</has>.

=head1 IMPORTED SUBROUTINES

See L<Role::Tiny/IMPORTED SUBROUTINES> for all the other subroutines that are
imported by this module.

=head2 has

  has attr => (
    is => 'ro',
  );

Declares an attribute for the class to be composed into.  See
L<Moo/has> for all options.

=head1 CLEANING UP IMPORTS

L<Moo::Role> cleans up its own imported methods and any imports
declared before the C<use Moo::Role> statement automatically.
Anything imported after C<use Moo::Role> will be composed into
consuming packages.  A package that consumes this role:

  package My::Role::ID;

  use Digest::MD5 qw(md5_hex);
  use Moo::Role;
  use Digest::SHA qw(sha1_hex);

  requires 'name';

  sub as_md5  { my ($self) = @_; return md5_hex($self->name);  }
  sub as_sha1 { my ($self) = @_; return sha1_hex($self->name); }

  1;

..will now have a C<< $self->sha1_hex() >> method available to it
that probably does not do what you expect.  On the other hand, a call
to C<< $self->md5_hex() >> will die with the helpful error message:
C<Can't locate object method "md5_hex">.

See L<Moo/"CLEANING UP IMPORTS"> for more details.

=head1 SUPPORT

See L<Moo> for support and contact information.

=head1 AUTHORS

See L<Moo> for authors.

=head1 COPYRIGHT AND LICENSE

See L<Moo> for the copyright and license.

=cut
