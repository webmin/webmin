#!/usr/local/bin/perl
# Turn on or off the DNSSEC key rotation cron job
use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%access, %text, %in, %config);
our $dnssec_cron_cmd;
our $module_name;
our $module_config_file;

require './bind8-lib.pl';
&foreign_require("cron", "cron-lib.pl");
&ReadParse();
&error_setup($text{'dnssec_err'});
$access{'defaults'} || &error($text{'dnssec_ecannot'});

$in{'period'} =~ /^[1-9]\d*$/ || &error($text{'dnssec_eperiod'});
$in{'period'} < 30 || &error($text{'dnssec_eperiod30'});

# Create or delete the cron job
my $job = &get_dnssec_cron_job();
if ($job && !$in{'enabled'}) {
	# Turn off cron job
	&lock_file(&cron::cron_file($job));
	&cron::delete_cron_job($job);
	&unlock_file(&cron::cron_file($job));
	}
elsif (!$job && $in{'enabled'}) {
	# Turn on cron job
	$job = { 'user' => 'root',
		 'active' => 1,
		 'command' => $dnssec_cron_cmd,
		 'mins' => int(rand()*60),
		 'hours' => int(rand()*24),
		 'days' => '*',
		 'months' => '*',
		 'weekdays' => '*' };
	&lock_file(&cron::cron_file($job));
	&cron::create_cron_job($job);
	&unlock_file(&cron::cron_file($job));
	}
&cron::create_wrapper($dnssec_cron_cmd, $module_name, "resign.pl");

&lock_file($module_config_file);
$config{'dnssec_period'} = $in{'period'};
&save_module_config();
&unlock_file($module_config_file);

&webmin_log("dnssec");
&redirect("");

