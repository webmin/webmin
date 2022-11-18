package Method::Generate::Accessor;
use strict;
use warnings;

use Moo::_Utils qw(_maybe_load_module _install_coderef _module_name_rx);
use Moo::Object ();
BEGIN { our @ISA = qw(Moo::Object) }
use Sub::Quote qw(quote_sub quoted_from_sub quotify sanitize_identifier);
use Scalar::Util 'blessed';
use Carp qw(croak);
BEGIN {
  our @CARP_NOT = qw(
    Moo::_Utils
    Moo::Object
    Moo::Role
  );
}
BEGIN {
  *_CAN_WEAKEN_READONLY = (
    "$]" < 5.008_003 or $ENV{MOO_TEST_PRE_583}
  ) ? sub(){0} : sub(){1};
  our $CAN_HAZ_XS =
    !$ENV{MOO_XS_DISABLE}
      &&
    _maybe_load_module('Class::XSAccessor')
      &&
    (eval { Class::XSAccessor->VERSION('1.07') })
  ;
  our $CAN_HAZ_XS_PRED =
    $CAN_HAZ_XS &&
    (eval { Class::XSAccessor->VERSION('1.17') })
  ;
}
BEGIN {
  package
    Method::Generate::Accessor::_Generated;
  $Carp::Internal{+__PACKAGE__} = 1;
}

sub _die_overwrite {
  my ($pkg, $method, $type) = @_;
  croak "You cannot overwrite a locally defined method ($method) with "
    . ( $type || 'an accessor' );
}

