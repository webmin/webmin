#!/usr/local/bin/perl
# Re-start the LDAP client daemon

require './ldap-client-lib.pl';
&error_setup($text{'start_err'});

&fix_ldap_authconfig();
&foreign_require("init");
&init::stop_action($config{'init_name'});
($ok, $out) = &init::start_action($config{'init_name'});
$ok || &error($out);

&webmin_log("restart");
&redirect("");

