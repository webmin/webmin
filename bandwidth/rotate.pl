#!/usr/local/bin/perl
# Parse the firewall log and rotate it

$no_acl_check++;
require './bandwidth-lib.pl';
use Time::Local;

# Detect firewall system if needed
if (!$config{'firewall_system'}) {
	$sys = &detect_firewall_system();
	if ($sys) {
		$config{'firewall_system'} = $sys;
		&save_module_config();
		}
	else {
		die "Failed to detect firewall system!";
		}
	}

# See if this process is already running
if ($pid = &check_pid_file($pid_file)) {
	print STDERR "rotate.pl process $pid is already running\n";
	exit;
	}
open(PID, ">$pid_file");
print PID $$,"\n";
close(PID);

$time_now = time();
@time_now = localtime($time_now);
@hours = ( );

# Scan the entries in the log file
&pre_process();
open(LOG, $bandwidth_log);
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
foreach $hour (@hours) {
	&save_hour($hour);
	}

# Truncate the file (if it exists) and notify syslog
if (-r $bandwidth_log) {
	open(LOG, ">$bandwidth_log");
	close(LOG);
	}
&foreign_call($syslog_module, "signal_syslog");

# Remove PID file
unlink($pid_file);

