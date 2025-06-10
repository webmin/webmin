#!/usr/local/bin/perl
# Stop the syslog-ng server

require './syslog-ng-lib.pl';
&error_setup($text{'stop_err'});
$err = &stop_syslog_ng();
&error($err) if ($err);
&webmin_log("stop");
&redirect("");
