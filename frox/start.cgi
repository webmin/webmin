#!/usr/local/bin/perl
# Start the Frox proxy

require './frox-lib.pl';
&error_setup($text{'start_err'});

# Fixed up file on Debian that controls startup script
if ($config{'daemon_file'}) {
	&lock_file($config{'daemon_file'});
	&read_env_file($config{'daemon_file'}, \%daemon);
	if ($daemon{'RUN_DAEMON'} ne 'yes') {
		$daemon{'RUN_DAEMON'} = 'yes';
		&write_env_file($config{'daemon_file'}, \%daemon);
		}
	&unlock_file($config{'daemon_file'});
	}

if ($config{'start_cmd'}) {
	$cmd = $config{'start_cmd'};
	}
else {
	$cmd = "$config{'frox'} -f $config{'frox_conf'}";
	}
$temp = &transname();
$ex = &system_logged("($cmd) >$temp 2>&1 </dev/null");
$out = `cat $temp`;
unlink($temp);
if ($ex || (!$config{'start_cmd'} && $out =~ /\S/) || $out =~ /error/i) {
	&error("<pre>$out</pre>");
	}
&webmin_log("start");
&redirect("");

