#!/usr/local/bin/perl
# stop.cgi
# Stop the running fetchmail daemon

require './fetchmail-lib.pl';
&ReadParse();
&error_setup($text{'stop_err'});
$config{'config_file'} || $< || &error($text{'stop_ecannot'});
$can_daemon || &error($text{'start_ecannot'});

if ($config{'stop_cmd'}) {
	$out = &backquote_logged("$config{'stop_cmd'} 2>&1");
	}
elsif ($< == 0) {
	if ($config{'daemon_user'} eq 'root') {
		$out = &backquote_logged("$config{'fetchmail_path'} -q 2>&1");
		}
	else {
		$out = &backquote_logged("su - '$config{'daemon_user'}' -c '$config{'fetchmail_path'} -q' 2>&1");
		}
	}
else {
	$out = &backquote_logged("$config{'fetchmail_path'} -q 2>&1");
	}
if ($?) {
	&error("<tt>$out</tt>");
	}
&webmin_log("stop");
&redirect("");

