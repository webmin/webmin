package Method::Generate::DemolishAll;
use strict;
use warnings;

use Moo::Object ();
BEGIN { our @ISA = qw(Moo::Object) }
use Sub::Quote qw(quote_sub quotify);
use Moo::_Utils qw(_getglob _linear_isa _in_global_destruction_code);

sub generate_method {
  my ($self, $into) = @_;
  quote_sub "${into}::DEMOLISHALL", join '',
    $self->_handle_subdemolish($into),
    qq{    my \$self = shift;\n},
    $self->demolishall_body_for($into, '$self', '@_'),
    qq{    return \$self\n};
  quote_sub "${into}::DESTROY",
    sprintf <<'END_CODE', $into, _in_global_destruction_code;
    my $self = shift;
    my $e;
    {
      local $?;
      local $@;
      package %s;
      eval {
        $self->DEMOLISHALL(%s);
        1;
      } or $e = $@;
    }

    # fatal warnings+die in DESTROY = bad times (perl rt#123398)
    no warnings FATAL => 'all';
    use warnings 'all';
    die $e if defined $e; # rethrow
END_CODE
}

sub demolishall_body_for {
  my ($self, $into, $me, $args) = @_;
  my @demolishers =
    grep *{_getglob($_)}{CODE},
    map "${_}::DEMOLISH",
    @{_linear_isa($into)};
  join '',
    qq{    package $into;\n},
    map qq{    ${me}->${_}(${args});\n}, @demolishers;
}

sub _handle_subdemolish {
  my ($self, $into) = @_;
  '    if (ref($_[0]) ne '.quotify($into).') {'."\n".
  "      package $into;\n".
  '      return shift->Moo::Object::DEMOLISHALL(@_)'.";\n".
  '    }'."\n";
}

1;