sub generate_method {
  my ($self, $into, $name, $spec, $quote_opts) = @_;
  $quote_opts = {
    no_defer => 1,
    package => 'Method::Generate::Accessor::_Generated',
    %{ $quote_opts||{} },
  };
  $spec->{allow_overwrite}++ if $name =~ s/^\+//;
  croak "Must have an is" unless my $is = $spec->{is};
  if ($is eq 'ro') {
    $spec->{reader} = $name unless exists $spec->{reader};
  } elsif ($is eq 'rw') {
    $spec->{accessor} = $name unless exists $spec->{accessor}
      or ( $spec->{reader} and $spec->{writer} );
  } elsif ($is eq 'lazy') {
    $spec->{reader} = $name unless exists $spec->{reader};
    $spec->{lazy} = 1;
    $spec->{builder} ||= '_build_'.$name unless exists $spec->{default};
  } elsif ($is eq 'rwp') {
    $spec->{reader} = $name unless exists $spec->{reader};
    $spec->{writer} = "_set_${name}" unless exists $spec->{writer};
  } elsif ($is ne 'bare') {
    croak "Unknown is ${is}";
  }
  if (exists $spec->{builder}) {
    if(ref $spec->{builder}) {
      $self->_validate_codulatable('builder', $spec->{builder},
        "$into->$name", 'or a method name');
      $spec->{builder_sub} = $spec->{builder};
      $spec->{builder} = 1;
    }
    $spec->{builder} = '_build_'.$name if ($spec->{builder}||0) eq 1;
    croak "Invalid builder for $into->$name - not a valid method name"
      if $spec->{builder} !~ _module_name_rx;
  }
  if (($spec->{predicate}||0) eq 1) {
    $spec->{predicate} = $name =~ /^_/ ? "_has${name}" : "has_${name}";
  }
  if (($spec->{clearer}||0) eq 1) {
    $spec->{clearer} = $name =~ /^_/ ? "_clear${name}" : "clear_${name}";
  }
  if (($spec->{trigger}||0) eq 1) {
    $spec->{trigger} = quote_sub('shift->_trigger_'.$name.'(@_)');
  }
  if (($spec->{coerce}||0) eq 1) {
    my $isa = $spec->{isa};
    if (blessed $isa and $isa->can('coercion')) {
      $spec->{coerce} = $isa->coercion;
    } elsif (blessed $isa and $isa->can('coerce')) {
      $spec->{coerce} = sub { $isa->coerce(@_) };
    } else {
      croak "Invalid coercion for $into->$name - no appropriate type constraint";
    }
  }

  foreach my $setting (qw( isa coerce )) {
    next if !exists $spec->{$setting};
    $self->_validate_codulatable($setting, $spec->{$setting}, "$into->$name");
  }

  if (exists $spec->{default}) {
    if (ref $spec->{default}) {
      $self->_validate_codulatable('default', $spec->{default}, "$into->$name",
        'or a non-ref');
    }
  }

  if (exists $spec->{moosify}) {
    if (ref $spec->{moosify} ne 'ARRAY') {
      $spec->{moosify} = [$spec->{moosify}];
    }

    foreach my $spec (@{$spec->{moosify}}) {
      $self->_validate_codulatable('moosify', $spec, "$into->$name");
    }
  }

  my %methods;
  if (my $reader = $spec->{reader}) {
    _die_overwrite($into, $reader, 'a reader')
      if !$spec->{allow_overwrite} && defined &{"${into}::${reader}"};
    if (our $CAN_HAZ_XS && $self->is_simple_get($name, $spec)) {
      $methods{$reader} = $self->_generate_xs(
        getters => $into, $reader, $name, $spec
      );
    } else {
      $self->{captures} = {};
      $methods{$reader} =
        quote_sub "${into}::${reader}"
          => '    Carp::croak("'.$reader.' is a read-only accessor") if @_ > 1;'."\n"
             .$self->_generate_get($name, $spec)
          => delete $self->{captures}
          => $quote_opts
        ;
    }
  }
  if (my $accessor = $spec->{accessor}) {
    _die_overwrite($into, $accessor, 'an accessor')
      if !$spec->{allow_overwrite} && defined &{"${into}::${accessor}"};
    if (
      our $CAN_HAZ_XS
      && $self->is_simple_get($name, $spec)
      && $self->is_simple_set($name, $spec)
    ) {
      $methods{$accessor} = $self->_generate_xs(
        accessors => $into, $accessor, $name, $spec
      );
    } else {
      $self->{captures} = {};
      $methods{$accessor} =
        quote_sub "${into}::${accessor}"
          => $self->_generate_getset($name, $spec)
          => delete $self->{captures}
          => $quote_opts
        ;
    }
  }
  if (my $writer = $spec->{writer}) {
    _die_overwrite($into, $writer, 'a writer')
      if !$spec->{allow_overwrite} && defined &{"${into}::${writer}"};
    if (
      our $CAN_HAZ_XS
      && $self->is_simple_set($name, $spec)
    ) {
      $methods{$writer} = $self->_generate_xs(
        setters => $into, $writer, $name, $spec
      );
    } else {
      $self->{captures} = {};
      $methods{$writer} =
        quote_sub "${into}::${writer}"
          => $self->_generate_set($name, $spec)
          => delete $self->{captures}
          => $quote_opts
        ;
    }
  }
  if (my $pred = $spec->{predicate}) {
    _die_overwrite($into, $pred, 'a predicate')
      if !$spec->{allow_overwrite} && defined &{"${into}::${pred}"};
    if (our $CAN_HAZ_XS && our $CAN_HAZ_XS_PRED) {
      $methods{$pred} = $self->_generate_xs(
        exists_predicates => $into, $pred, $name, $spec
      );
    } else {
      $self->{captures} = {};
      $methods{$pred} =
        quote_sub "${into}::${pred}"
          => $self->_generate_simple_has('$_[0]', $name, $spec)."\n"
          => delete $self->{captures}
          => $quote_opts
        ;
    }
  }
  if (my $builder = delete $spec->{builder_sub}) {
    _install_coderef( "${into}::$spec->{builder}" => $builder );
  }
  if (my $cl = $spec->{clearer}) {
    _die_overwrite($into, $cl, 'a clearer')
      if !$spec->{allow_overwrite} && defined &{"${into}::${cl}"};
    $self->{captures} = {};
    $methods{$cl} =
      quote_sub "${into}::${cl}"
        => $self->_generate_simple_clear('$_[0]', $name, $spec)."\n"
        => delete $self->{captures}
        => $quote_opts
      ;
  }
  if (my $hspec = $spec->{handles}) {
    my $asserter = $spec->{asserter} ||= '_assert_'.$name;
    my @specs = do {
      if (ref($hspec) eq 'ARRAY') {
        map [ $_ => $_ ], @$hspec;
      } elsif (ref($hspec) eq 'HASH') {
        map [ $_ => ref($hspec->{$_}) ? @{$hspec->{$_}} : $hspec->{$_} ],
          keys %$hspec;
      } elsif (!ref($hspec)) {
        require Moo::Role;
        map [ $_ => $_ ], Moo::Role->methods_provided_by($hspec)
      } else {
        croak "You gave me a handles of ${hspec} and I have no idea why";
      }
    };
    foreach my $delegation_spec (@specs) {
      my ($proxy, $target, @args) = @$delegation_spec;
      _die_overwrite($into, $proxy, 'a delegation')
        if !$spec->{allow_overwrite} && defined &{"${into}::${proxy}"};
      $self->{captures} = {};
      $methods{$proxy} =
        quote_sub "${into}::${proxy}"
          => $self->_generate_delegation($asserter, $target, \@args)
          => delete $self->{captures}
          => $quote_opts
        ;
    }
  }
  if (my $asserter = $spec->{asserter}) {
    _die_overwrite($into, $asserter, 'an asserter')
      if !$spec->{allow_overwrite} && defined &{"${into}::${asserter}"};
    local $self->{captures} = {};
    $methods{$asserter} =
      quote_sub "${into}::${asserter}"
        => $self->_generate_asserter($name, $spec)
        => delete $self->{captures}
        => $quote_opts
      ;
  }
  \%methods;
}

