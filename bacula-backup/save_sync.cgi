#!/usr/local/bin/perl
# Turn syncing on or off

require './bacula-backup-lib.pl';
&foreign_require("cron", "cron-lib.pl");
&ReadParse();
&error_setup($text{'sync_err'});

$job = $oldjob = &find_cron_job();
if ($in{'sched'}) {
	$job ||= { 'command' => $cron_cmd,
		   'user' => 'root',
		   'active' => 1 };
	&lock_file(&cron::cron_file($job));
	&cron::parse_times_input($job, \%in);
	&cron::create_wrapper($cron_cmd, $module_name, "sync.pl");
	if ($oldjob) {
		&cron::change_cron_job($job);
		}
	else {
		&cron::create_cron_job($job);
		}
	&unlock_file(&cron::cron_file($job));
	}
elsif ($job) {
	&lock_file(&cron::cron_file($job));
	&cron::delete_cron_job($job);
	&unlock_file(&cron::cron_file($job));
	}
&webmin_log("sync");
&redirect("");

