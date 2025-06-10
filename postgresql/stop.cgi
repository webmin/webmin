#!/usr/local/bin/perl
# stop.cgi
# Stop the PostgreSQL database server

require './postgresql-lib.pl';
&error_setup($text{'stop_err'});
$access{'stop'} || &error($text{'stop_ecannot'});
$err = &stop_postgresql();
&error($err) if ($err);
sleep(2);
&webmin_log("stop");
&redirect("");