sub merge_specs {
  my ($self, @specs) = @_;
  my $spec = shift @specs;
  for my $old_spec (@specs) {
    foreach my $key (keys %$old_spec) {
      if ($key eq 'handles') {
      }
      elsif ($key eq 'moosify') {
        $spec->{$key} = [
          map { ref $_ eq 'ARRAY' ? @$_ : $_ }
          grep defined,
          ($old_spec->{$key}, $spec->{$key})
        ];
      }
      elsif ($key eq 'builder' || $key eq 'default') {
        $spec->{$key} = $old_spec->{$key}
          if !(exists $spec->{builder} || exists $spec->{default});
      }
      elsif (!exists $spec->{$key}) {
        $spec->{$key} = $old_spec->{$key};
      }
    }
  }
  $spec;
}

sub is_simple_attribute {
  my ($self, $name, $spec) = @_;
  # clearer doesn't have to be listed because it doesn't
  # affect whether defined/exists makes a difference
  !grep $spec->{$_},
    qw(lazy default builder coerce isa trigger predicate weak_ref);
}

sub is_simple_get {
  my ($self, $name, $spec) = @_;
  !($spec->{lazy} and (exists $spec->{default} or $spec->{builder}));
}

sub is_simple_set {
  my ($self, $name, $spec) = @_;
  !grep $spec->{$_}, qw(coerce isa trigger weak_ref);
}

sub has_default {
  my ($self, $name, $spec) = @_;
  $spec->{builder} or exists $spec->{default} or (($spec->{is}||'') eq 'lazy');
}

sub has_eager_default {
  my ($self, $name, $spec) = @_;
  (!$spec->{lazy} and (exists $spec->{default} or $spec->{builder}));
}

sub _generate_get {
  my ($self, $name, $spec) = @_;
  my $simple = $self->_generate_simple_get('$_[0]', $name, $spec);
  if ($self->is_simple_get($name, $spec)) {
    $simple;
  } else {
    $self->_generate_use_default(
      '$_[0]', $name, $spec,
      $self->_generate_simple_has('$_[0]', $name, $spec),
    );
  }
}

sub generate_simple_has {
  my $self = shift;
  $self->{captures} = {};
  my $code = $self->_generate_simple_has(@_);
  ($code, delete $self->{captures});
}

sub _generate_simple_has {
  my ($self, $me, $name) = @_;
  "exists ${me}->{${\quotify $name}}";
}

