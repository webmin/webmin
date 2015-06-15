#!/usr/local/bin/perl
# Create a new zone, and add some allowed ports to it

use strict;
use warnings;
require 'firewalld-lib.pl';
our (%text, %in);
&ReadParse();
&error_setup($text{'zone_err'});

# Validate inputs
$in{'name'} =~ /^[a-z0-9\.\_\-]+$/i || &error($text{'zone_ename'});
my @zones = &list_firewalld_zones();
my ($clash) = grep { $_->{'name'} eq $in{'name'} } @zones;
$clash && &error($text{'zone_eclash'});

# Add the zone
my $err = &create_firewalld_zone($in{'name'});
&error($err) if ($err);

# Find the Webmin port
my @webminports;
if (&foreign_installed("webmin")) {
	&foreign_require("webmin");
	my @socks = &webmin::get_miniserv_sockets();
	@webminports = &unique(map { $_->[1] } @webminports);
	}
else {
	@webminports = ( $ENV{'SERVER_PORT'} || 10000 );
	}

# Work out which ports to allow
my (@addports, @addservs);
if ($in{'mode'} == 1) {
	# Copy from another zone
	my ($source) = grep { $_->{'name'} eq $in{'source'} } @zones;
	@addports = @{$source->{'ports'}};
	@addservs = @{$source->{'services'}};
	}
elsif ($in{'mode'} >= 2) {
	# Common allowed ports
	push(@addports, "ssh/tcp", "auth/tcp");
	foreach my $webminport (@webminports) {
		push(@addports, $webminport."-".($webminport+10)."/tcp");
		}
	}

# Add them
# XXX

&webmin_log("create", "zone", $in{'name'});
&redirect("index.cgi?zone=".&urlize($in{'name'}));

