package Moo::sification;
use strict;
use warnings;
no warnings 'once';

use Carp qw(croak);
BEGIN { our @CARP_NOT = qw(Moo::HandleMoose) }
use Moo::_Utils qw(_in_global_destruction);

sub unimport {
  croak "Can't disable Moo::sification after inflation has been done"
    if $Moo::HandleMoose::SETUP_DONE;
  our $disabled = 1;
}

sub Moo::HandleMoose::AuthorityHack::DESTROY {
  unless (our $disabled or _in_global_destruction) {
    require Moo::HandleMoose;
    Moo::HandleMoose->import;
  }
}

sub import {
  return
    if our $setup_done;
  if ($INC{"Moose.pm"}) {
    require Moo::HandleMoose;
    Moo::HandleMoose->import;
  } else {
    $Moose::AUTHORITY = bless({}, 'Moo::HandleMoose::AuthorityHack');
  }
  $setup_done = 1;
}

1;
