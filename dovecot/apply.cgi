#!/usr/local/bin/perl
# Apply the configuration

require './dovecot-lib.pl';
&error_setup($text{'apply_err'});
$err = &apply_configuration();
&error($err) if ($err);
&webmin_log("apply");
&redirect("");


