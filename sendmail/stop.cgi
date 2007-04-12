#!/usr/local/bin/perl
# stop.cgi
# Stop the running sendmail process

require './sendmail-lib.pl';
&ReadParse();
$access{'stop'} || &error($text{'stop_ecannot'});
&error_setup($text{'stop_err'});
$err = &stop_sendmail();
&error($err) if ($err);
&webmin_log("stop");
&redirect("");

