#!/usr/local/bin/perl
# Start the LDAP server

require './ldap-server-lib.pl';
&error_setup($text{'start_err'});
$access{'start'} || &error($text{'start_ecannot'});
$err = &start_ldap_server();
&error($err) if ($err);
&webmin_log('start');
&redirect("");


