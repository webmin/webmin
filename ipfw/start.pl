#!/usr/local/bin/perl
# start.pl
# Apply the current firewall configuration

$no_acl_check++;
require './ipfw-lib.pl';
&ReadParse();
$err = &apply_rules();
if ($err) {
	$err =~ s/<[^>]*>//g;
	print STDERR "Failed to enable firewall : $err\n";
	exit(1);
	}
else {
	exit(0);
	}

