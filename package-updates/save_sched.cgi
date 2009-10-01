#!/usr/local/bin/perl
# Save scheduled checking options

require './package-updates-lib.pl';
&ReadParse();

&lock_file($module_config_file);
$config{'sched_email'} = $in{'email'};
$config{'sched_action'} = $in{'action'};
&save_module_config();
&unlock_file($module_config_file);

$oldjob = $job = &find_cron_job();
if ($in{'sched_def'}) {
	if ($job) {
		&lock_file(&cron::cron_file($job));
		&cron::delete_cron_job($job);
		&unlock_file(&cron::cron_file($job));
		}
	$msg = $text{'sched_no'};
	}
else {
	$job ||= { 'user' => 'root',
		   'active' => 1,
		   'command' => $cron_cmd };
	$job->{'mins'} = $job->{'hours'} = $job->{'days'} =
		$job->{'months'} = $job->{'weekdays'} = '*';
	if ($in{'sched'} eq 'h') {
		$job->{'mins'} = '0';
		}
	elsif ($in{'sched'} eq 'd') {
		$job->{'mins'} = '0';
		$job->{'hours'} = '0';
		}
	elsif ($in{'sched'} eq 'w') {
		$job->{'mins'} = '0';
		$job->{'hours'} = '0';
		$job->{'weekdays'} = '0';
		}
	&lock_file(&cron::cron_file($job));
	if ($oldjob) {
		&cron::change_cron_job($job);
		}
	else {
		&cron::create_cron_job($job);
		}
	&unlock_file(&cron::cron_file($job));
	&lock_file($cron_cmd);
	&cron::create_wrapper($cron_cmd, $module_name, "update.pl");
	&unlock_file($cron_cmd);
	$msg = $text{'sched_yes'};
	}

# Tell the user
&ui_print_header(undef, $text{'sched_title'}, "");

print "$msg<p>\n";

&ui_print_footer("", $text{'index_return'});
&webmin_log("sched", undef, $in{'sched_def'} ? 0 : 1);

