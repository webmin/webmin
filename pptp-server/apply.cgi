#!/usr/local/bin/perl
# apply.cgi
# Shut down and re-start the PPTP server

require './pptp-server-lib.pl';
&error_setup($text{'apply_err'});
$access{'apply'} || &error($text{'apply_ecannot'});

$err = &apply_configuration();
&error($err) if ($err);

&webmin_log("apply");
&redirect("");

