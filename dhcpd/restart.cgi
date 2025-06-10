#!/usr/local/bin/perl
# restart.cgi
# Restart the running dhcpd

require './dhcpd-lib.pl';
&ReadParse();
%access = &get_module_acl();
&error_setup($text{'eacl_aviol'});
&error("$text{'eacl_np'} $text{'eacl_papply'}") unless $access{'apply'};

&error_setup($text{'restart_errmsg1'});
$err = &restart_dhcpd();
&error($err) if ($err);
&webmin_log("apply");
&redirect("");

