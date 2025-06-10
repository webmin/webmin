#!/usr/local/bin/perl
# Have Postfix re-read its config

require './postfix-lib.pl';

$access{'startstop'} || &error($text{'reload_ecannot'});
&error_setup($text{'reload_efailed'});
$err = &reload_postfix();
&error($err) if ($err);
&webmin_log("reload");
&redirect("");

