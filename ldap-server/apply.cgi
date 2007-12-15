#!/usr/local/bin/perl
# Apply the current config

require './ldap-server-lib.pl';
&error_setup($text{'apply_err'});
$access{'apply'} || &error($text{'apply_ecannot'});
$err = &apply_configuration();
&error($err) if ($err);
&webmin_log('apply');
&redirect("");


