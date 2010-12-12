#!/usr/local/bin/perl
# table_form.cgi
# Display a form for creating a table

require './postgresql-lib.pl';
&ReadParse();
&can_edit_db($in{'db'}) || &error($text{'dbase_ecannot'});

# Redirect to other pages depending on button
if ($in{'addview'}) {
	&redirect("edit_view.cgi?new=1&db=".&urlize($in{'db'}));
	return;
	}
elsif ($in{'addseq'}) {
	&redirect("edit_seq.cgi?new=1&db=".&urlize($in{'db'}));
	return;
	}
elsif ($in{'dropdb'}) {
	&redirect("drop_dbase.cgi?db=".&urlize($in{'db'}));
	return;
	}
elsif ($in{'backupdb'}) {
	&redirect("backup_form.cgi?db=".&urlize($in{'db'}));
	return;
	}
elsif ($in{'restoredb'}) {
	&redirect("restore_form.cgi?db=".&urlize($in{'db'}));
	return;
	}
elsif ($in{'exec'}) {
	&redirect("exec_form.cgi?db=".&urlize($in{'db'}));
	return;
	}

$desc = "<tt>$in{'db'}</tt>";
&ui_print_header($desc, $text{'table_title2'}, "", "table_form");

# Start of form block
print &ui_form_start("create_table.cgi", "post");
print &ui_hidden("db", $in{'db'});
print &ui_table_start($text{'table_header2'}, undef, 2);

# Table name
print &ui_table_row($text{'table_name'},
	&ui_textbox("name", undef, 40));

# Initial fields
@type_list = &list_types();
for($i=0; $i<(int($in{'fields'}) || 4); $i++) {
	push(@table, [
		&ui_textbox("field_$i", undef, 30),
		&ui_select("type_$i", undef,
			   [ [ undef, '&nbsp;' ], @type_list ]),
		&ui_textbox("size_$i", undef, 10),
		&ui_checkbox("arr_$i", 1, $text{'table_arr'}, 0)." ".
		&ui_checkbox("null_$i", 1, $text{'field_null'}, 1)." ".
		&ui_checkbox("key_$i", 1, $text{'field_key'}, 0)." ".
		&ui_checkbox("uniq_$i", 1, $text{'field_uniq'}, 0),
		]);
	}
print &ui_table_row($text{'table_initial'},
	&ui_columns_table([ $text{'field_name'}, $text{'field_type'},
			    $text{'field_size'}, $text{'table_opts'} ],
			  undef, \@table));

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'create'} ] ]);

&ui_print_footer("edit_dbase.cgi?db=$in{'db'}", $text{'dbase_return'});

