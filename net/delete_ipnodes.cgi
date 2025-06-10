#!/usr/local/bin/perl
# Delete several IPv6 host file entries

require './net-lib.pl';
&error_setup($text{'idelete_err'});
$access{'ipnodes'} == 2 || &error($text{'hosts_ecannot'});
&ReadParse();
@d = split(/\0/, $in{'d'});
@d || &error($text{'hdelete_enone'});

# Do the deletions
&lock_file($config{'ipnodes_file'});
@hosts = &list_ipnodes();
foreach $d (sort { $b <=> $a } @d) {
	$host = $hosts[$d];
	&delete_ipnode($host);
	}

&unlock_file($config{'ipnodes_file'});
&webmin_log("delete", "ipnodes", scalar(@d));
&redirect("list_ipnodes.cgi");

