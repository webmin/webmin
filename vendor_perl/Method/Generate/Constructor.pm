package Method::Generate::Constructor;
use strict;
use warnings;

use Sub::Quote qw(quote_sub quotify);
use Sub::Defer;
use Moo::_Utils qw(_getstash _getglob _linear_isa);
use Scalar::Util qw(weaken);
use Carp qw(croak);
use Carp::Heavy ();
BEGIN { our @CARP_NOT = qw(Sub::Defer) }
BEGIN {
  local $Moo::sification::disabled = 1;
  require Moo;
  Moo->import;
}

sub register_attribute_specs {
  my ($self, @new_specs) = @_;
  $self->assert_constructor;
  my $specs = $self->{attribute_specs}||={};
  my $ag = $self->accessor_generator;
  while (my ($name, $new_spec) = splice @new_specs, 0, 2) {
    if ($name =~ s/^\+//) {
      croak "has '+${name}' given but no ${name} attribute already exists"
        unless my $old_spec = $specs->{$name};
      $ag->merge_specs($new_spec, $old_spec);
    }
    if ($new_spec->{required}
      && !(
        $ag->has_default($name, $new_spec)
        || !exists $new_spec->{init_arg}
        || defined $new_spec->{init_arg}
      )
    ) {
      croak "You cannot have a required attribute (${name})"
        . " without a default, builder, or an init_arg";
    }
    $new_spec->{index} = scalar keys %$specs
      unless defined $new_spec->{index};
    $specs->{$name} = $new_spec;
  }
  $self;
}

sub all_attribute_specs {
  $_[0]->{attribute_specs}
}

sub accessor_generator {
  $_[0]->{accessor_generator}
}

sub construction_string {
  my ($self) = @_;
  $self->{construction_string}
    ||= $self->_build_construction_string;
}

sub buildall_generator {
  require Method::Generate::BuildAll;
  Method::Generate::BuildAll->new;
}

sub _build_construction_string {
  my ($self) = @_;
  my $builder = $self->{construction_builder};
  $builder ? $self->$builder
    : 'bless('
    .$self->accessor_generator->default_construction_string
    .', $class);'
}

sub install_delayed {
  my ($self) = @_;
  $self->assert_constructor;
  my $package = $self->{package};
  my (undef, @isa) = @{_linear_isa($package)};
  my $isa = join ',', @isa;
  my (undef, $from_file, $from_line) = caller(Carp::short_error_loc());
  my $constructor = defer_sub "${package}::new" => sub {
    my (undef, @new_isa) = @{_linear_isa($package)};
    if (join(',', @new_isa) ne $isa) {
      my ($expected_new) = grep { *{_getglob($_.'::new')}{CODE} } @isa;
      my ($found_new) = grep { *{_getglob($_.'::new')}{CODE} } @new_isa;
      if (($found_new||'') ne ($expected_new||'')) {
        $found_new ||= 'none';
        $expected_new ||= 'none';
        croak "Expected parent constructor of $package to be"
        . " $expected_new, but found $found_new: changing the inheritance"
        . " chain (\@ISA) at runtime (after $from_file line $from_line) is unsupported";
      }
    }

    my $constructor = $self->generate_method(
      $package, 'new', $self->{attribute_specs}, { no_install => 1, no_defer => 1 }
    );
    $self->{inlined} = 1;
    weaken($self->{constructor} = $constructor);
    $constructor;
  };
  $self->{inlined} = 0;
  weaken($self->{constructor} = $constructor);
  $self;
}

sub current_constructor {
  my ($self, $package) = @_;
  return *{_getglob("${package}::new")}{CODE};
}

sub assert_constructor {
  my ($self) = @_;
  my $package = $self->{package} or return 1;
  my $current = $self->current_constructor($package)
    or return 1;
  my $constructor = $self->{constructor}
    or croak "Unknown constructor for $package already exists";
  croak "Constructor for $package has been replaced with an unknown sub"
    if $constructor != $current;
  croak "Constructor for $package has been inlined and cannot be updated"
    if $self->{inlined};
}

