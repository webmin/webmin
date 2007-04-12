#!/usr/local/bin/perl
# start.cgi
# Start the jabber server

require './jabber-lib.pl';
$err = &start_jabber();
&error($err) if ($err);
&webmin_log("start");
&redirect("");

