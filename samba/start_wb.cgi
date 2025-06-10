#!/usr/local/bin/perl
# Attempt to start the winbindd processes

require './samba-lib.pl';

&error_setup("$text{'eacl_aviol'}ask_epass.cgi");
&error("$text{'eacl_np'} $text{'eacl_papply'}") unless $access{'apply'};
 
&error_setup($text{'start_err_wb'});

if ($config{'start_cmd_wb'}) {
	$rv = &system_logged("$config{'start_cmd_wb'} >/dev/null 2>&1 </dev/null");
	if ($rv) { &error(&text('start_fail', $config{'start_cmd_wb'})); }
	}
else {
	chdir("/");
	$rv = &system_logged("$config{winbind_server} </dev/null");
	if ($rv) { &error(&text('start_fail', $config{winbind_server})); }
	}
&webmin_log("start_wb");
&redirect("");

