#!/usr/local/bin/perl
# stop.cgi

require './usermin-lib.pl';
$access{'stop'} || &error($text{'stop_ecannot'});
&error_setup($text{'stop_err'});
$err = &stop_usermin();
&error($err) if ($err);
&redirect("");

