#!/usr/local/bin/perl
# Show a form for creating or editing index on a table

require './postgresql-lib.pl';
&ReadParse();
&can_edit_db($in{'db'}) || &error($text{'dbase_ecannot'});
$access{'edonly'} && &error($text{'dbase_ecannot'});
$access{'indexes'} || &error($text{'index_ecannot'});

if ($in{'index'}) {
	# Editing an index
	$str = &index_structure($in{'db'}, $in{'index'});
	$table = $str->{'table'};
	}
else {
	# Creating an index
	$table = $in{'table'};
	}
$desc = &text('table_header', "<tt>$table</tt>", "<tt>$in{'db'}</tt>");
&ui_print_header($desc, $in{'index'} ? $text{'index_title2'}
				     : $text{'index_title1'}, "");

print &ui_form_start("save_index.cgi", "post");
print &ui_hidden("db", $in{'db'}),"\n";
print &ui_hidden("table", $table),"\n";
print &ui_hidden("old", $in{'index'}),"\n";
print &ui_table_start($text{'index_header1'}, undef, 2);

# Index name
print &ui_table_row($text{'index_name'},
		    &ui_textbox("name", $str->{'name'}, 20));

# Fields in index
@str = &table_structure($in{'db'}, $table);
@cols = map { $_->{'field'} } @str;
print &ui_table_row($text{'index_fields'},
		   &ui_select("cols", $str->{'cols'},
		      [ map { [ $_->{'field'}, "$_->{'field'} - $_->{'type'}" ] } @str ], 5, 1));

# Index type
print &ui_table_row($text{'index_type'},
		    &ui_select("type", $str->{'type'},
			[ [ "unique", $text{'index_unique'} ],
			  [ "", $text{'index_nonunique'} ] ]));

# Access method
print &ui_table_row($text{'index_using'},
		    &ui_select("using", $str->{'using'} || "btree",
			[ [ "btree", $text{'index_btree'} ],
			  [ "rtree", $text{'index_rtree'} ],
			  [ "hash", $text{'index_hash'} ],
			  [ "gist", $text{'index_gist'} ] ],
			undef, undef, 1));

print &ui_table_end();
if ($in{'index'}) {
	print &ui_form_end([ [ "save", $text{'save'} ],
			     [ "delete", $text{'delete'} ] ]);
	}
else {
	print &ui_form_end([ [ "create", $text{'create'} ] ]);
	}

&ui_print_footer("edit_dbase.cgi?db=$in{'db'}", $text{'dbase_return'},
	&get_databases_return_link($in{'db'}), $text{'index_return'});
