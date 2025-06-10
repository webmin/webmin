#!/usr/local/bin/perl
# Setup, update or delete reporting cron job

require './sarg-lib.pl';
&foreign_require("cron", "cron-lib.pl");
@jobs = &cron::list_cron_jobs();
($oldjob) = grep { $_->{'user'} eq 'root' &&
		$_->{'command'} eq $cron_cmd } @jobs;
&ReadParse();

# Validate inputs
&error_setup($text{'sched_err'});
if ($oldjob) {
	$job = $oldjob;
	}
else {
	$job = { 'active' => 1,
		 'user' => 'root',
		 'command' => $cron_cmd };
	}
if ($in{'sched'}) {
	&cron::parse_times_input($job, \%in);
	&cron::create_wrapper($cron_cmd, $module_name, "generate.pl");
	}
if (!$in{'range_def'}) {
	$in{'rfrom'} =~ /^\d+$/ || &error($text{'sched_erfrom'});
	$in{'rto'} =~ /^\d+$/ || &error($text{'sched_erto'});
	}

&lock_file(&cron::cron_file($job));
if ($in{'sched'} && !$oldjob) {
	# Need to create
	&cron::create_cron_job($job);
	$mode = "create";
	}
elsif (!$in{'sched'} && $oldjob) {
	# Need to delete
	&cron::delete_cron_job($job);
	$mode = "delete";
	}
elsif ($in{'sched'} && $oldjob) {
	# Need to update
	&cron::change_cron_job($job);
	$mode = "update";
	}
else {
	$mode = "nothing";
	}
&unlock_file(&cron::cron_file($job));

# Save config settings
&lock_file($module_config_file);
$config{'clear'} = $in{'clear'};
$config{'range'} = $in{'range_def'} ? undef : $in{'rfrom'}." ".$in{'rto'};
&save_module_config();
&unlock_file($module_config_file);
&webmin_log("sched", undef, $mode);

&redirect("");

