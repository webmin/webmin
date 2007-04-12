#!/usr/local/bin/perl
# stop.cgi
# Stop the jabber server

require './jabber-lib.pl';
&error_setup($text{'stop_err'});
$err = &stop_jabber();
&error($err) if ($err);
&webmin_log("stop");
&redirect("");

