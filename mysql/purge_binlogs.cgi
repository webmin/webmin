#!/usr/local/bin/perl
# Delete old binary logs from the server

require './mysql-lib.pl';
$access{'perms'} == 1 || &error($text{'binlogs_ecannot'});
&error_setup($text{'binlogs_purgeerr'});
&ReadParse();

my ($curfile) = &get_binary_log_status();
$curfile || &error($text{'binlogs_epurgeoff'});
if ($in{'mode'} == 0) {
	# Purge logs older than some number of days
	$in{'days'} =~ /^\d+$/ && $in{'days'} > 0 ||
		&error($text{'binlogs_epurgedays'});
	&execute_sql_logged($master_db,
		"purge binary logs before date_sub(now(), interval ".
		$in{'days'}." day)");
	}
else {
	# Purge all logs except the one currently being written
	&execute_sql_logged($master_db,
		"purge binary logs to '".$curfile."'");
	}
&webmin_log("purgebinlogs");
&redirect("edit_binlogs.cgi");
