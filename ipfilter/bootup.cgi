#!/usr/local/bin/perl
# Enable or disable ipfilter at boot time

require './ipfilter-lib.pl';
&ReadParse();
if ($in{'boot'}) {
	&create_firewall_init();
	}
else {
	&delete_firewall_init();
	}
&webmin_log($in{'boot'} ? "bootup" : "bootdown");
&redirect("");

