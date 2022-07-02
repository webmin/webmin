#!/usr/local/bin/perl
# Save player time limits

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './minecraft-lib.pl';
our (%in, %text, %config, $module_config_file, $module_name);
&ReadParse();
&foreign_require("webmincron");
&error_setup($text{'playtime_err'});

# Validate and save inputs
$config{'playtime_enabled'} = $in{'enabled'};

$in{'max_def'} || $in{'max'} =~ /^\d+$/ || &error($text{'playtime_emax'});
$config{'playtime_max'} = $in{'max_def'} ? undef : $in{'max'};

$in{'users_def'} || $in{'users'} =~ /\S/ || &error($text{'playtime_eusers'});
$config{'playtime_users'} = $in{'users_def'} ? undef : $in{'users'};

$in{'days'} =~ /\S/ || &error($text{'playtime_edays'});
$config{'playtime_days'} = join(" ", split(/\0/, $in{'days'}));

$in{'ips_def'} || $in{'ips'} =~ /\S/ || &error($text{'playtime_eips'});
$config{'playtime_ips'} = $in{'ips_def'} ? undef : $in{'ips'};

&lock_file($module_config_file);
&save_module_config(\%config);
&unlock_file($module_config_file);

# Setup or disable cron job
my $job = &get_playtime_job();
if (!$in{'enabled'}) {
	if ($job) {
		&webmincron::delete_webmin_cron($job);
		}
	}
else {
	$job ||= { 'module' => $module_name,
		   'interval' => 6*60,
		   'func' => 'check_playtime_limits' };
	&webmincron::save_webmin_cron($job);
	}

&webmin_log("playtime");
&redirect("");
