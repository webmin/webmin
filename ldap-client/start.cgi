#!/usr/local/bin/perl
# Start the LDAP client daemon

require './ldap-client-lib.pl';
&error_setup($text{'start_err'});

&fix_ldap_authconfig();
&foreign_require("init");
($ok, $out) = &init::start_action($config{'init_name'});
$ok || &error($out);

&webmin_log("start");
&redirect("");

