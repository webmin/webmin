#!/usr/local/bin/perl
# start.cgi
# Start the MySQL database server

require './mysql-lib.pl';
&error_setup($text{'start_err'});
$access{'stop'} || &error($text{'stop_ecannot'});
$err = &start_mysql();
&error($err) if ($err);
sleep(3);
&webmin_log("start");
&redirect("");

