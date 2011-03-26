#!/usr/bin/perl
# Save bandwidth monitoring settings

require './itsecur-lib.pl';
&can_edit_error("bandwidth");
&ReadParse();
&foreign_require("bandwidth", "bandwidth-lib.pl");

if ($in{'enabled'}) {
	# Enable in config, so that log rules are generated
	$config{'bandwidth'} = $in{'iface'};
	&save_module_config();

	# Setup firewall and bandwidth modules
	$bandwidth::config{'iface'} = $in{'iface'};
	&bandwidth::save_module_config();
	$firewall::config{'direct'} = 1;
	&firewall::save_module_config();

	# Set up syslog.conf entry
	$conf = &syslog::get_config();
	$sysconf = &bandwidth::find_sysconf($conf);
	if (!$sysconf) {
		&lock_file($syslog::config{'syslog_conf'});
		&syslog::create_log({ 'file' => $bandwidth::bandwidth_log,
				      'active' => 1,
				      'sel' => [ "kern.=debug" ] });
		&unlock_file($syslog::config{'syslog_conf'});
		$err = &syslog::restart_syslog();
		&error($err) if ($err);
		}

	# Set up cron job
	$job = &bandwidth::find_cron_job();
	if (!$job) {
		&cron::create_wrapper($bandwidth::cron_cmd, $bandwidth::module_name, "rotate.pl");
		$job = { 'user' => 'root',
			 'active' => 1,
			 'command' => $bandwidth::cron_cmd,
			 'special' => 'hourly' };
		&lock_file(&cron::cron_file($job));
		&cron::create_cron_job($job);
		&unlock_file(&cron::cron_file($job));
		}
	}
else {
	# Disable in config
	$config{'bandwidth'} = undef;
	&save_module_config();

	# Remove cron job
	$job = &bandwidth::find_cron_job();
	if ($job) {
		&lock_file(&cron::cron_file($job));
		&cron::delete_cron_job($job);
		&unlock_file(&cron::cron_file($job));
		}


	}

&redirect("");

