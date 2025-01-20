#!/usr/local/bin/perl
# Parse the firewall log and rotate it

$no_acl_check++;
use Time::Local;
require './bandwidth-lib.pl';

our (%config, $module_config_file, $module_var_directory, $pid_file,
     $syslog_module, $syslog_journald);

my ($logfh, $timestamp_file, $bandwidth_log, $lastline);

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

# Scan the entries in the log file
&pre_process();
open(LOG, "<".$bandwidth_log);
while(<LOG>) {
	if (&process_line($_, \@hours, $time_now)) {
		# Found a valid line
		$lastline = $_;
		}
	elsif (/last\s+message\s+repeated\s+(\d+)/) {
		# re-process the last line N-1 times
		for($i=0; $i<$1-1; $i++) {
			&process_line($lastline, \@hours, $time_now);
			}
		}
	else {
		#print "skipping $_";
		}
	}
close(LOG);

# Save all hours
foreach my $hour (@hours) {
	&save_hour($hour);
	}

# Truncate the file (if it exists) and notify syslog
if (-r $bandwidth_log) {
	open(my $log, ">".$bandwidth_log);
	close($log);
	}
&foreign_call($syslog_module, "signal_syslog");

# Remove PID file
unlink($pid_file);

# Exit with success
exit(0);