sub _generate_simple_clear {
  my ($self, $me, $name) = @_;
  "    delete ${me}->{${\quotify $name}}\n"
}

sub generate_get_default {
  my $self = shift;
  $self->{captures} = {};
  my $code = $self->_generate_get_default(@_);
  ($code, delete $self->{captures});
}

sub generate_use_default {
  my $self = shift;
  $self->{captures} = {};
  my $code = $self->_generate_use_default(@_);
  ($code, delete $self->{captures});
}

sub _generate_use_default {
  my ($self, $me, $name, $spec, $test) = @_;
  my $get_value = $self->_generate_get_default($me, $name, $spec);
  if ($spec->{coerce}) {
    $get_value = $self->_generate_coerce(
      $name, $get_value,
      $spec->{coerce}
    )
  }
  $test." ? \n"
  .$self->_generate_simple_get($me, $name, $spec)."\n:"
  .($spec->{isa} ?
       "    do {\n      my \$value = ".$get_value.";\n"
      ."      ".$self->_generate_isa_check($name, '$value', $spec->{isa}).";\n"
      ."      ".$self->_generate_simple_set($me, $name, $spec, '$value')."\n"
      ."    }\n"
    : '    ('.$self->_generate_simple_set($me, $name, $spec, $get_value).")\n"
  );
}

sub _generate_get_default {
  my ($self, $me, $name, $spec) = @_;
  if (exists $spec->{default}) {
    ref $spec->{default}
      ? $self->_generate_call_code($name, 'default', $me, $spec->{default})
    : quotify $spec->{default};
  }
  else {
    "${me}->${\$spec->{builder}}"
  }
}

sub generate_simple_get {
  my ($self, @args) = @_;
  $self->{captures} = {};
  my $code = $self->_generate_simple_get(@args);
  ($code, delete $self->{captures});
}

sub _generate_simple_get {
  my ($self, $me, $name) = @_;
  my $name_str = quotify $name;
  "${me}->{${name_str}}";
}

sub _generate_set {
  my ($self, $name, $spec) = @_;
  my ($me, $source) = ('$_[0]', '$_[1]');
  if ($self->is_simple_set($name, $spec)) {
    return $self->_generate_simple_set($me, $name, $spec, $source);
  }

  my ($coerce, $trigger, $isa_check) = @{$spec}{qw(coerce trigger isa)};
  if ($coerce) {
    $source = $self->_generate_coerce($name, $source, $coerce);
  }
  if ($isa_check) {
    'scalar do { my $value = '.$source.";\n"
    .'  ('.$self->_generate_isa_check($name, '$value', $isa_check)."),\n"
    .'  ('.$self->_generate_simple_set($me, $name, $spec, '$value')."),\n"
    .($trigger
      ? '('.$self->_generate_trigger($name, $me, '$value', $trigger)."),\n"
      : '')
    .'  ('.$self->_generate_simple_get($me, $name, $spec)."),\n"
    ."}";
  }
  elsif ($trigger) {
    my $set = $self->_generate_simple_set($me, $name, $spec, $source);
    "scalar (\n"
    . '  ('.$self->_generate_trigger($name, $me, "($set)", $trigger)."),\n"
    . '  ('.$self->_generate_simple_get($me, $name, $spec)."),\n"
    . ")";
  }
  else {
    '('.$self->_generate_simple_set($me, $name, $spec, $source).')';
  }
}

sub generate_coerce {
  my $self = shift;
  $self->{captures} = {};
  my $code = $self->_generate_coerce(@_);
  ($code, delete $self->{captures});
}

sub _attr_desc {
  my ($name, $init_arg) = @_;
  return quotify($name) if !defined($init_arg) or $init_arg eq $name;
  return quotify($name).' (constructor argument: '.quotify($init_arg).')';
}

sub _generate_coerce {
  my ($self, $name, $value, $coerce, $init_arg) = @_;
  $self->_wrap_attr_exception(
    $name,
    "coercion",
    $init_arg,
    $self->_generate_call_code($name, 'coerce', "${value}", $coerce),
    1,
  );
}

