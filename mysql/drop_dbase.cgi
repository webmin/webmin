#!/usr/local/bin/perl
# drop_dbase.cgi
# Drop an existing database

require './mysql-lib.pl';
&ReadParse();
&error_setup($text{'ddrop_err'});
&can_edit_db($in{'db'}) || &error($text{'dbase_ecannot'});
$access{'edonly'} && &error($text{'dbase_ecannot'});
if ($in{'confirm'}) {
	# Drop the database
	$access{'delete'} || &error($text{'dbase_ecannot'});
	&execute_sql_logged($master_db, "drop database ".&quotestr($in{'db'}));
	&delete_database_backup_job($in{'db'});
	&webmin_log("delete", "db", $in{'db'});
	&redirect("");
	}
elsif ($in{'empty'}) {
	# Delete all the tables
	foreach $t (&list_tables($in{'db'})) {
		&execute_sql_logged($in{'db'}, "drop table ".&quotestr($t));
		}
	&webmin_log("delete", "db", $in{'db'});
	&redirect("edit_dbase.cgi?db=$in{'db'}");
	}
else {
	# Ask the user if he is sure..
	&ui_print_header(undef, $text{'ddrop_title'}, "");
	@tables = &list_tables($in{'db'});
	$rows = 0;
	foreach $t (@tables) {
		$d = &execute_sql($in{'db'}, "select count(*) from ".&quotestr($t));
		$rows += $d->{'data'}->[0]->[0];
		}

	if (!$access{'delete'}) {
		# Offer to drop tables only
		$msg = &text('ddrop_rusure2', "<tt>$in{'db'}</tt>", scalar(@tables), $rows);
		$msg .= " ".$text{'ddrop_mysql'} if ($in{'db'} eq $master_db);
		print &ui_confirmation_form(
			"drop_dbase.cgi", $msg,
			[ [ 'db', $in{'db'} ] ],
			[ [ 'empty', $text{'ddrop_empty2'} ] ],
			);
		}
	else {
		# Offer to drop DB or tables
		$msg = &text('ddrop_rusure', "<tt>$in{'db'}</tt>", scalar(@tables), $rows);
		$msg .= " ".$text{'ddrop_mysql'} if ($in{'db'} eq $master_db);
		print &ui_confirmation_form(
			"drop_dbase.cgi", $msg,
			[ [ 'db', $in{'db'} ] ],
			[ [ 'confirm', $text{'ddrop_ok'} ],
			  @tables ? ( [ 'empty', $text{'ddrop_empty'} ] ) : ( ),
			],
			);
		}

	&ui_print_footer("edit_dbase.cgi?db=$in{'db'}", $text{'dbase_return'},
			 &get_databases_return_link($in{'db'}), $text{'index_return'});
	}


