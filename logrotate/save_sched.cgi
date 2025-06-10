#!/usr/local/bin/perl
# save_sched.cgi
# Create, update or delete the rotation cron job

require './logrotate-lib.pl';
&ReadParse();

&foreign_require("cron", "cron-lib.pl");
@jobs = &cron::list_cron_jobs();
if ($in{'idx'} ne "") {
	$oldjob = $job = $jobs[$in{'idx'}];
	}
else {
	$job = { 'user' => 'root',
		 'command' => &has_command($config{'logrotate'})." ".
			      $config{'logrotate_conf'},
		 'active' => 1 };
	}
&lock_file(&cron::cron_file($job));

&error_setup($text{'sched_err'});
&cron::parse_times_input($job, \%in) if ($in{'sched'});

if ($oldjob && $in{'sched'}) {
	# Just update
	&cron::change_cron_job($job);
	$action = "modify";
	}
elsif ($oldjob && !$in{'sched'}) {
	# Delete
	&cron::delete_cron_job($job);
	$action = "delete";
	}
elsif (!$oldjob && $in{'sched'}) {
	# Create new
	&cron::create_cron_job($job);
	$action = "create";
	}

&unlock_file(&cron::cron_file($job));
&webmin_log($action, "sched");

&redirect("");

