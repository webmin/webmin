#!/usr/local/bin/perl
# Delete multiple PostgreSQL groups

require './postgresql-lib.pl';
&ReadParse();
$access{'users'} || &error($text{'user_ecannot'});
&error_setup($text{'group_derr'});
@d = split(/\0/, $in{'d'});
@d || &error($text{'group_enone'});

foreach $g (@d) {
	if (&get_postgresql_version() >= 8.0) {
		&execute_sql_logged($config{'basedb'}, "drop group $g");
		}
	else {
		&execute_sql_logged($config{'basedb'}, "delete from pg_group where grosysid = $g");
		}
	}
&webmin_log("delete", "groups", scalar(@d));
&redirect("list_groups.cgi");

