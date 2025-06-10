#!/usr/local/bin/perl
# restart.cgi
# Kill and restart the syslog process

require './syslog-lib.pl';
&ReadParse();
$access{'noedit'} && &error($text{'restart_ecannot'});
$err = &restart_syslog();
&error($err) if ($err);
&webmin_log("apply");
&redirect("");

