#!/usr/local/bin/perl
# start.cgi
# Start up the PPTP server

require './pptp-server-lib.pl';
&error_setup($text{'start_err'});
$access{'apply'} || &error($text{'start_ecannot'});
$cmd = $config{'start_cmd'} || $config{'pptpd'};
$temp = &transname();
$rv = &system_logged("$cmd >$temp 2>&1 </dev/null");
$out = `cat $temp`;
unlink($temp);
if ($rv) {
	&error("<pre>$out</pre>");
	}
&webmin_log("start");
&redirect("");

