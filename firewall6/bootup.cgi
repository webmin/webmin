#!/usr/local/bin/perl
# bootup.cgi
# Enable or disable ip6tables at boot time

require './firewall6-lib.pl';
&ReadParse();
$access{'bootup'} || &error($text{'bootup_ecannot'});
if ($in{'boot'}) {
	&create_firewall_init();
	}
elsif (defined(&disable_at_boot)) {
	&disable_at_boot();
	}
else {
	&foreign_require("init", "init-lib.pl");
	&init::disable_at_boot("webmin-ip6tables");
	}
&webmin_log($in{'boot'} ? "bootup" : "bootdown");
&redirect("index.cgi?table=$in{'table'}");

