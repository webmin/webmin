#!/usr/local/bin/perl
# apply.cgi
# Apply the current network config

require './net-lib.pl';
$access{'apply'} || &error($text{'apply_ecannot'});
&apply_network();
sleep(1);
&redirect("");

