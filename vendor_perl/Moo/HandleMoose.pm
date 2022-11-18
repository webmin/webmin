package Moo::HandleMoose;
use strict;
use warnings;
no warnings 'once';

use Moo::_Utils qw(_getstash);
use Sub::Quote qw(quotify);
use Carp qw(croak);

our %TYPE_MAP;

our $SETUP_DONE;

sub import { return if $SETUP_DONE; inject_all(); $SETUP_DONE = 1; }

sub inject_all {
  croak "Can't inflate Moose metaclass with Moo::sification disabled"
    if $Moo::sification::disabled;
  require Class::MOP;
  inject_fake_metaclass_for($_)
    for grep $_ ne 'Moo::Object', keys %Moo::MAKERS;
  inject_fake_metaclass_for($_) for keys %Moo::Role::INFO;
  require Moose::Meta::Method::Constructor;
  @Moo::HandleMoose::FakeConstructor::ISA = 'Moose::Meta::Method::Constructor';
  @Moo::HandleMoose::FakeMeta::ISA = 'Moose::Meta::Method::Meta';
}

sub maybe_reinject_fake_metaclass_for {
  my ($name) = @_;
  our %DID_INJECT;
  if (delete $DID_INJECT{$name}) {
    unless ($Moo::Role::INFO{$name}) {
      Moo->_constructor_maker_for($name)->install_delayed;
    }
    inject_fake_metaclass_for($name);
  }
}

sub inject_fake_metaclass_for {
  my ($name) = @_;
  require Class::MOP;
  require Moo::HandleMoose::FakeMetaClass;
  Class::MOP::store_metaclass_by_name(
    $name, bless({ name => $name }, 'Moo::HandleMoose::FakeMetaClass')
  );
  require Moose::Util::TypeConstraints;
  if ($Moo::Role::INFO{$name}) {
    Moose::Util::TypeConstraints::find_or_create_does_type_constraint($name);
  } else {
    Moose::Util::TypeConstraints::find_or_create_isa_type_constraint($name);
  }
}

{
  package Moo::HandleMoose::FakeConstructor;

  sub _uninlined_body { \&Moose::Object::new }
}

