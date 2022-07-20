#!/usr/local/bin/perl
# Open some ports on the firewall. Exit statuses are :
# 0 - Nothing needed to be done
# 1 - Given ports were opened up
# 2 - IPtables is not installed or supported
# 3 - No firewall is active
# 4 - Could not apply configuration
# 5 - Bad args

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our ($module_name, $no_acl_check);
$no_acl_check++;
$ENV{'WEBMIN_CONFIG'} = "/etc/webmin";
$ENV{'WEBMIN_VAR'} = "/var/webmin";
if ($0 =~ /^(.*\/)[^\/]+$/) {
	chdir($1);
	}
require './firewalld-lib.pl';
if ($module_name ne 'firewalld') {
	print STDERR "Command must be run with full path\n";
	exit(5);
	}

# Parse args
my $no_apply = 0;
if ($ARGV[0] eq "--no-apply") {
	$no_apply = 1;
	shift(@ARGV);
	}
if (!@ARGV) {
	print STDERR "Missing ports to open\n";
	exit(5);
	}
foreach my $p (@ARGV) {
	if ($p !~ /^\d+$/ && $p !~ /^\d+:\d+$/ && $p !~ /^\d+(,\d+)*$/) {
		print STDERR "Port $p must be number or start:end range\n";
		exit(5);
		}
	}

# Check Firewalld support
if (&foreign_installed($module_name, 1) != 2) {
	print STDERR "Firewalld is not available\n";
	exit(2);
	}
if (!&is_firewalld_running()) {
	print STDERR "Firewalld is not running\n";
	exit(2);
	}

# Check if any zones are active
my @azones = &list_firewalld_zones(1);
if (!@azones) {
	print STDERR "No active FirewallD zones found\n";
	exit(3);
	}

# Get the default zone
my @zones = &list_firewalld_zones();
my ($zone) = grep { $_->{'default'} } @zones;
if (!$zone) {
	print STDERR "Default FirewallD zone not found\n";
	exit(3);
	}

my @added = ( );
foreach my $p (@ARGV) {
	# For each port, find existing rules
	$p =~ s/^(\d+):(\d+)/$1-$2/;
	print STDERR "Checking for port $p ..\n";
	if (&indexof($p."/tcp", @{$zone->{'ports'}}) >= 0) {
		print STDERR ".. already allowed\n";
		}
	else {
		# Need to add
		my $err = &create_firewalld_port($zone, $p, "tcp");
		if ($err) {
			print STDERR ".. failed : $err\n";
			}
		else {
			push(@added, $p);
			}
		}
	}

if (@added) {
	# Added some ports - apply them
	print STDERR "Opened ports ",join(" ", @added),"\n";
	my $ex = 1;
	if (!$no_apply) {
		my $err = &apply_firewalld();
		if ($err) {
			print "Failed to apply configuration : $err\n";
			$ex = 4;
			}
		else {
			print "Applied configuration successfully\n";
			}
		}
	&webmin_log("openports", undef, undef, { 'ports' => \@added });
	exit($ex);
	}
else {
	print STDERR "All ports are already open\n";
	exit(0);
	}
