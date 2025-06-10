#!/usr/local/bin/perl
# start.cgi
# Start the heartbeat process

require './heartbeat-lib.pl';
&error_setup($text{'start_err'});
$out = &backquote_logged("$config{'start_cmd'} 2>&1 </dev/null");
if ($?) {
	&error("<pre>$out</pre>");
	}
&redirect("");

