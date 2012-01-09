#!/usr/local/bin/perl
# webalizer.pl
# Generate a report on schedule

$no_acl_check++;
require './webalizer-lib.pl';
$lconf = &get_log_config($ARGV[0]);
$lconf || die "Logfile $ARGV[0] config file does not exist";

open(NULL, ">/dev/null");
&clean_language();
$ok = &generate_report($ARGV[0], NULL, 0);
&reset_environment();
close(NULL);

if ($ok && $lconf->{'clear'}) {
	# Truncate or delete the files for this report
	foreach $f (&all_log_files($ARGV[0])) {
		next if (!-r $f);
		if ($f eq $ARGV[0]) {
			# Just truncate the main log file
			truncate($f, 0);
			}
		else {
			# Delete any extra compressed files
			unlink($f);
			}
		}
	}

