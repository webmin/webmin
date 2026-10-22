#!/usr/local/bin/perl
# drop_table.cgi
# Delete an existing table

require './mysql-lib.pl';
&ReadParse();
&can_edit_db($in{'db'}) || &error($text{'dbase_ecannot'});
$access{'edonly'} && &error($text{'dbase_ecannot'});
if ($in{'confirm'}) {
	# Drop the table
	&error_setup($text{'tdrop_err'});
	&execute_sql_logged($in{'db'}, "drop table ".&quotestr($in{'table'}));
	&webmin_log("delete", "table", $in{'table'}, \%in);
	&redirect("edit_dbase.cgi?db=".&urlize($in{'db'}));
	}
else {
	# Ask the user if he is sure..
	&ui_print_header(undef, $text{'tdrop_title'}, "");
	@tables = &list_tables($in{'db'});
	$d = &execute_sql($in{'db'},
		"select count(*) from ".&quotestr($in{'table'}));
	$rows = $d->{'data'}->[0]->[0];

	print "<center>\n";
	print "<b>",&text('tdrop_rusure',
			  "<tt>".&html_escape($in{'table'})."</tt>",
			  "<tt>".&html_escape($in{'db'})."</tt>", $rows),"</b><p>\n";
	print &ui_form_start("drop_table.cgi");
	print &ui_hidden("db", $in{'db'});
	print &ui_hidden("table", $in{'table'});
	print &ui_form_end([ [ "confirm", $text{'tdrop_ok'} ] ]);
	print "</center>\n";
	&ui_print_footer(
		"edit_table.cgi?db=".&urlize($in{'db'})."&table=".&urlize($in{'table'}),
		$text{'table_return'},
		"edit_dbase.cgi?db=".&urlize($in{'db'}), $text{'dbase_return'},
		&get_databases_return_link($in{'db'}), $text{'index_return'});
	}

