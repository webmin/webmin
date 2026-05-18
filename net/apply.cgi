#!/usr/local/bin/perl
# apply.cgi
# Apply the current network config

require './net-lib.pl';
$access{'apply'} || &error($text{'apply_ecannot'});
&error_setup($text{'apply_err'});
$err = &apply_network();
$err && &error("<pre>".&html_escape($err)."</pre>");
sleep(1);
&webmin_log("apply");
&redirect("");
