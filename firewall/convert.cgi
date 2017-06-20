#!/usr/local/bin/perl
# convert.cgi
# Convert in-kernel firewall rules to the save file, and setup a bootup script

require './firewall4-lib.pl';
&ReadParse();
$access{'setup'} || &error($text{'setup_ecannot'});
&error_setup($text{'convert_err'});
&lock_file($iptables_save_file);
if (defined(&unapply_iptables)) {
	# Call distro's unapply command
	$err = &unapply_iptables();
	}
else {
	# Manually run iptables-save
	$out = &backquote_logged("iptables-save >$iptables_save_file 2>&1");
	$err = "<pre>$out</pre>" if ($?);
	}
&error($err) if ($err);

if ($in{'atboot'}) {
	&create_firewall_init();
	}
&unlock_file($iptables_save_file);

&webmin_log("convert");
&redirect("");

