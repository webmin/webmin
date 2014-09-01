#!/usr/local/bin/perl
# Drops multiple databases

require './mysql-lib.pl';
&ReadParse();
&error_setup($text{'ddrops_err'});
@dbs = split(/\0/, $in{'d'});
@dbs || &error($text{'ddrops_enone'});
$access{'delete'} || &error($text{'ddrops_ecannot'});
foreach $db (@dbs) {
	&can_edit_db($db) || &error(&text('ddrops_ecannotdb', $db));
	}
$access{'edonly'} && &error($text{'dbase_ecannot'});

if ($in{'confirm'}) {
	# Drop the databases
	foreach $db (@dbs) {
		&execute_sql_logged($master_db,"drop database ".&quotestr($db));
		&delete_database_backup_job($db);
		}
	&webmin_log("delete", "dbs", scalar(@dbs), \%in);
	&redirect("");
	}
else {
	# Ask the user if he is sure..
	&ui_print_header(undef, $text{'ddrops_title'}, "");

	$rows = 0;
	$tables = 0;
	foreach $db (@dbs) {
		@tables = &list_tables($db);
		foreach $t (@tables) {
			$d = &execute_sql($db,
				"select count(*) from ".&quotestr($t));
			$rows += $d->{'data'}->[0]->[0];
			$tables++;
			}
		}

	print "<center><b>",&text($tables ? 'ddrops_rusure' : 'ddrops_rusure2',
				  scalar(@dbs), $tables, $rows),"\n";
	if (&indexof($master_db, @dbs) >= 0) {
		print $text{'ddrop_mysql'},"\n";
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


