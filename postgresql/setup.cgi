#!/usr/local/bin/perl
# setup.cgi
# Setup the database server for the first time

require './postgresql-lib.pl';
&error_setup($text{'setup_err'});
$access{'stop'} || &error($text{'setup_ecannot'});
$err = &setup_postgresql();
&error($err) if ($err);
sleep(3);
&webmin_log("setup");
&redirect("");

