#!/usr/local/bin/perl
# Kill all winbindd processes and re-start them

require './samba-lib.pl';

&error_setup("$text{'eacl_aviol'}ask_epass.cgi");
&error("$text{'eacl_np'} $text{'eacl_papply'}") unless $access{'apply'};

&error_setup($text{'restart_err_wb'});
 
if ($config{'stop_cmd_wb'}) {
	&system_logged("$config{'stop_cmd_wb'} >/dev/null 2>&1 </dev/null");
	}
else {
	@wbpids = &find_byname("winbindd");
	&kill_logged('TERM', @wbpids);
	}

if ($config{'start_cmd_wb'}) {
	$rv = &system_logged("$config{'start_cmd_wb'} >/dev/null 2>&1 </dev/null");
	if ($rv) { &error(&text('start_fail', $config{'start_cmd_wb'})); }
	}
else {
	$rv = &system_logged("$config{winbind_server} >/dev/null 2>&1 </dev/null");
	if ($rv) { &error(&text('start_fail', $config{winbind_server})); }
	}

&webmin_log("apply_wb");
&redirect("");

