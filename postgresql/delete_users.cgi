#!/usr/local/bin/perl
# Delete multiple PostgreSQL users

require './postgresql-lib.pl';
&ReadParse();
$access{'users'} || &error($text{'user_ecannot'});
&error_setup($text{'user_derr'});
@d = split(/\0/, $in{'d'});
@d || &error($text{'user_enone'});

$main::disable_postgresql_escaping = 1;
foreach $u (@d) {
	&execute_sql_logged($config{'basedb'}, "drop user \"$u\"");
	}
&webmin_log("delete", "users", scalar(@d));
&redirect("list_users.cgi");

