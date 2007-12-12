#!/usr/local/bin/perl
# apply.cgi
# Apply the current firewall configuration

require './ipfw-lib.pl';
&ReadParse();
&error_setup($text{'apply_err'});
$err = &apply_rules();
&error($err) if ($err);
$err = &apply_cluster_configuration();
&error($err) if ($err);
&webmin_log("apply");
&redirect("");

