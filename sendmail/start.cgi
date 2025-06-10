#!/usr/local/bin/perl
# start.cgi
# Start sendmail

require './sendmail-lib.pl';
$access{'stop'} || &error($text{'start_ecannot'});
&error_setup($text{'start_err'});
$err = &start_sendmail();
&error($err) if ($err);
&webmin_log("start");
&redirect("");

