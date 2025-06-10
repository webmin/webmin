#!/usr/local/bin/perl
# restart.cgi
# Kill all smbd and nmdb processes and re-start them

require './samba-lib.pl';

&error_setup("$text{'eacl_aviol'}ask_epass.cgi");
&error("$text{'eacl_np'} $text{'eacl_papply'}") unless $access{'apply'};

&error_setup($text{'restart_err'});

if ($config{'restart_cmd'}) {
	# Just use a single restart command
	$rv = &system_logged(
		"$config{'restart_cmd'} >/dev/null 2>&1 </dev/null");
	if ($rv) { &error(&text('restart_fail', $config{'restart_cmd'})); }
	}
else {
 	# Stop first
	if ($config{'stop_cmd'}) {
		&system_logged(
			"$config{'stop_cmd'} >/dev/null 2>&1 </dev/null");
		}
	else {
		@smbpids = &find_byname("smbd");
		@nmbpids = &find_byname("nmbd");
		&kill_logged('TERM', @smbpids, @nmbpids);
		}

	# Allow Samba some time to shut down
	sleep(2);

	# Start up again
	if ($config{'start_cmd'}) {
		$rv = &system_logged(
			"$config{'start_cmd'} >/dev/null 2>&1 </dev/null");
		if ($rv) {
			&error(&text('start_fail', $config{'start_cmd'}));
			}
		}
	else {
		$rv = &system_logged(
			"$config{samba_server} -D >/dev/null 2>&1 </dev/null");
		if ($rv) {
			&error(&text('start_fail', $config{samba_server}));
			}
		$rv = &system_logged(
			"$config{name_server} -D >/dev/null 2>&1 </dev/null");
		if ($rv) {
			&error(&text('start_fail', $config{samba_server}));
			}
		}
	}

&webmin_log("apply");
&redirect("");

