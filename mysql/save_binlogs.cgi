#!/usr/local/bin/perl
# Save binary logging configuration options

require './mysql-lib.pl';
$access{'perms'} == 1 || &error($text{'binlogs_ecannot'});
&is_mysql_local() || &error($text{'binlogs_eremote'});
&error_setup($text{'binlogs_err'});
&ReadParse();

# Get the mysqld section
foreach my $l (&get_all_mysqld_files()) {
	&lock_file($l);
	}
$conf = &get_mysql_config();
# Prefer the main server section over generic MariaDB sections that can
# belong to a plugin-specific include file
($mysqld) = grep { $_->{'name'} eq 'mysqld' } @$conf;
($mysqld) = grep { $_->{'name'} eq 'mariadbd' } @$conf if (!$mysqld);
($mysqld) = grep { $_->{'name'} eq 'mariadb' } @$conf if (!$mysqld);
$mysqld || &error($text{'cnf_emysqld'});
$mems = $mysqld->{'members'};

if ($in{'enabled'}) {
	# Work out the base directive, preserving an existing or active default
	# so that merely saving this page cannot start a new binary log chain.
	# On servers that log by default the directive is also left absent, as
	# writing one would change the default base name even when stopped
	my $lbdir = &find("log_bin", $mems) || &find("log-bin", $mems);
	my $baseargs;
	if ($in{'base_def'}) {
		if ($lbdir) {
			$baseargs = [ $lbdir->{'value'} // "" ];
			}
		else {
			my ($curfile) = &get_binary_log_status();
			$baseargs = $curfile || &get_binlog_default_on() ?
					[ ] : [ "mysql-bin" ];
			}
		}
	else {
		$in{'base'} =~ /^[a-zA-Z0-9\.\-\_\/]+$/ ||
			&error($text{'binlogs_ebase'});
		$baseargs = [ $in{'base'} ];
		}
	&save_directive($conf, $mysqld, "log-bin", [ ]);
	&save_directive($conf, $mysqld, "log_bin", $baseargs);

	# Remove any directives that force binary logging off
	foreach my $s ("skip-log-bin", "skip_log_bin",
		       "disable-log-bin", "disable_log_bin") {
		&save_directive($conf, $mysqld, $s, [ ]);
		}

	# A unique server ID is required by MySQL for binary logging
	my $sid = &find_value("server_id", $mems);
	$sid = &find_value("server-id", $mems) if (!defined($sid));
	if ($in{'serverid_def'}) {
		if (!defined($sid)) {
			&save_directive($conf, $mysqld, "server_id", [ 1 ]);
			}
		}
	else {
		$in{'serverid'} =~ /^\d+$/ && $in{'serverid'} >= 1 &&
		    $in{'serverid'} <= 4294967295 ||
			&error($text{'binlogs_eserverid'});
		&save_directive($conf, $mysqld, "server-id", [ ]);
		&save_directive($conf, $mysqld, "server_id",
				[ $in{'serverid'} ]);
		}
	}
else {
	# Remove the directive under both possible names, and force logging
	# off in case the server enables it by default (as MySQL 8+ does)
	&save_directive($conf, $mysqld, "log-bin", [ ]);
	&save_directive($conf, $mysqld, "log_bin", [ ]);
	foreach my $s ("skip_log_bin", "disable-log-bin",
		       "disable_log_bin") {
		&save_directive($conf, $mysqld, $s, [ ]);
		}
	&save_directive($conf, $mysqld, "skip-log-bin", [ "" ]);
	}

# Save the binary log format
if (defined($in{'format'})) {
	$in{'format'} =~ /^(|ROW|MIXED|STATEMENT)$/ ||
		&error($text{'binlogs_eformat'});
	&save_directive($conf, $mysqld, "binlog-format", [ ]);
	&save_directive($conf, $mysqld, "binlog_format",
			$in{'format'} ? [ $in{'format'} ] : [ ]);
	}

# Save the maximum size of one log file, which the server limits to the
# range from 4 kB to 1 GB
if ($in{'maxsize_def'}) {
	&save_directive($conf, $mysqld, "max-binlog-size", [ ]);
	&save_directive($conf, $mysqld, "max_binlog_size", [ ]);
	}
else {
	$in{'maxsize'} =~ /^\d+$/ ||
		&error($text{'binlogs_emaxsize'});
	defined(&parse_binlog_max_size($in{'maxsize'},
				       $in{'maxsize_units'})) ||
		&error($text{'binlogs_emaxsizerange'});
	&save_directive($conf, $mysqld, "max-binlog-size", [ ]);
	&save_directive($conf, $mysqld, "max_binlog_size",
			[ $in{'maxsize'}.$in{'maxsize_units'} ]);
	}

# Save the retention period, preferring the seconds-based variable on
# servers that support it as it also allows fractional days
my ($ver, $variant) = &get_mysql_variant_cached();
my $newexpire = $variant eq "mysql" &&
		&compare_version_numbers($ver, "8.0") >= 0 ||
		$variant eq "mariadb" &&
		&compare_version_numbers($ver, "10.6") >= 0;
if ($in{'expire_def'}) {
	&save_directive($conf, $mysqld, "binlog_expire_logs_seconds", [ ]);
	&save_directive($conf, $mysqld, "expire_logs_days", [ ]);
	}
else {
	# Fractional days are allowed, and zero disables automatic deletion
	$in{'expire'} =~ /^\d+(\.\d+)?$/ ||
		&error($text{'binlogs_eexpire'});
	my $days = $in{'expire'} + 0;
	if ($newexpire) {
		# The seconds variable is limited to 32 bits
		my $secs = &parse_binlog_expire_days($days);
		$secs <= 4294967295 ||
			&error(&text('binlogs_eexpiremax',
				&format_binlog_expire_days(4294967295)));
		&save_directive($conf, $mysqld, "expire_logs_days", [ ]);
		&save_directive($conf, $mysqld, "binlog_expire_logs_seconds",
				[ $secs ]);
		}
	else {
		# The days variable is limited to 99 whole days on servers
		# without the seconds-based variable
		$days <= 99 ||
			&error(&text('binlogs_eexpiremax', 99));
		$days == int($days) ||
			&error($text{'binlogs_eexpireint'});
		&save_directive($conf, $mysqld, "binlog_expire_logs_seconds",
				[ ]);
		&save_directive($conf, $mysqld, "expire_logs_days",
				[ $days ]);
		}
	}

# Write out file, and restart if requested
foreach my $l (&get_all_mysqld_files()) {
	&flush_file_lines($l, undef, 1);
	&unlock_file($l);
	}
if ($in{'restart'} && &is_mysql_running() > 0) {
	&stop_mysql();
	$err = &start_mysql();
	&error($err) if ($err);
	}
&webmin_log("binlogs");
&redirect("edit_binlogs.cgi");
