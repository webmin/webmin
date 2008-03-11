#!/usr/local/bin/perl
# save_cron.cgi
# Create, update or delete a cron job for fetchmail

require './fetchmail-lib.pl';
&foreign_require("cron", "cron-lib.pl");
$can_cron || &error($text{'cron_ecannot2'});
&error_setup($text{'cron_err'});
&ReadParse();

@jobs = &cron::list_cron_jobs();
($job) = grep { $_->{'user'} eq $cron_user &&
		$_->{'command'} =~ /^$cron_cmd/ } @jobs;
	   
# Validate inputs
$cmd = $cron_cmd;
if ($in{'output'} == 0) {
	$cmd .= " --null";
	}
elsif ($in{'output'} == 1) {
	$in{'file'} =~ /^\/.+$/ || &error($text{'cron_efile'});
	$cmd .= " --file ".quotemeta($in{'file'});
	}
elsif ($in{'output'} == 2) {
	$in{'mail'} =~ /^\S+$/ || &error($text{'cron_efile'});
	$cmd .= " --mail ".quotemeta($in{'mail'});
	}
elsif ($in{'output'} == 3) {
	$cmd .= " --output";
	}
elsif ($in{'output'} == 4) {
	$cmd .= " --owner";
	}
if ($in{'errors'}) {
	$cmd .= " --errors";
	}
if ($cron_user eq "root" && $fetchmail_config) {
	defined(getpwnam($in{'user'})) || &error($text{'cron_euser'});
	$cmd .= " --user $in{'user'}";
	}

if ($job && $in{'enabled'}) {
	# Update cron job
	$job->{'command'} = $cmd;
	&cron::parse_times_input($job, \%in);
	&lock_file(&cron::cron_file($job));
	&cron::change_cron_job($job);
	$what = "update";
	}
elsif (!$job && $in{'enabled'}) {
	# Create job
	$job = { 'user' => $cron_user,
		 'command' => $cmd,
		 'active' => 1 };
	&cron::parse_times_input($job, \%in);
	&lock_file($cron_cmd);
	&lock_file(&cron::cron_file($job));
	&cron::create_cron_job($job);
	$what = "create";
	}
elsif ($job && !$in{'enabled'}) {
	# Delete job
	&lock_file(&cron::cron_file($job));
	&cron::delete_cron_job($job);
	$what = "delete";
	}
&cron::create_wrapper($cron_cmd, $module_name, "check.pl");
&unlock_all_files();
&webmin_log($what, "cron");
&redirect("");


