#!/usr/local/bin/perl
# edit_table.cgi
# Display the structure of some table

require './postgresql-lib.pl';
&ReadParse();
&can_edit_db($in{'db'}) || &error($text{'dbase_ecannot'});
$desc = &text('table_header', "<tt>$in{'table'}</tt>", "<tt>$in{'db'}</tt>");
&ui_print_header($desc, $text{'table_title'}, "", "edit_table");

# Table of fields
print &ui_form_start("delete_fields.cgi", "post");
print &ui_hidden("db", $in{'db'}),"\n";
print &ui_hidden("table", $in{'table'}),"\n"; 
@desc = &table_structure($in{'db'}, $in{'table'});
$candrop = &can_drop_fields() && @desc > 1;
@tds = $candrop ? ( "width=5" ) : ( );
@rowlinks = ( &select_all_link("d"), &select_invert_link("d") );
print &ui_links_row(\@rowlinks);
print &ui_columns_start([ $candrop ? ( "" ) : ( ),
			  $text{'table_field'},
                          $text{'table_type'},
                          $text{'table_arr'},
                          $text{'table_null'} ], 100, 0, \@tds);
$i = 0;
foreach $r (@desc) {
	@cols = ( "<a href='edit_field.cgi?db=$in{'db'}&table=$in{'table'}&".
		   "idx=$i'>".&html_escape($r->{'field'})."</a>",
		   &html_escape($r->{'type'}),
		   $r->{'arr'} eq 'YES' ? $text{'yes'} : $text{'no'},
		   $r->{'null'} eq 'YES' ? $text{'yes'} : $text{'no'},
		);
	if ($candrop) {
		print &ui_checked_columns_row(\@cols, \@tds, "d",$r->{'field'});
		}
	else {
		print &ui_columns_row(\@cols, \@tds);
		}
	$i++;
	}
print &ui_columns_end();
print &ui_links_row(\@rowlinks);
print &ui_form_end($candrop ? [ [ "delete", $text{'table_delete'} ] ] : [ ]);

$hiddens = &ui_hidden("db", $in{'db'}).&ui_hidden("table", $in{'table'});
print "<table><tr>\n";

# Add a field
print "<td>\n";
print &ui_form_start("edit_field.cgi");
print $hiddens;
print &ui_submit($text{'table_add'});
print &ui_select("type", undef, [ &list_types() ]);
print &ui_form_end();
print "</td>\n";

# View and edit data button
print "<td>\n";
print &ui_form_start("view_table.cgi", "form-data");
print $hiddens;
print &ui_submit($text{'table_data'});
print &ui_form_end();
print "</td>\n";

# CSV export button
print "<td>\n";
print &ui_form_start("csv_form.cgi");
print $hiddens;
print &ui_submit($text{'table_csv'});
print &ui_form_end();
print "</td>\n";

# Create index button
if (&supports_indexes() && $access{'indexes'}) {
	print "<td>\n";
	print &ui_form_start("edit_index.cgi");
	print $hiddens;
	print &ui_submit($text{'table_index'});
	print &ui_form_end();
	print "</td>\n";
	}

# Drop table button
print "<td>\n";
print &ui_form_start("drop_table.cgi");
print $hiddens;
print &ui_submit($text{'table_drop'});
print &ui_form_end();
print "</td>\n";

print "</tr></table>\n";

&ui_print_footer("edit_dbase.cgi?db=$in{'db'}", $text{'dbase_return'},
	&get_databases_return_link($in{'db'}), $text{'index_return'});

