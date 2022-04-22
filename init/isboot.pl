#!/usr/bin/perl
# isboot.pl
# Called by setup.sh to check if given service is enabled

$no_acl_check++;
require './init-lib.pl';
$product = $ARGV[0] || "webmin";
# Is enabled and system supports systemd
if (&action_status($product) == 2 &&
    $init_mode eq "systemd") {
	&enable_at_boot($product);
	};
