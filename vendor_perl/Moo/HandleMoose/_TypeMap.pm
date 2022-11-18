package Moo::HandleMoose::_TypeMap;
use strict;
use warnings;

package
  Moo::HandleMoose;
our %TYPE_MAP;

package Moo::HandleMoose::_TypeMap;

use Scalar::Util ();
use Config ();

BEGIN {
  *_OVERLOAD_ON_REF = "$]" < 5.010000 ? sub(){1} : sub(){0};
}

our %WEAK_TYPES;

sub _str_to_ref {
  my $in = shift;
  return $in
    if ref $in;

  if ($in =~ /(?:^|=)([A-Z]+)\(0x([0-9a-zA-Z]+)\)$/) {
    my $type = $1;
    my $id = do { no warnings 'portable'; hex "$2" };
    require B;
    my $sv = bless \$id, 'B::SV';
    my $ref = eval { $sv->object_2svref };

    if (!defined $ref or Scalar::Util::reftype($ref) ne $type) {
      die <<'END_ERROR';
Moo initialization encountered types defined in a parent thread - ensure that
Moo is require()d before any further thread spawns following a type definition.
END_ERROR
    }

    # on older perls where overloading magic is attached to the ref rather
    # than the ref target, reblessing will pick up the magic
    if (_OVERLOAD_ON_REF and my $class = Scalar::Util::blessed($ref)) {
      bless $ref, $class;
    }

    return $ref;
  }
  return $in;
}

sub TIEHASH  { bless {}, $_[0] }

sub STORE {
  my ($self, $key, $value) = @_;
  my $type = _str_to_ref($key);
  $key = "$type";
  $WEAK_TYPES{$key} = $type;
  Scalar::Util::weaken($WEAK_TYPES{$key})
    if ref $type;
  $self->{$key} = $value;
}

sub FETCH    { $_[0]->{$_[1]} }
sub FIRSTKEY { my $a = scalar keys %{$_[0]}; each %{$_[0]} }
sub NEXTKEY  { each %{$_[0]} }
sub EXISTS   { exists $_[0]->{$_[1]} }
sub DELETE   { delete $_[0]->{$_[1]} }
sub CLEAR    { %{$_[0]} = () }
sub SCALAR   { scalar %{$_[0]} }

sub CLONE {
  my @types = map {
    defined $WEAK_TYPES{$_} ? ($WEAK_TYPES{$_} => $TYPE_MAP{$_}) : ()
  } keys %TYPE_MAP;
  %WEAK_TYPES = ();
  %TYPE_MAP = @types;
}

sub DESTROY {
  my %types = %{$_[0]};
  untie %TYPE_MAP;
  %TYPE_MAP = %types;
}

if ($Config::Config{useithreads}) {
  my @types = %TYPE_MAP;
  tie %TYPE_MAP, __PACKAGE__;
  %TYPE_MAP = @types;
}

1;
