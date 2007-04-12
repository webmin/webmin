#!/usr/local/bin/perl
# start.cgi
# Start the print scheduler

require './lpadmin-lib.pl';
&ReadParse();
$access{'stop'} == 1 || &error($text{'start_ecannot'});
&error_setup($text{'start_err'});
if ($config{'start_cmd'}) {
	$out = &backquote_logged("($config{'start_cmd'}) 2>&1");
	&error($out) if ($?);
	sleep(3);
	}
else {
	&start_sched();
	}
&webmin_log("start");
&redirect("");

