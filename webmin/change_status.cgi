#!/usr/local/bin/perl
# Save status collection options

require './webmin-lib.pl';
&ReadParse();
&foreign_require("system-status");
&error_setup($text{'status_err'});

# Save collection interval
if ($in{'interval_def'}) {
	$system_status::config{'collect_interval'} = 'none';
	}
else {
	$in{'interval'} =~ /^\d+$/ && $in{'interval'} > 0 &&
	   $in{'interval'} <= 60 || &error($text{'status_einterval'});
	$system_status::config{'collect_interval'} = $in{'interval'};
	}

# Save collection options
$system_status::config{'collect_pkgs'} = $in{'pkgs'};
$system_status::config{'collect_notemp'} = !$in{'temp'};
$system_status::config{'collect_units'} = $in{'units'};

&lock_file($system_status::module_config_file);
&save_module_config(\%system_status::config, 'system-status');
&unlock_file($system_status::module_config_file);
&system_status::setup_collectinfo_job();
if ($in{'interval_def'}) {
	&unlink_file($system_status::collected_info_file);
	}
else {
	&system_status::scheduled_collect_system_info();
	}

&webmin_log("status");
&redirect("");

