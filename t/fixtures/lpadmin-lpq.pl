#!/usr/bin/perl
# Emit a queue fixture instead of querying the workstation's print service.
use strict;
use warnings;

print "Rank Owner Job Files Total Size\n";
if (defined($ENV{'WEBMIN_TEST_PRINT_TITLE'})) {
	print "1st fixture 12 $ENV{'WEBMIN_TEST_PRINT_TITLE'} 123 bytes\n";
	}
