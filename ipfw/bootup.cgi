#!/usr/local/bin/perl
# bootup.cgi
# Enable or disable ipfw at boot time

require './ipfw-lib.pl';
&ReadParse();
if ($in{'boot'}) {
	&create_firewall_init();
	}
else {
	&foreign_require("init", "init-lib.pl");
	&init::disable_at_boot($module_name);
	}
&webmin_log($in{'boot'} ? "bootup" : "bootdown");
&redirect("");

