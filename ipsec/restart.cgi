#!/usr/local/bin/perl
# restart.cgi
# Re-start the IPsec server

require './ipsec-lib.pl';
&error_setup($text{'restart_err'});
$err = &restart_ipsec();
&error($err) if ($err);
&webmin_log("restart");
&redirect("");

