#!/usr/local/bin/perl
# Apply the IPfilter configuration

require './ipfilter-lib.pl';
&error_setup($text{'apply_err'});
$err = &apply_configuration();
&error($err) if ($err);
$err = &apply_cluster_configuration();
&error($err) if ($err);
&webmin_log("apply");
&redirect("");

