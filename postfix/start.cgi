#!/usr/local/bin/perl
#
# postfix-module by Guillaume Cottenceau <gc@mandrakesoft.com>,
# for webmin by Jamie Cameron
#
# Start postfix

require './postfix-lib.pl';

$access{'startstop'} || &error($text{'start_ecannot'});
&error_setup($text{'start_efailed'});
$err = &start_postfix();
&error($err) if ($err);
&webmin_log("start");
&redirect("");

