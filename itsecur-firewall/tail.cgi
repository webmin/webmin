#!/usr/bin/perl

$trust_unknown_referers = 1;
require './itsecur-lib.pl';
&can_use_error("logs");
&ReadParse();
$| = 1;
$SIG{'HUP'} = sub { print "got HUP!\n"; };
$log = $config{'log'} || &get_log_file();
print "Content-type: text/plain\n\n";

# Get all the firewall log lines
open(LOG, $log);
while(<LOG>) {
	push(@log, $_) if (&is_log_line($_));
	shift(@log) if (@log > 20);
	}

# Show the last 20, and keep tailing
print @log;
while(1) {
	sleep(1);
	$line = <LOG>;
	print $line if ($line && &is_log_line($line));
	}