sub generate_trigger {
  my $self = shift;
  $self->{captures} = {};
  my $code = $self->_generate_trigger(@_);
  ($code, delete $self->{captures});
}

sub _generate_trigger {
  my ($self, $name, $obj, $value, $trigger) = @_;
  $self->_generate_call_code($name, 'trigger', "${obj}, ${value}", $trigger);
}

sub generate_isa_check {
  my ($self, @args) = @_;
  $self->{captures} = {};
  my $code = $self->_generate_isa_check(@args);
  ($code, delete $self->{captures});
}

sub _wrap_attr_exception {
  my ($self, $name, $step, $arg, $code, $want_return) = @_;
  my $prefix = quotify("${step} for "._attr_desc($name, $arg).' failed: ');
  "do {\n"
  .'  local $Method::Generate::Accessor::CurrentAttribute = {'."\n"
  .'    init_arg => '.quotify($arg).",\n"
  .'    name     => '.quotify($name).",\n"
  .'    step     => '.quotify($step).",\n"
  ."  };\n"
  .($want_return ? '  (my $_return),'."\n" : '')
  .'  (my $_error), (my $_old_error = $@);'."\n"
  ."  (eval {\n"
  .'    ($@ = $_old_error),'."\n"
  .'    ('
  .($want_return ? '$_return ='."\n" : '')
  .$code."),\n"
  ."    1\n"
  ."  } or\n"
  .'    $_error = CORE::ref $@ ? $@ : '.$prefix.'.$@);'."\n"
  .'  ($@ = $_old_error),'."\n"
  .'  (defined $_error and CORE::die $_error);'."\n"
  .($want_return ? '  $_return;'."\n" : '')
  ."}\n"
}

sub _generate_isa_check {
  my ($self, $name, $value, $check, $init_arg) = @_;
  $self->_wrap_attr_exception(
    $name,
    "isa check",
    $init_arg,
    $self->_generate_call_code($name, 'isa_check', $value, $check)
  );
}

sub _generate_call_code {
  my ($self, $name, $type, $values, $sub) = @_;
  $sub = \&{$sub} if blessed($sub);  # coderef if blessed
  if (my $quoted = quoted_from_sub($sub)) {
    my $local = 1;
    if ($values eq '@_' || $values eq '$_[0]') {
      $local = 0;
      $values = '@_';
    }
    my $code = $quoted->[1];
    if (my $captures = $quoted->[2]) {
      my $cap_name = qq{\$${type}_captures_for_}.sanitize_identifier($name);
      $self->{captures}->{$cap_name} = \$captures;
      Sub::Quote::inlinify($code, $values,
        Sub::Quote::capture_unroll($cap_name, $captures, 6), $local);
    } else {
      Sub::Quote::inlinify($code, $values, undef, $local);
    }
  } else {
    my $cap_name = qq{\$${type}_for_}.sanitize_identifier($name);
    $self->{captures}->{$cap_name} = \$sub;
    "${cap_name}->(${values})";
  }
}

sub _sanitize_name { sanitize_identifier($_[1]) }

sub generate_populate_set {
  my $self = shift;
  $self->{captures} = {};
  my $code = $self->_generate_populate_set(@_);
  ($code, delete $self->{captures});
}

sub _generate_populate_set {
  my ($self, $me, $name, $spec, $source, $test, $init_arg) = @_;

  my $has_default = $self->has_eager_default($name, $spec);
  if (!($has_default || $test)) {
    return '';
  }
  if ($has_default) {
    my $get_default = $self->_generate_get_default($me, $name, $spec);
    $source =
      $test
        ? "(\n  ${test}\n"
            ."   ? ${source}\n   : "
            .$get_default
            .")"
        : $get_default;
  }
  if ($spec->{coerce}) {
    $source = $self->_generate_coerce(
      $name, $source,
      $spec->{coerce}, $init_arg
    )
  }
  if ($spec->{isa}) {
    $source = 'scalar do { my $value = '.$source.";\n"
    .'  ('.$self->_generate_isa_check(
        $name, '$value', $spec->{isa}, $init_arg
      )."),\n"
    ."  \$value\n"
    ."}\n";
  }
  my $set = $self->_generate_simple_set($me, $name, $spec, $source);
  my $trigger = $spec->{trigger} ? $self->_generate_trigger(
    $name, $me, $self->_generate_simple_get($me, $name, $spec),
    $spec->{trigger}
  ) : undef;
  if ($has_default) {
    "($set)," . ($trigger && $test ? "($test and $trigger)," : '') . "\n";
  }
  else {
    "($test and ($set)" . ($trigger ? ", ($trigger)" : '') . "),\n";
  }
}

