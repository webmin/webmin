#!/usr/bin/perl
# bootup.cgi
# Enable or disable the system nftables service at boot time

require './nftables-lib.pl';    ## no critic
use strict;
use warnings;
our (%in, %text);
ReadParse();
assert_acl('bootup');
foreign_check("init") || error($text{'bootup_einit'});
nftables_service_status() || error($text{'bootup_eservice'});

if ($in{'boot'}) {
	enable_nftables_at_boot();
	}
else {
	disable_nftables_at_boot();
	}
webmin_log($in{'boot'} ? "bootup" : "bootdown");
redirect("index.cgi");
