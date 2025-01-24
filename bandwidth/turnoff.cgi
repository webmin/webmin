#!/usr/local/bin/perl
# Remove firewall rules and syslog entry

require './bandwidth-lib.pl';
&ReadParse();
$access{'setup'} || &error($text{'turnoff_ecannot'});

# Remove firewall rules
$err = &delete_rules();
&error($err) if ($err);

if ($syslog_journald) {
	# Systemd journal
	# Nothing to do
	}
elsif ($syslog_module eq "syslog") {
	# Remove syslog entry
	$conf = &syslog::get_config();
	$sysconf = &find_sysconf($conf);
	if ($sysconf) {
		&lock_file($syslog::config{'syslog_conf'});
		&syslog::delete_log($sysconf);
		&unlock_file($syslog::config{'syslog_conf'});
		$err = &syslog::restart_syslog();
		&error($err) if ($err);
		}
	}
elsif ($syslog_module eq "syslog-ng") {
	# Remove syslog-ng entries
	$conf = &syslog_ng::get_config();
	($dest, $filter, $log) = &find_sysconf_ng($conf);
	&lock_file($syslog_ng::config{'syslogng_conf'});
	if ($dest) {
		&syslog_ng::save_directive($conf, undef, $dest, undef, 0);
		}
	if ($filter) {
		&syslog_ng::save_directive($conf, undef, $filter, undef, 0);
		}
	if ($log) {
		&syslog_ng::save_directive($conf, undef, $log, undef, 0);
		}
	&unlock_file($syslog_ng::config{'syslogng_conf'});
	}

# Remove rotation cron job
$job = &find_cron_job();
if ($job) {
	&lock_file(&cron::cron_file($job));
	&cron::delete_cron_job($job);
	&unlock_file(&cron::cron_file($job));
	}

&webmin_log("turnoff");
&redirect("");

