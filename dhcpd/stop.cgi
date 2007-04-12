#!/usr/local/bin/perl
# Attempt to stop dhcpd

require './dhcpd-lib.pl';
%access = &get_module_acl();
&error_setup("<blink><font color=red>$text{'eacl_aviol'}</font></blink>");
&error("$text{'eacl_np'} $text{'eacl_papply'}") unless $access{'apply'};

$whatfailed = $text{'stop_err'};
$err = &stop_dhcpd();
&error($err) if ($err);
&webmin_log("stop");
&redirect("");

