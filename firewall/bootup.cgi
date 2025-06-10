#!/usr/local/bin/perl
# bootup.cgi
# Enable or disable iptables at boot time

require './firewall-lib.pl';
&ReadParse();
if (&get_ipvx_version() == 6) {
	require './firewall6-lib.pl';
	}
else {
	require './firewall4-lib.pl';
	}
$access{'bootup'} || &error($text{'bootup_ecannot'});
if ($in{'boot'}) {
	&create_firewall_init();
	}
elsif (defined(&disable_at_boot)) {
	&disable_at_boot();
	}
else {
	&foreign_require("init", "init-lib.pl");
	&init::disable_at_boot("webmin-ip${ipvx}tables");
	}
&webmin_log($in{'boot'} ? "bootup" : "bootdown");
&redirect("index.cgi?version=${ipvx_arg}&table=$in{'table'}");
