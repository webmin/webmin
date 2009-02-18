#!/usr/local/bin/perl
# save_misc.cgi
# save miscellaneous options

require './sshd-lib.pl';
&ReadParse();
&error_setup($text{'misc_err'});
&lock_file($config{'sshd_config'});
$conf = &get_sshd_config();

&save_directive("X11Forwarding", $conf, $in{'x11'} ? 'yes' : 'no');

if ($version{'type'} ne 'ssh' || $version{'number'} < 2) {
	if ($in{'xoff_def'}) {
		&save_directive("X11DisplayOffset", $conf);
		}
	else {
		$in{'xoff'} =~ /^\d+$/ || &error($text{'misc_exoff'});
		&save_directive("X11DisplayOffset", $conf, $in{'xoff'});
		}

	if ($version{'type'} eq 'ssh' || $version{'number'} >= 2) {
		if ($in{'xauth_def'}) {
			&save_directive("XAuthLocation", $conf);
			}
		else {
			-x $in{'xauth'} || &error($text{'misc_exauth'});
			&save_directive("XAuthLocation", $conf, $in{'xauth'});
			}
		}
	}

if ($version{'type'} eq 'ssh' && $version{'number'} < 2) {
	if ($in{'umask_def'}) {
		&save_directive("Umask", $conf);
		}
	else {
		$in{'umask'} =~ /^0[0-7][0-7][0-7]$/ ||
			&error($text{'misc_eumask'});
		&save_directive("Umask", $conf, $in{'umask'});
		}
	}

&save_directive("SyslogFacility", $conf,
		$in{'syslog_def'} ? undef : uc($in{'syslog'}));

if ($version{'type'} eq 'openssh') {
	&save_directive("LogLevel", $conf,
			$in{'loglevel_def'} ? undef : $in{'loglevel'});
	}

if ($version{'type'} ne 'ssh' || $version{'number'} < 2) {
	if ($in{'bits_def'}) {
		&save_directive("ServerKeyBits", $conf);
		}
	else {
		$in{'bits'} =~ /^\d+$/ || &error($text{'misc_ebits'});
		&save_directive("ServerKeyBits", $conf, $in{'bits'});
		}
	}

if ($version{'type'} eq 'ssh') {
	&save_directive("QuietMode", $conf, $in{'quite'} ? 'yes' : 'no');
	}

if ($version{'type'} ne 'ssh' || $version{'number'} < 2) {
	if ($in{'regen_def'}) {
		&save_directive("KeyRegenerationInterval", $conf);
		}
	else {
		$in{'regen'} =~ /^\d+$/ || &error($text{'misc_eregen'});
		&save_directive("KeyRegenerationInterval", $conf, $in{'regen'});
		}
	}

if ($version{'type'} eq 'ssh' && $version{'number'} < 2) {
	&save_directive("FascistLogging", $conf, $in{'fascist'} ? 'yes' : 'no');
	}

if ($version{'type'} eq 'openssh' && $version{'number'} >= 2) {
	if ($in{'pid_def'}) {
		&save_directive("PidFile", $conf);
		}
	else {
		$in{'pid'} =~ /^\S+$/ || &error($text{'misc_epid'});
		&save_directive("PidFile", $conf, $in{'pid'});
		}
	}

if ($version{'type'} eq 'openssh' && $version{'number'} >= 3.2) {
	&save_directive("UsePrivilegeSeparation", $conf,
			$in{'separ'} ? 'yes' : 'no');
	}

&flush_file_lines();
&unlock_file($config{'sshd_config'});
&webmin_log("misc");
&redirect("");

