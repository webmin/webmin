#!/usr/local/bin/perl
# restart_inetd.cgi
# Send a HUP signal to the inetd process

require './inetd-lib.pl';
$whatfailed = $text{'error_restart'};

$out = &backquote_logged("$config{'restart_command'} 2>&1");
if ($?) {
	# Failed to signal inetd
	&error($out);
	}
&webmin_log("apply");
&redirect("");