sub inject_real_metaclass_for {
  my ($name) = @_;
  our %DID_INJECT;
  return Class::MOP::get_metaclass_by_name($name) if $DID_INJECT{$name};
  require Moose; require Moo; require Moo::Role; require Scalar::Util;
  require Sub::Defer;
  Class::MOP::remove_metaclass_by_name($name);
  my ($am_role, $am_class, $meta, $attr_specs, $attr_order) = do {
    if (my $info = $Moo::Role::INFO{$name}) {
      my @attr_info = @{$info->{attributes}||[]};
      (1, 0, Moose::Meta::Role->initialize($name),
       { @attr_info },
       [ @attr_info[grep !($_ % 2), 0..$#attr_info] ]
      )
    } elsif ( my $cmaker = Moo->_constructor_maker_for($name) ) {
      my $specs = $cmaker->all_attribute_specs;
      (0, 1, Moose::Meta::Class->initialize($name), $specs,
       [ sort { $specs->{$a}{index} <=> $specs->{$b}{index} } keys %$specs ]
      );
    } else {
       # This codepath is used if $name does not exist in $Moo::MAKERS
       (0, 0, Moose::Meta::Class->initialize($name), {}, [] )
    }
  };

  {
    local $DID_INJECT{$name} = 1;
    foreach my $spec (values %$attr_specs) {
      if (my $inflators = delete $spec->{moosify}) {
        $_->($spec) for @$inflators;
      }
    }

    my %methods
      = %{($am_role ? 'Moo::Role' : 'Moo')->_concrete_methods_of($name)};

    # if stuff gets added afterwards, _maybe_reset_handlemoose should
    # trigger the recreation of the metaclass but we need to ensure the
    # Moo::Role cache is cleared so we don't confuse Moo itself.
    if (my $info = $Moo::Role::INFO{$name}) {
      delete $info->{methods};
    }

    # needed to ensure the method body is stable and get things named
    $methods{$_} = Sub::Defer::undefer_sub($methods{$_})
      for
        grep $_ ne 'new',
        keys %methods;
    my @attrs;
    {
      # This local is completely not required for roles but harmless
      local @{_getstash($name)}{keys %methods};
      my %seen_name;
      foreach my $attr_name (@$attr_order) {
        $seen_name{$attr_name} = 1;
        my %spec = %{$attr_specs->{$attr_name}};
        my %spec_map = (
          map { $_->name => $_->init_arg||$_->name }
          (
            (grep { $_->has_init_arg }
              $meta->attribute_metaclass->meta->get_all_attributes),
            grep { exists($_->{init_arg}) ? defined($_->init_arg) : 1 }
            map {
              my $meta = Moose::Util::resolve_metatrait_alias('Attribute', $_)
                          ->meta;
              map $meta->get_attribute($_), $meta->get_attribute_list
            }  @{$spec{traits}||[]}
          )
        );
        # have to hard code this because Moose's role meta-model is lacking
        $spec_map{traits} ||= 'traits';

        $spec{is} = 'ro' if $spec{is} eq 'lazy' or $spec{is} eq 'rwp';
        my $coerce = $spec{coerce};
        if (my $isa = $spec{isa}) {
          my $tc = $spec{isa} = do {
            if (my $mapped = $TYPE_MAP{$isa}) {
              my $type = $mapped->();
              unless ( Scalar::Util::blessed($type)
                  && $type->isa("Moose::Meta::TypeConstraint") ) {
                croak "error inflating attribute '$attr_name' for package '$name': "
                  ."\$TYPE_MAP{$isa} did not return a valid type constraint'";
              }
              $coerce ? $type->create_child_type(name => $type->name) : $type;
            } else {
              Moose::Meta::TypeConstraint->new(
                constraint => sub { eval { &$isa; 1 } }
              );
            }
          };
          if ($coerce) {
            $tc->coercion(Moose::Meta::TypeCoercion->new)
              ->_compiled_type_coercion($coerce);
            $spec{coerce} = 1;
          }
        } elsif ($coerce) {
          my $attr = quotify($attr_name);
          my $tc = Moose::Meta::TypeConstraint->new(
                    constraint => sub { die "This is not going to work" },
                    inlined => sub {
                        'my $r = $_[42]{'.$attr.'}; $_[42]{'.$attr.'} = 1; $r'
                    },
                  );
          $tc->coercion(Moose::Meta::TypeCoercion->new)
            ->_compiled_type_coercion($coerce);
          $spec{isa} = $tc;
          $spec{coerce} = 1;
        }
        %spec =
          map { $spec_map{$_} => $spec{$_} }
          grep { exists $spec_map{$_} }
          keys %spec;
        push @attrs, $meta->add_attribute($attr_name => %spec);
      }
      foreach my $mouse (do { our %MOUSE; @{$MOUSE{$name}||[]} }) {
        foreach my $attr ($mouse->get_all_attributes) {
          my %spec = %{$attr};
          delete @spec{qw(
            associated_class associated_methods __METACLASS__
            provides curries
          )};
          my $attr_name = delete $spec{name};
          next if $seen_name{$attr_name}++;
          push @attrs, $meta->add_attribute($attr_name => %spec);
        }
      }
    }
    foreach my $meth_name (keys %methods) {
      my $meth_code = $methods{$meth_name};
      $meta->add_method($meth_name, $meth_code);
    }

    if ($am_role) {
      my $info = $Moo::Role::INFO{$name};
      $meta->add_required_methods(@{$info->{requires}});
      foreach my $modifier (@{$info->{modifiers}}) {
        my ($type, @args) = @$modifier;
        my $code = pop @args;
        $meta->${\"add_${type}_method_modifier"}($_, $code) for @args;
      }
    }
    elsif ($am_class) {
      foreach my $attr (@attrs) {
        foreach my $method (@{$attr->associated_methods}) {
          $method->{body} = $name->can($method->name);
        }
      }
      bless(
        $meta->find_method_by_name('new'),
        'Moo::HandleMoose::FakeConstructor',
      );
      my $meta_meth;
      if (
        $meta_meth = $meta->find_method_by_name('meta')
        and $meta_meth->body == \&Moo::Object::meta
      ) {
        bless($meta_meth, 'Moo::HandleMoose::FakeMeta');
      }
      # a combination of Moo and Moose may bypass a Moo constructor but still
      # use a Moo DEMOLISHALL.  We need to make sure this is loaded before
      # global destruction.
      require Method::Generate::DemolishAll;
    }
    $meta->add_role(Class::MOP::class_of($_))
      for grep !/\|/ && $_ ne $name, # reject Foo|Bar and same-role-as-self
        keys %{$Moo::Role::APPLIED_TO{$name}}
  }
  $DID_INJECT{$name} = 1;
  $meta;
}

1;
