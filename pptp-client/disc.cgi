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
sleep(3);
@conns = &list_connected();
($conn) = grep { $_->[0] eq $in{'tunnel'} } @conns;
if ($conn) {
	# Not dead .. kill harder
	&kill_logged('KILL', $conn->[1]);
	}
&webmin_log("disc", undef, $in{'tunnel'});
&redirect("");


