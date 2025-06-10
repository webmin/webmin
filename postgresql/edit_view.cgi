#!/usr/local/bin/perl
# Show a form for creating or editing a view

require './postgresql-lib.pl';
&ReadParse();
&can_edit_db($in{'db'}) || &error($text{'dbase_ecannot'});
$access{'edonly'} && &error($text{'dbase_ecannot'});
$access{'views'} || &error($text{'view_ecannot'});

if ($in{'view'}) {
	# Editing an index
	$str = &view_structure($in{'db'}, $in{'view'});
	}
$desc = "<tt>$in{'db'}</tt>";
&ui_print_header($desc, $in{'view'} ? $text{'view_title2'}
				     : $text{'view_title1'}, "");

print &ui_form_start("save_view.cgi", "post");
print &ui_hidden("db", $in{'db'}),"\n";
print &ui_hidden("old", $in{'view'}),"\n";
print &ui_table_start($text{'view_header1'}, undef, 2, [ "width=30%" ]);

# View name
print &ui_table_row($text{'view_name'},
		    &ui_textbox("name", $str->{'name'}, 20));

# Column names
if (!$in{'view'}) {
	print &ui_table_row($text{'view_cols'},
		    &ui_radio("cols_set", 0, [ [ 0, $text{'view_auto'} ],
					       [ 1, $text{'view_below'} ] ]).
		    "<br>\n".
		    &ui_textarea("cols", undef, 3, 20));
	}

# Selection query
print &ui_table_row($text{'view_query'},
		    &ui_textarea("query", $str->{'query'}, 5, 60, "on"));

print &ui_table_end();
if ($in{'view'}) {
	print &ui_form_end([ [ "save", $text{'save'} ],
			     [ "delete", $text{'delete'} ] ]);
	}
else {
	print &ui_form_end([ [ "create", $text{'create'} ] ]);
	}

&ui_print_footer("edit_dbase.cgi?db=$in{'db'}", $text{'dbase_return'},
	&get_databases_return_link($in{'db'}), $text{'index_return'});
