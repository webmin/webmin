#!/usr/local/bin/perl
# start.cgi
# Start the qmail rc command in the background

require './qmail-lib.pl';
$err = &start_qmail();
&error($err) if ($err);
&webmin_log("start");
&redirect("");

