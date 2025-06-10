#!/usr/local/bin/perl
# Apply the syslog-ng config

require './syslog-ng-lib.pl';
&error_setup($text{'apply_err'});
$err = &apply_configuration();
&error($err) if ($err);
&webmin_log("apply");
&redirect("");
