#!/usr/local/bin/perl
# Restart the MySQL database server

require './mysql-lib.pl';
&error_setup($text{'restart_err'});
$access{'stop'} || &error($text{'stop_ecannot'});
$err = &stop_mysql();
&error($err) if ($err);
$err = &start_mysql();
&error($err) if ($err);
sleep(3);
&webmin_log("restart");
&redirect("");

