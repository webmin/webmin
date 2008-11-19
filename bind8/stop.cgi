#!/usr/local/bin/perl
# Stop bind 8

require './bind8-lib.pl';
$access{'ro'} && &error($text{'stop_ecannot'});
$access{'apply'} || &error($text{'stop_ecannot'});
$err = &stop_bind();
&error($err) if ($err);
&webmin_log("stop");
&redirect($in{'return'} ? $ENV{'HTTP_REFERER'} : "");

