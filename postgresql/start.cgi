#!/usr/local/bin/perl
# start.cgi
# Start the PostgreSQL database server

require './postgresql-lib.pl';
&error_setup($text{'start_err'});
$access{'stop'} || &error($text{'start_ecannot'});
$err = &start_postgresql();
&error($err) if ($err);
sleep(3);
&webmin_log("start");
&redirect("");

