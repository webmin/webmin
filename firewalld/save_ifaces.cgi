#!/usr/local/bin/perl
# Update interface ports

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './firewalld-lib.pl';
our (%in, %text);
&error_setup($text{'ifaces_err'});
&ReadParse();

# Get the zone
my @zones = &list_firewalld_zones();
my ($zone) = grep { $_->{'name'} eq $in{'zone'} } @zones;
$zone || &error($text{'port_ezone'});

# Update the interfaces list 
my @ifaces = $in{'iface_def'} ? ( ) : split(/\0/, $in{'iface'});
my $err = &update_zone_interfaces($zone, \@ifaces);
&error($err) if ($err);

&webmin_log("ifaces", "zone", $zone->{'name'});
&redirect("index.cgi?zone=".&urlize($zone->{'name'}));
