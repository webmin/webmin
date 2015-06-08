#!/usr/local/bin/perl
# Create, update or delete a port

use strict;
use warnings;
require 'firewalld-lib.pl';
our (%in, %text);
&error_setup($text{'port_err'});
&ReadParse();

# Get the zone and rule
my @zones = &list_firewalld_zones();
my ($zone) = grep { $_->{'name'} eq $in{'zone'} } @zones;
$zone || &error($text{'port_ezone'});
my ($oldport, $oldproto);
if ($in{'id'}) {
	($oldport, $oldproto) = split(/\//, $in{'id'});
	}

my $logport;
if ($in{'delete'}) {
	# Just remove the existing rule
	my $err = &delete_firewalld_port($zone, $oldport, $oldproto);
	&error($err) if ($err);
	$logport = $oldport;
	}
else {
	# Validate inputs
	my $port;
	if ($in{'mode'} == 0) {
		$in{'port'} =~ /^\d+$/ &&
		  $in{'port'} > 0 && $in{'port'} < 65536 ||
		  getservbyname($in{'port'}, $in{'proto'}) ||
		     &error($text{'port_eport'});
		$port = $in{'port'};
		}
	else {
		$in{'portlow'} =~ /^\d+$/ &&
		  $in{'portlow'} > 0 && $in{'portlow'} < 65536 ||
		     &error($text{'port_eportlow'});
		$in{'porthigh'} =~ /^\d+$/ &&
		  $in{'porthigh'} > 0 && $in{'porthigh'} < 65536 ||
		     &error($text{'port_eporthigh'});
		$in{'portlow'} < $in{'porthigh'} ||
		     &error($text{'port_eportrange'});
		$port = $in{'portlow'}."-".$in{'porthigh'};
		}
	my $proto = $in{'proto'};

	# Create or update allowed port
	if (!$in{'new'}) {
		my $err = &delete_firewalld_port($zone, $oldport, $oldproto);
		&error($err) if ($err);
		}
	my $err = &create_firewalld_port($zone, $port, $proto);
	&error($err) if ($err);
	$logport = $port;
	}
&webmin_log($in{'delete'} ? 'delete' : $in{'new'} ? 'create' : 'update',
	    'port', $logport);
&redirect("index.cgi?zone=".&urlize($zone->{'name'}));
