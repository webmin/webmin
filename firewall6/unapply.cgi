#!/usr/local/bin/perl
# unapply.cgi
# Revert the firewall configuration from the kernel settings

require './firewall6-lib.pl';
&ReadParse();
$access{'unapply'} || &error($text{'unapply_ecannot'});
&error_setup($text{'apply_err'});
if (defined(&unapply_ip6tables)) {
	# Call distro's unapply command
	$err = &unapply_ip6tables();
	}
else {
	# Manually run ip6tables-save
	$err = &ip6tables_save();
	}
&error($err) if ($err);
&webmin_log("unapply");
&redirect("index.cgi?table=$in{'table'}");

