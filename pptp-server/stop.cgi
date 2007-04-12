#!/usr/local/bin/perl
# stop.cgi
# Shut down the PPTP server

require './pptp-server-lib.pl';
&error_setup($text{'stop_err'});
$access{'stop'} || &error($text{'stop_ecannot'});
if ($config{'stop_cmd'}) {
	$out = &backquote_logged("$config{'stop_cmd'} 2>&1 </dev/null");
	&error("<pre>$out</pre>") if ($?);
	}
else {
	$pid = &get_pptpd_pid();
	if (!$pid || !&kill_logged('TERM', $pid)) {
		&error($text{'stop_egone'});
		}
	}
&webmin_log("stop");
&redirect("");