sub _generate_core_set {
  my ($self, $me, $name, $spec, $value) = @_;
  my $name_str = quotify $name;
  "${me}->{${name_str}} = ${value}";
}

sub _generate_simple_set {
  my ($self, $me, $name, $spec, $value) = @_;
  my $name_str = quotify $name;
  my $simple = $self->_generate_core_set($me, $name, $spec, $value);

  if ($spec->{weak_ref}) {
    require Scalar::Util;
    my $get = $self->_generate_simple_get($me, $name, $spec);

    # Perl < 5.8.3 can't weaken refs to readonly vars
    # (e.g. string constants). This *can* be solved by:
    #
    # &Internals::SvREADONLY($foo, 0);
    # Scalar::Util::weaken($foo);
    # &Internals::SvREADONLY($foo, 1);
    #
    # but requires Internal functions and is just too damn crazy
    # so simply throw a better exception
    my $weak_simple = _CAN_WEAKEN_READONLY
      ? "do { Scalar::Util::weaken(${simple}); no warnings 'void'; $get }"
      : <<"EOC"
        ( eval { Scalar::Util::weaken($simple); 1 }
          ? do { no warnings 'void'; $get }
          : do {
            if( \$@ =~ /Modification of a read-only value attempted/) {
              require Carp;
              Carp::croak( sprintf (
                'Reference to readonly value in "%s" can not be weakened on Perl < 5.8.3',
                $name_str,
              ) );
            } else {
              die \$@;
            }
          }
        )
EOC
  } else {
    $simple;
  }
}

sub _generate_getset {
  my ($self, $name, $spec) = @_;
  q{(@_ > 1}."\n      ? ".$self->_generate_set($name, $spec)
    ."\n      : ".$self->_generate_get($name, $spec)."\n    )";
}

sub _generate_asserter {
  my ($self, $name, $spec) = @_;
  my $name_str = quotify($name);
  "do {\n"
   ."  my \$val = ".$self->_generate_get($name, $spec).";\n"
   ."  ".$self->_generate_simple_has('$_[0]', $name, $spec)."\n"
   ."    or Carp::croak(q{Attempted to access '}.${name_str}.q{' but it is not set});\n"
   ."  \$val;\n"
   ."}\n";
}
sub _generate_delegation {
  my ($self, $asserter, $target, $args) = @_;
  my $arg_string = do {
    if (@$args) {
      # I could, I reckon, linearise out non-refs here using quotify
      # plus something to check for numbers but I'm unsure if it's worth it
      $self->{captures}{'@curries'} = $args;
      '@curries, @_';
    } else {
      '@_';
    }
  };
  "shift->${asserter}->${target}(${arg_string});";
}

sub _generate_xs {
  my ($self, $type, $into, $name, $slot) = @_;
  Class::XSAccessor->import(
    class => $into,
    $type => { $name => $slot },
    replace => 1,
  );
  $into->can($name);
}

sub default_construction_string { '{}' }

sub _validate_codulatable {
  my ($self, $setting, $value, $into, $appended) = @_;

  my $error;

  if (blessed $value) {
    local $@;
    no warnings 'void';
    eval { \&$value; 1 }
      and return 1;
    $error = "could not be converted to a coderef: $@";
  }
  elsif (ref $value eq 'CODE') {
    return 1;
  }
  else {
    $error = 'is not a coderef or code-convertible object';
  }

  croak "Invalid $setting '"
    . ($INC{'overload.pm'} ? overload::StrVal($value) : $value)
    . "' for $into " . $error
    . ($appended ? " $appended" : '');
}

1;
