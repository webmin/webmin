#!/usr/local/bin/perl
# Show form for searching a table, using multiple fields

if (-r 'mysql-lib.pl') {
	require './mysql-lib.pl';
	}
else {
	require './postgresql-lib.pl';
	}
&ReadParse();
&can_edit_db($in{'db'}) || &error($text{'dbase_ecannot'});
@str = &table_structure($in{'db'}, $in{'table'});

$desc = &text('table_header', "<tt>$in{'table'}</tt>", "<tt>$in{'db'}</tt>");
&ui_print_header($desc, $text{'adv_title'}, "");

print &ui_form_start("view_table.cgi", "post");
print &ui_hidden("db", $in{'db'});
print &ui_hidden("table", $in{'table'});

print &ui_radio("and", 1, [ [ 0, $text{'adv_or'} ],
			    [ 1, $text{'adv_and'} ] ]),"<p>\n";
print "<table>\n";
for($i=0; $i<10; $i++) {
	print "<tr>\n";
	print "<td>",&ui_select("field_$i", "",
		[ [ "", "&nbsp;" ],
		  map { [ $_->{'field'}, $_->{'field'} ] } @str ]),"</td>\n";
	print "<td>",&ui_select("match_$i", 0,
		[ map { [ $_, $text{'view_match'.$_} ] } (0.. 3) ]),"</td>\n";
	print "<td>",&ui_textbox("for_$i", undef, 30),"</td>\n";
	print "</tr>\n";
	}
print "</table>\n";
print &ui_form_end([ [ "advanced", $text{'adv_ok'} ] ]);

if ($access{'edonly'}) {
	&ui_print_footer("edit_dbase.cgi?db=$in{'db'}",$text{'dbase_return'},
		"", $text{'index_return'});
	}
else {
	&ui_print_footer("edit_table.cgi?db=$in{'db'}&table=$in{'table'}",
		$text{'table_return'},
		"edit_dbase.cgi?db=$in{'db'}", $text{'dbase_return'},
		"", $text{'index_return'});
	}

