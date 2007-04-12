#!/usr/local/bin/perl
# start.cgi
# Start the usermin server

require './usermin-lib.pl';
$access{'stop'} || &error($text{'start_ecannot'});
$err = &start_usermin();
&error($err) if ($err);
&redirect("");

