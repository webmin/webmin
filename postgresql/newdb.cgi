#!/usr/local/bin/perl
# newdb.cgi
# Create a new database with one optional table

require './postgresql-lib.pl';
&ReadParse();
$access{'create'} || &error($text{'newdb_ecannot'});
&error_setup($text{'newdb_err'});

# Make sure maximum databases limit has not been exceeded
@alldbs = &list_databases();
@titles = grep { &can_edit_db($_) } @alldbs;
if ($access{'create'} == 2 && @titles >= $access{'max'}) {
	&error($text{'newdb_ecannot2'});
	}

$in{'db'} =~ /^[A-z0-9\.\-]+$/ || &error($text{'newdb_edb'});
$cmd = "create database $in{'db'}";
if (!$in{'path_def'}) {
	$in{'path'} =~ /\S/ || &error($text{'newdb_epath'});
	$cmd .= " with location = '$in{'path'}'";
	}
if (!$in{'user_def'}) {
	$cmd .= " with owner=\"$in{'user'}\"";
	}
if (!$in{'encoding_def'} && &get_postgresql_version() >= 8) {
	$in{'encoding'} =~ /\S/ || &error($text{'newdb_eencoding'});
	$cmd .= " encoding = '$in{'encoding'}'";
	}
if ($in{'template'}) {
	$cmd .= " template = $in{'template'}";
	}
&execute_sql_logged($config{'basedb'}, $cmd);
&webmin_log("create", "db", $in{'db'});
if ($access{'dbs'} ne '*') {
	$access{'dbs'} .= " " if ($access{'dbs'});
	$access{'dbs'} .= $in{'db'};
	&save_module_acl(\%access);
	}
&redirect("");

