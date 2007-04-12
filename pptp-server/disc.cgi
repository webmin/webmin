#!/usr/local/bin/perl
# disc.cgi
# Disconnect a VPN connection

require './pptp-server-lib.pl';
&ReadParse();
&error_setup($text{'disc_err'});
$access{'conns'} || &error($text{'conns_ecannot'});
@conns = &list_connections();
($conn) = grep { $_->[0] eq $in{'pid'} } @conns;
$conn || &error($text{'disc_egone'});
&kill_logged('TERM', $conn->[0]) || &error($text{'disc_ekill'});
&kill_logged('TERM', $conn->[1]);
sleep(2);	# wait for it to quit
&webmin_log("disc", undef, $conn->[2]);
&redirect("list_conns.cgi");

