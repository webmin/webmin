#!/usr/local/bin/perl
# apply.cgi
# Apply the current firewall configuration

require './firewall4-lib.pl';
&ReadParse();
$access{'apply'} || &error($text{'apply_ecannot'});
&error_setup($text{'apply_err'});
$err = &apply_configuration();
&error($err) if ($err);
$err = &apply_cluster_configuration();
&error($err) if ($err);
&webmin_log("apply");
&redirect("index.cgi?table=$in{'table'}");

