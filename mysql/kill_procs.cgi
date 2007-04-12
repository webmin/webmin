#!/usr/local/bin/perl
# Terminate several mysql connections

require './mysql-lib.pl';
&error_setup($text{'kill_err'});
$access{'perms'} == 1 || &error($text{'kill_ecannot'});

&ReadParse();
@d = split(/\0/, $in{'d'});
@d || &error($text{'kill_enone'});

foreach $d (@d) {
	&execute_sql_logged($master_db, "kill $d");
	}
&webmin_log("kill", undef, scalar(@d));
&redirect("list_procs.cgi");

