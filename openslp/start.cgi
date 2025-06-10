#!/usr/local/bin/perl
# start.cgi
# Start OpenSLP

require './slp-lib.pl';
&error_setup($text{'start_err'});
$temp = &transname();
if ($config{'start_cmd'}) {
	$rv = &system_logged("($config{'start_cmd'}) >$temp 2>&1");
	}
else {
	$rv = &system_logged("($config{'slpd'}) >$temp 2>&1");
	}
$out = `cat $temp`; unlink($temp);
if ($rv) {
	&error("<pre>$out</pre>");
	}
sleep(2);
&webmin_log("start");
&redirect("");

