#!/usr/local/bin/perl
# convert.cgi
# Convert in-kernel firewall rules to the save file, and setup a bootup script

require './firewall-lib.pl';
&ReadParse();
if (&get_ipvx_version() == 6) {
	require './firewall6-lib.pl';
	}
else {
	require './firewall4-lib.pl';
	}
$access{'setup'} || &error($text{'setup_ecannot'});
&error_setup($text{'convert_err'});
&lock_file($ipvx_save);
if (defined(&unapply_iptables)) {
	# Call distro's unapply command
	$err = &unapply_iptables();
	}
else {
	# Manually run iptables-save
	$out = &backquote_logged("ip${ipvy}tables-save >$ipvx_save 2>&1");
	$err = "<pre>$out</pre>" if ($?);
	}
&error($err) if ($err);

if ($in{'atboot'}) {
	&create_firewall_init();
	}
&unlock_file($ipvx_save);

&webmin_log("convert");
&redirect("");

