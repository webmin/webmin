#!/usr/local/bin/perl
# Update scheduled checking

require './cluster-shutdown-lib.pl';
&ReadParse();
&error_setup($text{'sched_err'});

# Validate and store inputs
$job = &find_cron_job();
if ($in{'sched'}) {
	$in{'email'} =~ /\S/ || &error($text{'sched_eemail'});
	$config{'email'} = $in{'email'};
	if ($in{'smtp_def'}) {
		delete($config{'smtp'});
		}
	else {
		&to_ipaddress($in{'smtp'}) || &to_ip6address($in{'smtp'}) ||
			&error($text{'sched_esmtp'});
		$config{'smtp'} = $in{'smtp'};
		}
	&save_module_config();
	}

# Create or delete cron job
&cron::create_wrapper($cron_cmd, $module_name, "check.pl");
if ($in{'sched'} && !$job) {
	$job = { 'command' => $cron_cmd,
		 'user' => 'root',
		 'active' => 1,
		 'mins' => '*/5',
		 'hours' => '*',
		 'days' => '*',
		 'months' => '*',
		 'weekdays' => '*',
		};
	&cron::create_cron_job($job);
	}
elsif (!$in{'sched'} && $job) {
	&cron::delete_cron_job($job);
	}

# Tell the user
&ui_print_header(undef, $text{'sched_title'}, "");

if ($in{'sched'}) {
	print $text{'sched_enabled'},"<p>\n";
	}
else {
	print $text{'sched_disabled'},"<p>\n";
	}

&ui_print_footer("", $text{'index_return'});

