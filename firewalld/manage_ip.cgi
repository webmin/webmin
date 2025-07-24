#!/usr/local/bin/perl
# Block given IP

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './firewalld-lib.pl';
our (%in, %text, %config);
&ReadParse();

# Setup error messages
my $allow = $in{'allow'} ? 1 : 0;

# Get the type
&error_setup($allow ? $text{'allow_err'} : $text{'block_err'});

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
my $timeout = $config{'timeout'} unless ($perm && $config{'timeout'});
my ($out, $rs) = &rich_rule('add',
	{ 'rule' =>
		&construct_rich_rule(
			'source address' => "$ip$mask",
			'action' => $allow ? 'accept' : undef,
			'priority' => $allow ? -32767 : -32766,
		),
	  'zone' => $zone->{'name'}, 'permanent' => $perm,
	  'timeout' => $timeout });
&error($out) if ($rs);
&apply_firewalld() if ($perm);

&webmin_log("ip", "${perm}block", "$ip$mask");
&redirect("index.cgi?zone=".&urlize($zone->{'name'}));
