#!/usr/local/bin/perl
# Update interface ports

use strict;
use warnings;
require 'firewalld-lib.pl';
our (%in, %text);
&error_setup($text{'ifaces_err'});
&ReadParse();

# Get the zone
my @zones = &list_firewalld_zones();
my ($zone) = grep { $_->{'name'} eq $in{'zone'} } @zones;
$zone || &error($text{'port_ezone'});

# 
