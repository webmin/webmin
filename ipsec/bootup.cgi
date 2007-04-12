#!/usr/local/bin/perl
# bootup.cgi
# Enable or disable the ipsec bootup action

require './ipsec-lib.pl';
&foreign_require("init", "init-lib.pl");
&ReadParse();

if ($in{'boot'} && $in{'starting'} != 2) {
	&init::enable_at_boot("ipsec");
	&webmin_log("boot");
	}
elsif (!$in{'boot'} && $in{'starting'} == 2) {
	&init::disable_at_boot("ipsec");
	&webmin_log("unboot");
	}
&redirect("");

