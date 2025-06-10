#!/usr/local/bin/perl
# stop.pl
# Shut down a connection by killing it's PID

$no_acl_check++;
require './pptp-client-lib.pl';

@conns = &list_connected();
($conn) = grep { $_->[0] eq $config{'boot'} } @conns;
$conn || die $text{'disc_egone'};
&kill_logged('HUP', $conn->[1]) || die $text{'disc_ekill'};
print &text('disc_done', $config{'boot'}),"\n";
exit(0);
