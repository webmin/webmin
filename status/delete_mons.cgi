#!/usr/local/bin/perl
# Delete multiple monitors at once

require './status-lib.pl';
$access{'edit'} || &error($text{'mon_ecannot'});
&ReadParse();
foreach $d (split(/\0/, $in{'d'})) {
	$serv = &get_service($d);
	$serv || &error($text{'delete_egone'});
	push(@dels, $serv);
	}
foreach $serv (@dels) {
	&delete_service($serv);
	}
&webmin_log("deletes", undef, scalar(@dels));
&redirect("");

