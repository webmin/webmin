#!/usr/local/bin/perl
# Save scheduled finding of servers
# Thanks to OpenCountry for sponsoring this feature

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './servers-lib.pl';
our (%in, %text, $module_name, $cron_cmd, @cluster_modules, %config, %access);
$access{'auto'} || &error($text{'auto_ecannot'});
&ReadParse();
&error_setup($text{'auto_err'});

my $job = &find_cron_job();

# Validate inputs
if ($in{'sched'}) {
	$in{'mins'} =~ /^\d+$/ && $in{'mins'} > 0 || &error($text{'auto_emins'});
	if ($in{'net_def'} == 1) {
		$config{'auto_net'} = undef;
		}
	elsif ($in{'net_def'} == 0) {
		my @nets = split(/\s+/, $in{'net'});
		foreach my $n (@nets) {
			&check_ipaddress($n) ||
				&error($text{'auto_enet'});
			}
		$config{'auto_net'} = $in{'net'};
		}
	else {
		$in{'iface'} =~ /^[a-z]+\d*(:\d+)?$/ ||
			&error($text{'auto_eiface'});
		$config{'auto_net'} = $in{'iface'};
		}
	$in{'auser'} =~ /\S/ || &error($text{'auto_euser'});
	$config{'auto_user'} = $in{'auser'};
	$config{'auto_pass'} = $in{'apass'};
	$config{'auto_type'} = $in{'type'};
	foreach my $m (@cluster_modules) {
		if (&foreign_available($m)) {
			$config{'auto_'.$m} = $in{$m};
			}
		}
	$config{'auto_remove'} = $in{'remove'};
	$config{'auto_self'} = $in{'self'};
	$in{'email_def'} || $in{'email'} =~ /\S/ ||&error($text{'auto_eemail'});
	$config{'auto_email'} = $in{'email_def'} ? undef : $in{'email'};
	$in{'smtp_def'} || &to_ipaddress($in{'smtp'}) ||
	    &to_ip6address($in{'smtp'}) ||
		&error($text{'auto_esmtp'});
	$config{'auto_smtp'} = $in{'smtp_def'} ? undef : $in{'smtp'};
	&save_module_config();
	}

# Create or update Cron job
&cron::create_wrapper($cron_cmd, $module_name, "auto.pl");
my @mins;
if ($in{'sched'}) {
	# Work out minutes
	for(my $i=0; $i<60; $i+=$in{'mins'}) {
		push(@mins, $i);
		}
	}
if ($in{'sched'} && !$job) {
	# Create the job
	$job = { 'user' => 'root',
		 'command' => $cron_cmd,
		 'active' => 1,
		 'mins' => join(",", @mins),
		 'hours' => '*',
		 'days' => '*',
		 'months' => '*',
		 'weekdays' => '*',
		};
	&cron::create_cron_job($job);
	}
elsif (!$in{'sched'} && $job) {
	# Delete the job
	&cron::delete_cron_job($job);
	}
elsif ($in{'sched'} && $job) {
	# Update the job
	$job->{'mins'} = join(",", @mins);
	$job->{'hours'} = $job->{'days'} =
	    $job->{'months'} = $job->{'weekdays'} = '*';
	&cron::change_cron_job($job);
	}

&redirect("");

