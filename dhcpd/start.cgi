#!/usr/local/bin/perl
# start.cgi
# Attempt to start dhcpd
require './dhcpd-lib.pl';
%access = &get_module_acl();
&error_setup("<blink><font color=red>$text{'eacl_aviol'}</font></blink>");
&error("$text{'eacl_np'} $text{'eacl_papply'}") unless $access{'apply'};

$whatfailed = $text{'start_failstart'};
$err = &start_dhcpd();
&error($err) if ($err);
&webmin_log("start");
&redirect("");

