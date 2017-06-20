#!/usr/local/bin/perl
# unapply.cgi
# Revert the firewall configuration from the kernel settings

require './firewall4-lib.pl';
&ReadParse();
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
&redirect("index.cgi?table=$in{'table'}");

