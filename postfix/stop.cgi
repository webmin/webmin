#!/usr/local/bin/perl
#
# postfix-module by Guillaume Cottenceau <gc@mandrakesoft.com>,
# for webmin by Jamie Cameron
# 
# Stop postfix

require './postfix-lib.pl';

$access{'startstop'} || &error($text{'stop_ecannot'});
&error_setup($text{'stop_efailed'});
$err = &stop_postfix();
&error($err) if ($err);
&webmin_log("stop");
&redirect("");

