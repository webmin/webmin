#!/usr/local/bin/perl
# Show a form for creating or editing a view

require './mysql-lib.pl';
&ReadParse();
&can_edit_db($in{'db'}) || &error($text{'dbase_ecannot'});
$access{'edonly'} && &error($text{'dbase_ecannot'});
$access{'views'} || &error($text{'view_ecannot'});

if ($in{'view'}) {
	# Editing a view
	$str = &view_structure($in{'db'}, $in{'view'});
	}
$desc = "<tt>$in{'db'}</tt>";
&ui_print_header($desc, $in{'view'} ? $text{'view_title2'}
				    : $text{'view_title1'}, "");

print &ui_form_start("save_view.cgi", "post");
print &ui_hidden("db", $in{'db'}),"\n";
print &ui_hidden("old", $in{'view'}),"\n";
print &ui_table_start($text{'view_header1'}, undef, 2);

# View name
print &ui_table_row($text{'view_name'},
		    $in{'view'} ? "<tt>$str->{'name'}</tt>" :
		    &ui_textbox("name", $str->{'name'}, 20));

# Selection query
print &ui_table_row($text{'view_query'},
		    &ui_textarea("query", $str->{'query'}, 5, 60, "on"));

# Algorithm
print &ui_table_row($text{'view_algorithm'},
		    &ui_select("algorithm", $str->{'algorithm'},
			       [ [ "undefined", $text{'view_undefined'} ],
				 [ "merge", $text{'view_merge'} ],
				 [ "temptable", $text{'view_temptable'} ] ]));

# Definer
print &ui_table_row($text{'view_definer'},
	$in{'view'} ? &ui_textbox("definer", $str->{'definer'}, 30)
		    : &ui_opt_textbox("definer", undef, 20, $text{'default'}));

# Security level
print &ui_table_row($text{'view_security'},
		    &ui_radio("security", $str->{'security'},
			     [ $in{'view'} ? ( ) : ( [ "", $text{'default'} ] ),
			       [ "definer", $text{'view_sdefiner'} ],
			       [ "invoker", $text{'view_sinvoker'} ] ]));

# Check option
print &ui_table_row($text{'view_check'},
		    &ui_radio("check", $str->{'check'},
			     [ [ "", $text{'view_nocheck'} ],
			       [ "cascaded", $text{'view_cascaded'} ],
			       [ "local", $text{'view_local'} ] ]));


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

