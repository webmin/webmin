#!/usr/local/bin/perl
# Kill all winbindd processes

require './samba-lib.pl';

&error_setup("$text{'eacl_aviol'}ask_epass.cgi");
&error("$text{'eacl_np'} $text{'eacl_papply'}") unless $access{'apply'};
 
if ($config{'stop_cmd_wb'}) {
	&system_logged("$config{'stop_cmd_wb'} >/dev/null 2>&1 </dev/null");
	}
else {
	@wbpids = &find_byname("winbindd");
	&kill_logged('TERM', @wbpids);
	}

&webmin_log("stop_wb");
&redirect("");

