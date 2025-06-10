#!/usr/local/bin/perl
# stop.cgi
# Stop the print scheduler

require './lpadmin-lib.pl';
&ReadParse();
$access{'stop'} == 1 || &error($text{'stop_ecannot'});
&error_setup($text{'stop_err'});
if ($config{'stop_cmd'}) {
	$out = &backquote_logged("($config{'stop_cmd'}) 2>&1");
	&error($out) if ($?);
	}
else {
	&stop_sched(&sched_running());
	}
&webmin_log("stop");
&redirect("");

