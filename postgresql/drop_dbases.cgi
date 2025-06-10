#!/usr/local/bin/perl
# Drop all selected databases

require './postgresql-lib.pl';
&ReadParse();
&error_setup($text{'ddrops_err'});
@dbs = split(/\0/, $in{'d'});
foreach $db (@dbs) {
	&can_edit_db($db) || &error(&text('ddrops_ecannot', $db));
	}
if ($in{'confirm'}) {
	# Drop the databases
	foreach $db (@dbs) {
		&execute_sql_logged($config{'basedb'}, "drop database \"$db\"");
		&delete_database_backup_job($db);
		}
	&webmin_log("delete", "dbs", scalar(@dbs));
	&redirect("");
	}
else {
	# Ask the user if he is sure..
	&ui_print_header(undef, $text{'ddrop_title'}, "");
	$rows = 0;
	$tables = 0;
	foreach $db (@dbs) {
		next if (!&accepting_connections($db));
		@tables = &list_tables($db);
		foreach $t (@tables) {
			$d = &execute_sql($db, "select count(*) from $t");
			$rows += $d->{'data'}->[0]->[0];
			$tables++;
			}
		}

	print "<center><b>",&text('ddrops_rusure', scalar(@dbs),
				  $tables, $rows),"\n";
	if (&indexof($config{'basedb'}, @dbs) >= 0) {
		print $text{'ddrops_mysql'},"\n";
		}
	print "</b><p>\n";
	print "<form action=drop_dbases.cgi>\n";
	foreach $db (@dbs) {
		print &ui_hidden("d", $db),"\n";
		}
	print "<input type=submit name=confirm value='$text{'ddrops_ok'}'>\n";
	print "</form></center>\n";
	&ui_print_footer("", $text{'index_return'});
	}


