#!/usr/local/bin/perl
# A wrapper which runs some Perl script or command as a service

BEGIN { open(ERR, ">c:/temp/win32.err");
	print ERR "Starting ..\n"; };

use Win32::Daemon;

# Tell the OS to start processing the service...
Win32::Daemon::StartService();

# Note: Added for convenience: The numeric codes for the Windows
# Service states:
#
# SERVICE_NOT_READY = 0
# SERVICE_STOPPED = 1
# SERVICE_START_PENDING = 2
# SERVICE_STOP_PENDING = 3
# SERVICE_RUNNING = 4
# SERVICE_CONTINUE_PENDING = 5
# SERVICE_PAUSE_PENDING = 6
# SERVICE_PAUSED = 7
# Wait until the service manager is ready for us to continue...

while( SERVICE_START_PENDING != Win32::Daemon::State() ) {
	sleep( 1 );
	}

# Now let the service manager know that we are running...
# This needs to be here, not after the client process exits, 
# otherwise the service will be in SERVICE_START_PENDING when
# it is up.
Win32::Daemon::State( SERVICE_RUNNING );
	
# Added (CRH): We need to replace the forward slashes with double 
# backslashes only in the first argument to the function. For some
# reason the service manager expects double backslashes.
$argone=shift @ARGV;
$argone=~s/\//\\\\/g;
unshift @ARGV, $argone;

# Start the program in a sub-process
%before = map { $_, 1 } &get_procs();
$pid = fork();
if (!$pid) {
	system(@ARGV);
	exit(1);
	}

$pid = -$pid;
print ERR "pid = $pid\n";
@after = &get_procs();
@new = grep { !$before{$_} } @after;


# Wait for messages
while(1) {
	sleep(5);
	if (Win32::Daemon::State() == SERVICE_STOP_PENDING ||
	    Win32::Daemon::State() == SERVICE_CONTROL_SHUTDOWN) {
		# Need to kill it
		foreach $p (@new) {
			print ERR "Killing process $p\n";
			system("process.exe -k $p");
			}
		last;
		}
	}

# Tell the OS that the service is terminating...
Win32::Daemon::StopService();

# Returns a list of process IDs
sub get_procs
{
local @rv;
open(PROC, "process.exe |");
while(<PROC>) {
	if (/^\s*(\S+)\s+(\d+)\s+(\d+)/) {
		push(@rv, $2);
		}
	}
close(PROC);
return @rv;
}

