#!/usr/local/bin/perl
# start.cgi
# Attempt to start the smbd and nmbd processes

require './samba-lib.pl';

&error_setup("$text{'eacl_aviol'}ask_epass.cgi");
&error("$text{'eacl_np'} $text{'eacl_papply'}") unless $access{'apply'};
 
&error_setup($text{'start_err'});

if ($config{'start_cmd'}) {
	$rv = &system_logged("$config{'start_cmd'} >/dev/null 2>&1 </dev/null");
	if ($rv) { &error(&text('start_fail', $config{'start_cmd'})); }
	}
else {
	chdir("/");
	$rv = &system_logged("$config{samba_server} -D </dev/null");
	if ($rv) { &error(&text('start_fail', $config{samba_server})); }
	$rv = &system_logged("$config{name_server} -D </dev/null");
	if ($rv) { &error(&text('start_fail', $config{name_server})); }
	}
&webmin_log("start");
&redirect("");

