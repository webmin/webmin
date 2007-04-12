#!/usr/local/bin/perl
# stop.cgi
# Stop the MySQL database server

require './mysql-lib.pl';
&error_setup($text{'stop_err'});
$err = &stop_mysql();
&error($err) if ($err);
&webmin_log("stop");
&redirect("");

