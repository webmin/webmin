#!/usr/local/bin/perl
# Parse the firewall log and rotate it

$no_acl_check++;
use Time::Local;
require './bandwidth-lib.pl';

our (%config, $module_config_file, $module_var_directory, $pid_file,
     $syslog_module, $syslog_journald, $bandwidth_log);

my ($logfh, $timestamp_file, $lastline);

# Detect firewall system if needed
if (!$config{'firewall_system'}) {
	my $sys = &detect_firewall_system();
	if ($sys) {
		$config{'firewall_system'} = $sys;
		&lock_file($module_config_file);
		&save_module_config();
		&unlock_file($module_config_file);
		}
	else {
		die("Failed to detect firewall system!\n");
		}
	}

# See if this process is already running
if (my $pid = &check_pid_file($pid_file)) {
	print STDERR "rotate.pl process $pid is already running\n";
	exit(1);
	}
open(my $pid, ">$pid_file");
print $pid $$,"\n";
close($pid);

# Get the current time
my $time_now = time();
my @time_now = localtime($time_now);
my @hours = ( );

# Pre-process command
&pre_process();

# Open the log file or pipe to journalctl
if ($syslog_journald) {
	$timestamp_file = "$module_var_directory/last-processed";
	my $last_processed = 0;
	if (-r $timestamp_file) {
		$last_processed = &read_file_contents($timestamp_file);
		chomp($last_processed);
		$last_processed = int($last_processed) || 0;
		}
	my $journal_cmd = &has_command("journalctl");
	$journal_cmd = "$journal_cmd -k --since=\@$last_processed ".
		       "--until=\@$time_now --grep=\"BANDWIDTH_(IN|OUT):\"";
	open($logfh, '-|', $journal_cmd) ||
		die("Cannot open $journal_cmd pipe: $!\n");
	}
else {
	open($logfh, "<".$bandwidth_log) ||
		die("Cannot open $bandwidth_log: $!\n");
	}

# Scan the entries in the log file
while(<$logfh>) {
	if (&process_line($_, \@hours, $time_now)) {
		# Found a valid line
		$lastline = $_;
		}
	elsif (/last\s+message\s+repeated\s+(\d+)/) {
		# re-process the last line N-1 times
		for(my $i=0; $i<$1-1; $i++) {
			&process_line($lastline, \@hours, $time_now);
			}
		}
	else {
		#print "skipping $_";
		}
	}
close($logfh);

# Save all hours
foreach my $hour (@hours) {
	&save_hour($hour);
	}

# Truncate the file (if it exists) and notify syslog
if (-r $bandwidth_log) {
	open(my $log, ">".$bandwidth_log);
	close($log);
	}
&foreign_call($syslog_module, "signal_syslog") if (!$syslog_journald);

# Save last collection time to start from here next time
if ($syslog_journald && @hours) {
	&lock_file($timestamp_file);
	&write_file_contents($timestamp_file, $time_now);
	&unlock_file($timestamp_file);
	}

# Remove PID file
unlink($pid_file);

# Exit with success
exit(0);