#!/usr/local/bin/perl
# apply.cgi
# Apply the current firewall configuration

require './firewall-lib.pl';
&ReadParse();
if (&get_ipvx_version() == 6) {
	require './firewall6-lib.pl';
	}
else {
	require './firewall4-lib.pl';
	}
$access{'apply'} || &error($text{'apply_ecannot'});
&error_setup($text{'apply_err'});
$err = &apply_configuration();
&error($err) if ($err);
$err = &apply_cluster_configuration();
&error($err) if ($err);
&webmin_log("apply");
&redirect("index.cgi?version=${ipvx_arg}&table=$in{'table'}");

