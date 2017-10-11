#!/usr/local/bin/perl
# Make a zone the default

use strict;
use warnings;
require './firewalld-lib.pl';
our (%text, %in);
&ReadParse();
&error_setup($text{'defzone_err'});

# Get the zone
my @zones = &list_firewalld_zones();
my ($zone) = grep { $_->{'name'} eq $in{'zone'} } @zones;
$zone || &error($text{'port_ezone'});

# Make the default
my $err = &default_firewalld_zone($zone);
&error($err) if ($err);

&webmin_log("default", "zone", $zone->{'name'});
&redirect("index.cgi?zone=".&urlize($zone->{'name'}));
