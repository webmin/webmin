#!/usr/local/bin/perl
# stop.cgi
# Stop OpenSLP

require './slp-lib.pl';
if ($config{'stop_cmd'}) {
	$out = &backquote_logged("$config{'stop_cmd'} 2>&1");
	&error_setup($text{'stop_err'});
	if ($?) {
		&error("<pre>$?\n$out</pre>");
		}
	}
else {
	$pid = &slpd_is_running();
	kill('TERM', $pid);
	}
&webmin_log("stop");
&redirect("");

