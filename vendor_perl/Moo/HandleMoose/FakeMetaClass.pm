package Moo::HandleMoose::FakeMetaClass;
use strict;
use warnings;

use Carp ();
BEGIN { our @CARP_NOT = qw(Moo::HandleMoose) }

sub DESTROY { }

sub AUTOLOAD {
  my ($meth) = (our $AUTOLOAD =~ /([^:]+)$/);
  my $self = shift;
  Carp::croak "Can't call $meth without object instance"
    if !ref $self;
  Carp::croak "Can't inflate Moose metaclass with Moo::sification disabled"
    if $Moo::sification::disabled;
  require Moo::HandleMoose;
  Moo::HandleMoose::inject_real_metaclass_for($self->{name})->$meth(@_)
}
sub can {
  my $self = shift;
  return $self->SUPER::can(@_)
    if !ref $self or $Moo::sification::disabled;
  require Moo::HandleMoose;
  Moo::HandleMoose::inject_real_metaclass_for($self->{name})->can(@_)
}
sub isa {
  my $self = shift;
  return $self->SUPER::isa(@_)
    if !ref $self or $Moo::sification::disabled;

  # prevent inflation by Devel::StackTrace, which does this check.  examining
  # the stack trace in an exception from inflation could re-trigger inflation
  # and cause another exception.
  return !!0
    if @_ == 1 && $_[0] eq 'Exception::Class::Base';

  require Moo::HandleMoose;
  Moo::HandleMoose::inject_real_metaclass_for($self->{name})->isa(@_)
}
sub make_immutable { $_[0] }

1;
