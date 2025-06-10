#!/usr/local/bin/perl
# Delete several host file entries

require './net-lib.pl';
&error_setup($text{'hdelete_err'});
$access{'hosts'} == 2 || &error($text{'hosts_ecannot'});
&ReadParse();
@d = split(/\0/, $in{'d'});
@d || &error($text{'hdelete_enone'});

# Do the deletions
&lock_file($config{'hosts_file'});
@hosts = &list_hosts();
foreach $d (sort { $b <=> $a } @d) {
	$host = $hosts[$d];
	&delete_host($host);
	}

&unlock_file($config{'hosts_file'});
&webmin_log("delete", "hosts", scalar(@d));
&redirect("list_hosts.cgi");

