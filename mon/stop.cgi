#!/usr/local/bin/perl
# stop.cgi
# Stop the mon process

require './mon-lib.pl';
&error_setup($text{'stop_err'});
if ($config{'stop_cmd'}) {
	$out = &backquote_logged("$config{'stop_cmd'} 2>&1 </dev/null");
	&error("<tt>$out</tt>") if ($?);
	}
else {
	if (open(PID, $config{'pid_file'}) && chop($pid = <PID>) &&
	    &kill_logged('TERM', $pid)) {
		close(PID);
		}
	else {
		&error($text{'stop_epid'});
		}
	}
&redirect("");

