#!/usr/local/bin/perl
# Generate the report from a cron job

$no_acl_check++;
require './sarg-lib.pl';

$temp = &tempname();
($from, $to) = split(/\s+/, $config{'range'});
open(TEMP, ">$temp");
$rv = &generate_report(TEMP, 0, $config{'clear'}, $from, $to);
close(TEMP);
$out = `cat $temp`;
unlink($temp);

if (!$rv) {
	print STDERR "Failed to generate Sarg report:\n";
	print STDERR $out;
	exit(1);
	}
else {
	exit(0);
	}

