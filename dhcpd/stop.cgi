#!/usr/local/bin/perl
# Attempt to stop dhcpd

require './dhcpd-lib.pl';
%access = &get_module_acl();
&error_setup($text{'eacl_aviol'});
&error("$text{'eacl_np'} $text{'eacl_papply'}") unless $access{'apply'};

&error_setup($text{'stop_err'});
$err = &stop_dhcpd();
&error($err) if ($err);
&webmin_log("stop");
&redirect("");

