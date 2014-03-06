#!/usr/local/bin/perl
# webalizer.pl
# Generate a report on schedule

use strict;
use warnings;
our ($no_acl_check, %config);
$no_acl_check++;
require './webalizer-lib.pl';
my $lconf = &get_log_config($ARGV[0]);
$lconf || die "Logfile $ARGV[0] config file does not exist";

my $fh;
open($fh, ">/dev/null");
&clean_language();
my $ok = &generate_report($ARGV[0], $fh, 0);
&reset_environment();
close($fh);

if ($ok && $lconf->{'clear'}) {
	# Truncate or delete the files for this report
	my @files = $config{'skip_old'} ? ( $ARGV[0] )
					: &all_log_files($ARGV[0]);
	foreach my $f (@files) {
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

