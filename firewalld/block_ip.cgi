#!/usr/local/bin/perl
# Block given IP

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './firewalld-lib.pl';
our (%in, %text);
&error_setup($text{'block_err'});
&ReadParse();

# Get the zone
my @zones = &list_firewalld_zones();
my ($zone) = grep { $_->{'name'} eq $in{'zone'} } @zones;
$zone || &error($text{'port_ezone'});

# Get the IP
my $ip = $in{'ip'};
$ip || &error($text{'block_eip'});

# Validate the IPv4 or IPv6 address/mask
my $mask = $ip =~ s/(\/\d+)$// ? $1 : "";
$ip =~ s/\Q$mask\E// if ($mask);
&check_ipaddress($ip) || &check_ip6address($ip) || &error($text{'block_eip'});

# Block the IP
my $perm = $in{'permanent'} ? 'perm' : '';
my $err = &block_ip("$ip$mask", $zone->{'name'}, $perm);
&error($err) if ($err);

&webmin_log("ip", "${perm}block", "$ip$mask");
&redirect("index.cgi?zone=".&urlize($zone->{'name'}));
