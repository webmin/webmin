#!/usr/local/bin/perl
# restart.cgi
# Stop and then restart the Jabber server

require './jabber-lib.pl';
&error_setup($text{'restart_err'});

$err = &stop_jabber();
&error($err) if ($err);

$err = &start_jabber();
&error($err) if ($err);

&webmin_log("restart");
&redirect("");

