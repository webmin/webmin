#!/usr/local/bin/perl
# Stop the LDAP client daemon

require './ldap-client-lib.pl';
&error_setup($text{'stop_err'});

&foreign_require("init");
($ok, $out) = &init::stop_action($config{'init_name'});
$ok || &error($out);

&webmin_log("stop");
&redirect("");

