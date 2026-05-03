#!/usr/bin/perl
# bootup.cgi
# Enable or disable Webmin-managed nftables rules at boot time

require './nftables-lib.pl';    ## no critic
use strict;
use warnings;
our (%in, %text);
ReadParse();
assert_acl('bootup');
foreign_check("init") || error($text{'bootup_einit'});

if ($in{'boot'}) {
	create_nftables_init();
	}
else {
	disable_nftables_init();
	}
webmin_log($in{'boot'} ? "bootup" : "bootdown");
redirect("index.cgi");
