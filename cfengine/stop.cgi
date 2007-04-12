#!/usr/local/bin/perl
# stop.cgi
# Stop the configuration engine daemon

require './cfengine-lib.pl';
&error_setup($text{'stop_err'});
if ($config{'stop_cmd'}) {
	$out = &backquote_logged("$config{'stop_cmd'} 2>&1 </dev/null");
	&error("<pre>$out</pre>") if ($out =~ /error|failed/ || $?);
	}
else {
	@pids = &find_byname("cfd");
	@pids || &error($text{'stop_epids'});
	&kill_logged('TERM', @pids) || &error(&text('stop_ekill', $!));
	}
&webmin_log("stop");
&redirect("edit_cfd.cgi");

