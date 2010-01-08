#!/usr/local/bin/perl
# newdb.cgi
# Create a new database with one optional table

require './mysql-lib.pl';
&ReadParse();
$access{'create'} || &error($text{'newdb_ecannot'});
&error_setup($text{'newdb_err'});

# Make sure maximum databases limit has not been exceeded
@alldbs = &list_databases();
@titles = grep { &can_edit_db($_) } @alldbs;
if ($access{'create'} == 2 && @titles >= $access{'max'}) {
	&error($text{'newdb_ecannot2'});
	}

$in{'db'} =~ /^[A-z0-9\.\-\s]+$/ || &error($text{'newdb_edb'});
if (!$in{'table_def'}) {
	@sql = &parse_table_form([ ], $in{'table'});
	}
&execute_sql_logged($master_db, "create database ".&quotestr($in{'db'}).
		    ($in{'charset'} ? " character set $in{'charset'}" : "").
		    ($in{'collation'} ? " collate $in{'collation'}" : ""));
&webmin_log("create", "db", $in{'db'});
if (@sql) {
	foreach $sql (@sql) {
		&execute_sql_logged($in{'db'}, $sql);
		}
	&webmin_log("create", "table", $in{'table'}, \%in);
	}
if ($access{'dbs'} ne '*') {
	$access{'dbs'} .= " " if ($access{'dbs'});
	$access{'dbs'} .= $in{'db'};
	&save_module_acl(\%access);
	}
&redirect("");

