#!/usr/local/bin/perl
# restart.cgi
# Kill all smbd and nmdb processes and re-start them

require './samba-lib.pl';

&error_setup("$text{'eacl_aviol'}ask_epass.cgi");
&error("$text{'eacl_np'} $text{'eacl_papply'}") unless $access{'apply'};
 
if ($config{'stop_cmd'}) {
	&system_logged("$config{'stop_cmd'} >/dev/null 2>&1 </dev/null");
	}
else {
	@smbpids = &find_byname("smbd");
	@nmbpids = &find_byname("nmbd");
	&kill_logged('TERM', @smbpids, @nmbpids);
	}

&webmin_log("stop");
&redirect("");

