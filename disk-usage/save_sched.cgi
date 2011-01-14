#!/usr/local/bin/perl
# Create, update or edit the scheduled checking job

require './disk-usage-lib.pl';
&foreign_require("cron", "cron-lib.pl");
&error_setup($text{'sched_err'});
$oldjob = $job = &find_cron_job();
&ReadParse();

if ($in{'enabled'}) {
	# Validate inputs
	$job ||= { 'user' => 'root',
		   'command' => $cron_cmd,
		   'active' => 1 };
	&cron::parse_times_input($job, \%in);
	if ($oldjob) {
		&cron::change_cron_job($job);
		}
	else {
		&cron::create_cron_job($job);
		}
	&cron::create_wrapper($cron_cmd, $module_name, "usage.pl");
	}
else {
	&cron::delete_cron_job($job) if ($job);
	}
&redirect("");