sub generate_method {
  my ($self, $into, $name, $spec, $quote_opts) = @_;
  $quote_opts = {
    %{$quote_opts||{}},
    package => $into,
  };
  foreach my $no_init (grep !exists($spec->{$_}{init_arg}), keys %$spec) {
    $spec->{$no_init}{init_arg} = $no_init;
  }
  local $self->{captures} = {};

  my $into_buildargs = $into->can('BUILDARGS');

  my $body
    = '    my $invoker = CORE::shift();'."\n"
    . '    my $class = CORE::ref($invoker) ? CORE::ref($invoker) : $invoker;'."\n"
    . $self->_handle_subconstructor($into, $name)
    . ( $into_buildargs && $into_buildargs != \&Moo::Object::BUILDARGS
      ? $self->_generate_args_via_buildargs
      : $self->_generate_args
    )
    . $self->_check_required($spec)
    . '    my $new = '.$self->construction_string.";\n"
    . $self->_assign_new($spec)
    . ( $into->can('BUILD')
      ? $self->buildall_generator->buildall_body_for( $into, '$new', '$args' )
      : ''
    )
    . '    return $new;'."\n";

  if ($into->can('DEMOLISH')) {
    require Method::Generate::DemolishAll;
    Method::Generate::DemolishAll->new->generate_method($into);
  }
  quote_sub
    "${into}::${name}" => $body,
    $self->{captures}, $quote_opts||{}
  ;
}

sub _handle_subconstructor {
  my ($self, $into, $name) = @_;
  if (my $gen = $self->{subconstructor_handler}) {
    '    if ($class ne '.quotify($into).') {'."\n".
    $gen.
    '    }'."\n";
  } else {
    ''
  }
}

sub _cap_call {
  my ($self, $code, $captures) = @_;
  @{$self->{captures}}{keys %$captures} = values %$captures if $captures;
  $code;
}

sub _generate_args_via_buildargs {
  my ($self) = @_;
  q{    my $args = $class->BUILDARGS(@_);}."\n"
  .q{    Carp::croak("BUILDARGS did not return a hashref") unless CORE::ref($args) eq 'HASH';}
  ."\n";
}

# inlined from Moo::Object - update that first.
sub _generate_args {
  my ($self) = @_;
  return <<'_EOA';
    my $args = scalar @_ == 1
      ? CORE::ref $_[0] eq 'HASH'
        ? { %{ $_[0] } }
        : Carp::croak("Single parameters to new() must be a HASH ref"
            . " data => ". $_[0])
      : @_ % 2
        ? Carp::croak("The new() method for $class expects a hash reference or a"
            . " key/value list. You passed an odd number of arguments")
        : {@_}
    ;
_EOA

}

sub _assign_new {
  my ($self, $spec) = @_;
  my $ag = $self->accessor_generator;
  my %test;
  NAME: foreach my $name (sort keys %$spec) {
    my $attr_spec = $spec->{$name};
    next NAME unless defined($attr_spec->{init_arg})
                       or $ag->has_eager_default($name, $attr_spec);
    $test{$name} = $attr_spec->{init_arg};
  }
  join '', map {
    my $arg = $test{$_};
    my $arg_key = quotify($arg);
    my $test = defined $arg ? "exists \$args->{$arg_key}" : undef;
    my $source = defined $arg ? "\$args->{$arg_key}" : undef;
    my $attr_spec = $spec->{$_};
    $self->_cap_call($ag->generate_populate_set(
      '$new', $_, $attr_spec, $source, $test, $arg,
    ));
  } sort keys %test;
}

sub _check_required {
  my ($self, $spec) = @_;
  my @required_init =
    map $spec->{$_}{init_arg},
      grep {
        my $s = $spec->{$_}; # ignore required if default or builder set
        $s->{required} and not($s->{builder} or exists $s->{default})
      } sort keys %$spec;
  return '' unless @required_init;
  '    if (my @missing = grep !exists $args->{$_}, '
    .join(', ', map quotify($_), @required_init).') {'."\n"
    .q{      Carp::croak("Missing required arguments: ".CORE::join(', ', sort @missing));}."\n"
    ."    }\n";
}

# bootstrap our own constructor
sub new {
  my $class = shift;
  delete _getstash(__PACKAGE__)->{new};
  bless $class->BUILDARGS(@_), $class;
}
Moo->_constructor_maker_for(__PACKAGE__)
->register_attribute_specs(
  attribute_specs => {
    is => 'ro',
    reader => 'all_attribute_specs',
  },
  accessor_generator => { is => 'ro' },
  construction_string => { is => 'lazy' },
  construction_builder => { is => 'bare' },
  subconstructor_handler => { is => 'ro' },
  package => { is => 'bare' },
);
if ($INC{'Moo/HandleMoose.pm'} && !$Moo::sification::disabled) {
  Moo::HandleMoose::inject_fake_metaclass_for(__PACKAGE__);
}

1;
