#!/usr/local/bin/perl
# bootup.cgi
# Enable or disable ADSL startup at boot time

require './adsl-client-lib.pl';
&foreign_require("init", "init-lib.pl");
&ReadParse();

if ($in{'boot'}) {
	# Enable starting at boot
	&init::enable_at_boot("adsl");
	&webmin_log("bootup");
	}
else {
	# Disable starting at boot
	&init::disable_at_boot("adsl");
	&webmin_log("bootdown");
	}
&redirect("");

