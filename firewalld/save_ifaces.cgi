#!/usr/local/bin/perl
# Update interface ports

use strict;
use warnings;
require './firewalld-lib.pl';
our (%in, %text);
&error_setup($text{'ifaces_err'});
&ReadParse();

# Get the zone
my @zones = &list_firewalld_zones();
my ($zone) = grep { $_->{'name'} eq $in{'zone'} } @zones;
$zone || &error($text{'port_ezone'});

# Update the interfaces list 
my $err = &update_zone_interfaces($zone, [ split(/\0/, $in{'iface'}) ]);
&error($err) if ($err);

&webmin_log("ifaces", "zone", $zone->{'name'});
&redirect("index.cgi?zone=".&urlize($zone->{'name'}));
