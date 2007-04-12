#!/usr/local/bin/perl
# start.cgi
# Start the syslog process

require './syslog-lib.pl';
$access{'noedit'} && &error($text{'start_ecannot'});
if ($config{'start_cmd'}) {
	&system_logged("$config{'start_cmd'} >/dev/null 2>/dev/null </dev/null");
	}
else {
	&system_logged("cd / ; $config{'syslogd'} >/dev/null 2>/dev/null </dev/null &");
	}
&webmin_log("start");
&redirect("");

