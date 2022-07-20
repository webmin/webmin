#!/usr/local/bin/perl
# Create, update or delete a service

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './firewalld-lib.pl';
our (%in, %text);
&error_setup($text{'serv_err'});
&ReadParse();

# Get the zone and rule
my @zones = &list_firewalld_zones();
my ($zone) = grep { $_->{'name'} eq $in{'zone'} } @zones;
$zone || &error($text{'port_ezone'});
my $oldserv;
if ($in{'id'}) {
	$oldserv = $in{'id'};
	}

my $logserv;
if ($in{'delete'}) {
	# Just remove the existing rule
	my $err = &delete_firewalld_service($zone, $oldserv);
	&error($err) if ($err);
	$logserv = $oldserv;
	}
else {
	# Validate inputs
	my $serv = $in{'serv'};

	# Create or update allowed port
	if (!$in{'new'}) {
		my $err = &delete_firewalld_service($zone, $oldserv);
		&error($err) if ($err);
		}
	my $err = &create_firewalld_service($zone, $serv);
	&error($err) if ($err);
	$logserv = $serv;
	}
&webmin_log($in{'delete'} ? 'delete' : $in{'new'} ? 'create' : 'update',
	    'serv', $logserv);
&redirect("index.cgi?zone=".&urlize($zone->{'name'}));
