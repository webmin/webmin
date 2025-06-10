#!/usr/local/bin/perl
# start.cgi
# Attempt to start dhcpd

require './dhcpd-lib.pl';
%access = &get_module_acl();
&error_setup($text{'eacl_aviol'});
&error("$text{'eacl_np'} $text{'eacl_papply'}") unless $access{'apply'};

&error_setup($text{'start_failstart'});
$err = &start_dhcpd();
&error($err) if ($err);
&webmin_log("start");
&redirect("");

