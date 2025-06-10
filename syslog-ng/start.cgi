#!/usr/local/bin/perl
# Start the syslog-ng server

require './syslog-ng-lib.pl';
&error_setup($text{'start_err'});
$err = &start_syslog_ng();
&error($err) if ($err);
&webmin_log("start");
&redirect("");
