#!/usr/bin/perl
# isboot.pl
# Called by setup.sh to check if given service is enabled

$no_acl_check++;
require './init-lib.pl';
$product = $ARGV[0] || "webmin";
if (&action_status($product) == 2) {
	print 1;
	exit;
	};
print 0;
