#!/usr/local/bin/perl
# stop.pl
# Turn off the firewall

$no_acl_check++;
require './ipfw-lib.pl';
&ReadParse();
$err = &disable_rules();
if ($err) {
	$err =~ s/<[^>]*>//g;
	print STDERR "Failed to disable firewall : $err\n";
	exit(1);
	}
else {
	exit(0);
	}

