#!/usr/local/bin/perl
# Add needed firewall rules and syslog entry, and apply configurations

require './bandwidth-lib.pl';
&ReadParse();
$access{'setup'} || &error($text{'setup_ecannot'});

# Work out interface
$iface = $in{'iface'} || $in{'other'};
$iface =~ /^\S+$/ || &error($text{'setup_eiface'});

# Add missing firewall rules
$err = &setup_rules($iface);
&error($err) if ($err);

if ($syslog_module eq "syslog") {
	# Add syslog entry
	$conf = &syslog::get_config();
	$sysconf = &find_sysconf($conf);
	if (!$sysconf) {
		&lock_file($syslog::config{'syslog_conf'});
		if ($syslog::config{'tags'}) {
			local $conf = &syslog::get_config();
			($tag) = grep { $_->{'tag'} eq '*' } @$conf;
			}
		&syslog::create_log({ 'file' => $bandwidth_log,
				      'active' => 1,
				      'section' => $tag,
				      'sel' => [ &get_loglevel() ] });
		&unlock_file($syslog::config{'syslog_conf'});
		$err = &syslog::restart_syslog();
		&error($err) if ($err);
		}
	}
else {
	# Add syslog-ng entry
	$conf = &syslog_ng::get_config();
	($dest, $filter, $log) = &find_sysconf_ng($conf);
	&lock_file($syslog_ng::config{'syslogng_conf'});
	if (!$dest) {
		# Create destination file entry
		$dest = { 'name' => 'destination',
			  'type' => 1,
			  'values' => [ 'd_bandwidth' ],
			  'members' => [
				{ 'name' => 'file',
				  'values' => [ $bandwidth_log ] }
					]
			};
		&syslog_ng::save_directive($conf, undef, undef, $dest, 0);
		}
	if (!$filter) {
		# Create filter for facility and level
		local @ll = &get_loglevel();
		($fac, $lvl) = split(/\./, $ll[0]);
		$lvl =~ s/^=//;
		$filter = { 'name' => 'filter',
			    'type' => 1,
			    'values' => [ 'f_bandwidth' ],
			    'members' => [ ]
			  };
		if ($fac ne "*") {
			push(@{$filter->{'members'}},
			     { 'name' => 'facility',
			       'values' => [ $fac ] });
			}
		if ($fac ne "*" && $lvl ne "*") {
			push(@{$filter->{'members'}}, "and");
			}
		if ($lvl ne "*") {
			push(@{$filter->{'members'}},
			     { 'name' => 'priority',
			       'values' => [ $lvl ] });
			}
		&syslog_ng::save_directive($conf, undef, undef, $filter, 0);
		}
	if (!$log) {
		# Create log for the default source, destination and filter
		@sources = &syslog_ng::find("source", $conf);
		$log = { 'name' => 'log',
			 'type' => 1,
			 'values' => [ ],
			 'members' => [
				{ 'name' => 'source',
				  'values' => [ $sources[0]->{'value'} ], },
				{ 'name' => 'filter',
				  'values' => [ "f_bandwidth" ], },
				{ 'name' => 'destination',
				  'values' => [ "d_bandwidth" ], },
					]
			};
		&syslog_ng::save_directive($conf, undef, undef, $log, 0);
		}
	&unlock_file($syslog_ng::config{'syslogng_conf'});
	}

# Save the interface
&lock_file($module_config_file);
$config{'iface'} = $iface;
&save_module_config();
&unlock_file($module_config_file);

# Setup the rotation cron job
$job = &find_cron_job();
if (!$job) {
	&cron::create_wrapper($cron_cmd, $module_name, "rotate.pl");
	$job = { 'user' => 'root',
		 'active' => 1,
		 'command' => $cron_cmd,
		 'mins' => '0',
		 'hours' => '*',
		 'days' => '*',
		 'months' => '*',
		 'weekdays' => '*',
		};
	&lock_file(&cron::cron_file($job));
	&cron::create_cron_job($job);
	&unlock_file(&cron::cron_file($job));
	}

&webmin_log("setup", undef, $iface);
&redirect("");

