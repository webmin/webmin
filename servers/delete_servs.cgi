#!/usr/local/bin/perl
# Delete serveral servers at once

use strict;
use warnings;
require './servers-lib.pl';
our (%text, %access, %in);
&ReadParse();
&error_setup($text{'delete_err'});
my @del = split(/\0/, $in{'d'});
@del || &error($text{'delete_enone'});
$access{'edit'} || &error($text{'delete_ecannot'});
foreach my $d (@del) {
	&delete_server($d);
	}
&webmin_log("deletes", undef, scalar(@del));
&redirect("");

