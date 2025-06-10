#!/usr/local/bin/perl
# Delete multiple PostgreSQL allowed hosts

require './postgresql-lib.pl';
&ReadParse();
$access{'users'} || &error($text{'host_ecannot'});
&error_setup($text{'host_derr'});
@d = split(/\0/, $in{'d'});
@d || &error($text{'host_enone'});

$v = &get_postgresql_version();
@hosts = &get_hba_config($v);
foreach $i (sort { $b <=> $a } @d) {
	($host) = $hosts[$i];
	&delete_hba($host, $v);
	}
&webmin_log("delete", "hosts", scalar(@d));
&redirect("list_hosts.cgi");

