#!/usr/local/bin/perl
# Apply the Frox proxy configuration

require './frox-lib.pl';
&error_setup($text{'apply_err'});

$err = &restart_frox();
&error($err) if ($err);
&webmin_log("apply");
&redirect("");

