#!/usr/local/bin/perl
# edit_table.cgi
# Display the structure of some table

require './mysql-lib.pl';
&ReadParse();
&can_edit_db($in{'db'}) || &error($text{'dbase_ecannot'});
if ($access{'edonly'}) {
	&redirect("view_table.cgi?db=$in{'db'}&table=".&urlize($in{'table'}));
	exit;
	}
$desc = &text('table_header', "<tt>$in{'table'}</tt>", "<tt>$in{'db'}</tt>");
&ui_print_header($desc, $text{'table_title'}, "", "edit_table");

print &ui_form_start("delete_fields.cgi", "post");
print &ui_hidden("db", $in{'db'}),"\n";
print &ui_hidden("table", $in{'table'}),"\n";
@desc = &table_structure($in{'db'}, $in{'table'});
@tds = ( "width=5" );
@rowlinks = ( &select_all_link("d"),
	      &select_invert_link("d") );
print &ui_links_row(\@rowlinks);
print &ui_columns_start([ "",
			  $text{'table_field'},
			  $text{'table_type'},
			  $text{'table_null'},
			  $text{'table_key'},
		 	  $text{'table_default'},
			  $text{'table_extra'} ], 100, 0, \@tds);
$i = 0;
foreach $r (@desc) {
	local @cols;
	push(@cols, "<a href='edit_field.cgi?db=$in{'db'}&table=".
		    &urlize($in{'table'})."&".
		    "idx=$i'>".&html_escape($r->{'field'})."</a>");
	push(@cols, &html_escape($r->{'type'}));
	push(@cols, $r->{'null'} eq 'YES' ? $text{'yes'} : $text{'no'});
	push(@cols,
		$r->{'key'} eq 'PRI' ? $text{'table_pri'} :
		$r->{'key'} eq 'MUL' ? $text{'table_mul'} :
				       $text{'table_none'});
	push(@cols, &html_escape($r->{'default'}));
	push(@cols, &html_escape($r->{'extra'}));
	print &ui_checked_columns_row(\@cols, \@tds, "d", $r->{'field'});
	$i++;
	}
print &ui_columns_end();
print &ui_links_row(\@rowlinks);
print &ui_form_end([ [ "delete", $text{'table_delete'} ] ]);

print "<form action=edit_field.cgi>\n";
print &ui_hidden("db", $in{'db'}),"\n";
print &ui_hidden("table", $in{'table'}),"\n";
print "<table width=100%><tr>\n";

# Add field button
print "<td width=25% nowrap><input type=submit value='$text{'table_add'}'>\n";
print "<select name=type>\n";
foreach $t (@type_list) {
	print "<option>$t\n";
	}
print "</select></td></form>\n";

# View and edit data button
print "<form action=view_table.cgi method=post enctype=multipart/form-data>\n";
print "<input type=hidden name=db value='$in{'db'}'>\n";
print "<input type=hidden name=table value='$in{'table'}'>\n";
print "<td align=center width=25%>\n";
print "<input type=submit value='$text{'table_data'}'></td>\n";
print "</form>\n";

# CSV export button
print "<form action=csv_form.cgi>\n";
print "<input type=hidden name=db value='$in{'db'}'>\n";
print "<input type=hidden name=table value='$in{'table'}'>\n";
print "<td align=center width=25%>\n";
print "<input type=submit value='$text{'table_csv'}'></td>\n";
print "</form>\n";

if ($access{'indexes'}) {
	# Create index button
	print "<form action=edit_index.cgi>\n";
	print "<input type=hidden name=db value='$in{'db'}'>\n";
	print "<input type=hidden name=table value='$in{'table'}'>\n";
	print "<td align=center width=25%>\n";
	print "<input type=submit value='$text{'table_index'}'></td>\n";
	print "</form>\n";
	}

# Drop table button
print "<form action=drop_table.cgi>\n";
print "<input type=hidden name=db value='$in{'db'}'>\n";
print "<input type=hidden name=table value='$in{'table'}'>\n";
print "<td align=right width=25%>\n";
print "<input type=submit value='$text{'table_drop'}'></td>\n";
print "</form>\n";

print "</tr></table>\n";

&ui_print_footer("edit_dbase.cgi?db=$in{'db'}", $text{'dbase_return'},
	"", $text{'index_return'});

