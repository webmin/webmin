#!/usr/local/bin/perl
# Stop the Frox proxy

require './frox-lib.pl';
&error_setup($text{'stop_err'});

if ($config{'stop_cmd'}) {
	$out = &backquote_logged("($config{'stop_cmd'}) 2>&1 </dev/null");
	if ($?) {
		&error("<pre>$out</pre>");
		}
	}
else {
	$pid = &is_frox_running();
	$pid || &error($text{'stop_egone'});
	&kill_logged('TERM', $pid);
	}
&webmin_log("stop");
&redirect("");

