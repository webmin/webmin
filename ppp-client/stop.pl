#!/usr/local/bin/perl
# stop.pl
# Shut down a connection by killing it's PID

$no_acl_check++;
require './ppp-client-lib.pl';

($ip, $pid, $sect) = &get_connect_details();
$disconnected = &ppp_disconnect($ip ? 0 : 1, 1);
exit($disconnected ? 0 : 1);

