#!/usr/local/bin/perl
# disc.cgi
# Shut down a PPTP tunnel

require './pptp-client-lib.pl';
&ReadParse();
&error_setup($text{'disc_err'});
@conns = &list_connected();
($conn) = grep { $_->[0] eq $in{'tunnel'} } @conns;
$conn || &error($text{'disc_egone'});
&kill_logged('HUP', $conn->[1]) || &error($text{'disc_ekill'});
&webmin_log("disc", undef, $in{'tunnel'});
sleep(3);
&redirect("");


