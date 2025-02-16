#!/usr/local/bin/perl
# Create, update or delete a forwarding rule

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './firewalld-lib.pl';
our (%in, %text);
&error_setup($text{'forward_err'});
&ReadParse();

# Get the zone and rule
my @zones = &list_firewalld_zones();
my ($zone) = grep { $_->{'name'} eq $in{'zone'} } @zones;
$zone || &error($text{'port_ezone'});
my ($oldport, $oldproto, $olddstport, $olddstaddr);
if ($in{'id'}) {
	($oldport, $oldproto, $olddstport, $olddstaddr) =
		split(/\//, $in{'id'});
	}

my $logport;
if ($in{'delete'}) {
	# Just remove the existing rule
	my $err = &delete_firewalld_forward($zone, $oldport, $oldproto,
					    $olddstport, $olddstaddr);
	&error($err) if ($err);
	$logport = $oldport;
	}
else {
	# Validate inputs
	my $port = &parse_port_field(\%in, '');
	my $proto = $in{'proto'};
	my $dstport = &parse_port_field(\%in, 'dst');
	my $dstaddr;
	if (!$in{'dstaddr_def'}) {
		&check_ipaddress($in{'dstaddr'}) ||
		    &check_ip6address($in{'dstaddr'}) ||
			&error($text{'forward_edstaddr'});
		$dstaddr = $in{'dstaddr'};
		}
	$dstport || $dstaddr || &error($text{'forward_eneither'});

	# Create or update forward
	if (!$in{'new'}) {
		my $err = &delete_firewalld_forward($zone, $oldport, $oldproto,
						    $olddstport, $olddstaddr);
		&error($err) if ($err);
		}
	my $err = &create_firewalld_forward($zone, $port, $proto,
					    $dstport, $dstaddr);
	&error($err) if ($err);
	$logport = $port;
	}
&webmin_log($in{'delete'} ? 'delete' : $in{'new'} ? 'create' : 'update',
	    'forward', $logport);
&redirect("index.cgi?zone=".&urlize($zone->{'name'}));
