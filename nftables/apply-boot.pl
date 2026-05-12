#!/usr/bin/perl
# apply-boot.pl
# Apply Webmin-managed nftables rules from the saved configuration

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our ($module_name, $no_acl_check);
$no_acl_check++;
if ($0 =~ /^(.*\/)[^\/]+$/) {
	chdir($1);
	}
require './nftables-lib.pl';
if ($module_name ne 'nftables') {
	print STDERR "Command must be run with full path\n";
	exit(5);
	}

my $err = apply_restore();
if ($err) {
	print STDERR $err, "\n";
	exit(1);
	}
exit(0);
