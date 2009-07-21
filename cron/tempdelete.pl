#!/usr/local/bin/perl
# Delete any Webmin temp files older than 7 days

$no_acl_check++;
require './cron-lib.pl';

if ($ARGV[0] eq "-debug" || $ARGV[0] eq "--debug") {
	shift(@ARGV);
	$debug = 1;
	}

# Don't run if disabled
if (!$gconfig{'tempdelete_days'}) {
	print "Temp file clearing is disabled\n";
	exit(0);
	}
if ($gconfig{'tempdir'} && !$gconfig{'tempdirdelete'}) {
	print "Temp file clearing is not done for the custom directory $gconfig{'tempdir'}\n";
	exit(0);
	}

$tempdir = &transname();
$tempdir =~ s/\/([^\/]+)$//;
if ($debug) {
	print "Checking temp directory $tempdir\n";
	}

$cutoff = time() - $gconfig{'tempdelete_days'}*24*60*60;
opendir(DIR, $tempdir);
foreach my $f (readdir(DIR)) {
	next if ($f eq "." || $f eq "..");
	local @st = lstat("$tempdir/$f");
	if ($st[9] < $cutoff) {
		if ($debug) {
			print "Deleting $tempdir/$f\n";
			}
		&unlink_file("$tempdir/$f");
		}
	}
closedir(DIR);

