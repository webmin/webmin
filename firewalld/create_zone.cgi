#!/usr/local/bin/perl
# Create a new zone, and add some allowed ports to it

use strict;
use warnings;
require './firewalld-lib.pl';
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
	# SSH, Webmin and Ident
	push(@addports, "ssh/tcp", "auth/tcp");
	foreach my $webminport (@webminports) {
		push(@addports, $webminport."-".($webminport+10)."/tcp");
		}

	if ($in{'mode'} >= 3) {
		# High ports
		push(@addports, "1024-65535/tcp");
		}

	if ($in{'mode'} >= 4) {
		# Other virtual hosting ports
		push(@addports, "53/tcp", "53/udp");	# DNS
		push(@addports, "80/tcp", "443/tcp");	# HTTP
		push(@addports, "25/tcp", "587/tcp");	# SMTP
		push(@addports, "20/tcp", "21/tcp");	# FTP
		push(@addports, "110/tcp", "995/tcp");	# POP3
		push(@addports, "143/tcp", "220/tcp", "993/tcp");  # IMAP
		push(@addports, "20000/tcp");		# Usermin
		}
	}

# Add the ports and services
my $zone = { 'name' => $in{'name'} };
foreach my $p (@addports) {
	my $err = &create_firewalld_port($zone, split(/\//, $p));
	&error($err) if ($err);
	}
foreach my $s (@addservs) {
	my $err = &create_firewalld_service($zone, $s);
	&error($err) if ($err);
	}

&webmin_log("create", "zone", $in{'name'});
&redirect("index.cgi?zone=".&urlize($in{'name'}));

