#!/usr/local/bin/perl
# edit_field.cgi
# Display a form for editing an existing field or creating a new one

require './postgresql-lib.pl';
&ReadParse();
&can_edit_db($in{'db'}) || &error($text{'dbase_ecannot'});
$desc = &text('field_in', "<tt>$in{'table'}</tt>", "<tt>$in{'db'}</tt>");
if ($in{'type'}) {
	# Creating a new field
	&ui_print_header($desc, $text{'field_title1'}, "", "create_field");
	$type = $in{'type'};
	}
else {
	# Editing an existing field
	&ui_print_header($desc, $text{'field_title2'}, "", "edit_field");
	@desc = &table_structure($in{'db'}, $in{'table'});
	$f = $desc[$in{'idx'}];
	$type = $f->{'type'};
	}

# Start of form block
print &ui_form_start("save_field.cgi", "post");
print &ui_hidden("db", $in{'db'});
print &ui_hidden("table", $in{'table'});
print &ui_hidden("new", $in{'type'});
print &ui_table_start($text{'field_header'}, undef, 2);

# Field name
print &ui_table_row($text{'field_name'},
	&ui_textbox("field", $f->{'field'}, 40));
print &ui_hidden("old", $f->{'field'}) if (!$in{'type'});

# Field type
if ($type =~ /^(\S+)\((.*)\)/) {
	$type = $1;
	$size = $2;
	}
print &ui_table_row($text{'field_type'}, $type);
print &ui_hidden("type", $type);

if ($type eq 'char' || $type eq 'varchar' || $type eq 'numeric' ||
    $type eq 'bit') {
	if ($in{'type'}) {
		# Type has a size
		print &ui_table_row($text{'field_size'},
			&ui_textbox("size", $size, 15));
		}
	else {
		# Type cannot be edited
		print &ui_table_row($text{'field_size'}, $size);
		}
	}

if ($in{'type'}) {
	# Ask if this is an array
	print &ui_table_row($text{'field_arr'},
		&ui_yesno_radio("arr", 0));
	}
else {
	# Display if array or not
	print &ui_table_row($text{'field_arr'},
		$f->{'arr'} eq 'YES' ? $text{'yes'} : $text{'no'});
	}

if (!$in{'type'}) {
	# Display nulls
	print &ui_table_row($text{'field_null'},
		$f->{'null'} eq 'YES' ? $text{'yes'} : $text{'no'});
	}

print &ui_table_end();
if ($in{'type'}) {
	print &ui_form_end([ [ undef, $text{'create'} ] ]);
	}
else {
	print &ui_form_end([ [ undef, $text{'save'} ],
		&can_drop_fields() && @desc > 1 ?
			( [ 'delete', $text{'delete'} ] ) : ( ) ]);
	}

&ui_print_footer("edit_table.cgi?db=$in{'db'}&table=$in{'table'}",
		  $text{'table_return'},
		 "edit_dbase.cgi?db=$in{'db'}", $text{'dbase_return'},
		 &get_databases_return_link($in{'db'}), $text{'index_return'});

