#!/usr/local/bin/perl
# bootup.cgi
# Enable or disable ipfw at boot time

require './ipfw-lib.pl';
&ReadParse();
if ($in{'boot'}) {
	&enable_boot();
	}
else {
	&disable_boot();
	}
&webmin_log($in{'boot'} ? "bootup" : "bootdown");
&redirect("");

