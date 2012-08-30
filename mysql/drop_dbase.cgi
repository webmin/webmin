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
	&execute_sql_logged($master_db, "drop database ".&quotestr($in{'db'}));
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

	print "<center><b>",&text('ddrop_rusure', "<tt>$in{'db'}</tt>",
				  scalar(@tables), $rows),"\n";
	print $text{'ddrop_mysql'},"\n" if ($in{'db'} eq $master_db);
	print "</b><p>\n";
	print "<form action=drop_dbase.cgi>\n";
	print "<input type=hidden name=db value='$in{'db'}'>\n";
	print "<input type=submit name=confirm value='$text{'ddrop_ok'}'>\n";
	print "<input type=submit name=empty value='$text{'ddrop_empty'}'>\n"
		if (@tables);
	print "</form></center>\n";
	&ui_print_footer("edit_dbase.cgi?db=$in{'db'}", $text{'dbase_return'},
			 &get_databases_return_link($in{'db'}), $text{'index_return'});
	}


