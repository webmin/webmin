#!/usr/local/bin/perl
# Delete serveral servers at once

require './servers-lib.pl';
&ReadParse();
&error_setup($text{'delete_err'});
@del = split(/\0/, $in{'d'});
@del || &error($text{'delete_enone'});
$access{'edit'} || &error($text{'delete_ecannot'});
foreach $d (@del) {
	&delete_server($d);
	}
&webmin_log("deletes", undef, scalar(@del));
&redirect("");

