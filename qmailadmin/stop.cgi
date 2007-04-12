#!/usr/local/bin/perl
# stop.cgi
# Stop the processes started by /var/qmail/rc

require './qmail-lib.pl';
$err = &stop_qmail();
&error($err) if ($err);
&webmin_log("stop");
&redirect("");

