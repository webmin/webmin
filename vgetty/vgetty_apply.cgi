#!/usr/local/bin/perl
# vgetty_apply.cgi
# Apply the current init config

require './vgetty-lib.pl';
&error_setup($text{'vgetty_applyerr'});
$err = &apply_configuration();
&error($err) if ($err);
&webmin_log("apply");
&redirect("");

