#!/usr/local/bin/perl
# unapply.cgi
# Revert the firewall configuration from the kernel settings

require './firewall-lib.pl';
&ReadParse();
if (&get_ipvx_version() == 6) {
	require './firewall6-lib.pl';
	}
else {
	require './firewall4-lib.pl';
	}
$access{'unapply'} || &error($text{'unapply_ecannot'});
&error_setup($text{'apply_err'});
if (defined(&unapply_iptables)) {
	# Call distro's unapply command
	$err = &unapply_iptables();
	}
else {
	# Manually run iptables-save
	$err = &iptables_save();
	}
&error($err) if ($err);
&webmin_log("unapply");
&redirect("index.cgi?version=${ipvx_arg}&table=$in{'table'}");

