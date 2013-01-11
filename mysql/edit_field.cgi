#!/usr/local/bin/perl
# edit_field.cgi
# Display a form for editing an existing field or creating a new one

require './mysql-lib.pl';
&ReadParse();
&can_edit_db($in{'db'}) || &error($text{'dbase_ecannot'});
$access{'edonly'} && &error($text{'dbase_ecannot'});
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

# Start of form
print &ui_form_start("save_field.cgi");
print &ui_hidden("db", $in{'db'});
print &ui_hidden("table", $in{'table'});
print &ui_hidden("new", $in{'type'});
print &ui_table_start($text{'field_header'}, undef, 2);

# Field name
print &ui_table_row($text{'field_name'},
	&ui_textbox("field", $f->{'field'}, 20));
print &ui_hidden("old", $f->{'field'}) if (!$in{'type'});

# Type
if ($type =~ /^(\S+)\((.*)\)(.*)/) {
	$type = $1;
	$size = $2;
	$extra = $3;
	}
print &ui_hidden("type", $type);
if ($in{'type'}) {
	# New field .. just show chosen type
	$tsel = $type;
	}
else {
	# Existing field .. allow type change
	$tsel = &ui_select("newtype", $type, \@type_list)." ".
		$text{'field_typewarn'};
	}
print &ui_table_row($text{'field_type'}, $tsel);

if ($type eq 'enum' || $type eq 'set') {
	# List of values
	local @ev = &split_enum($size);
	print &ui_table_row($text{'field_enum'},
		&ui_textarea("size", join("\n", @ev), 4, 20));
	}
elsif ($type eq 'float' || $type eq 'double' || $type eq 'decimal') {
	# Two values, for total and decimal
	print &ui_table_row($text{'field_dual'},
		&ui_textbox("size1", $size =~ /^(\d+)/ ? $1 : '', 5)."\n".
		&ui_textbox("size2", $size =~ /(\d+)$/ ? $1 : '', 5));
	}
elsif ($type eq 'date' || $type eq 'datetime' || $type eq 'time' ||
       $type eq 'timestamp' || $type =~ /(blob|text)$/) {
	# No width!
	}
elsif ($type ne 'varchar' && $type ne 'char' && $in{'type'}) {
	# Size is optional for new fields of most types
	print &ui_table_row($text{'field_size'},
		&ui_opt_textbox("size", undef, 10, $text{'default'}));
	}
else {
	# Size is one value
	print &ui_table_row($text{'field_size'},
		&ui_textbox("size", $size, 10));
	}

if ($type =~ /int$/) {
	# Display unsigned/zerofill option
	$opts = $extra =~ /unsigned/ ? 'unsigned' :
		$extra =~ /zerofill/ ? 'zerofill' : '';
	print &ui_hidden("oldopts", $opts);
	print &ui_table_row($text{'field_opts'},
		&ui_radio("opts", $opts,
			  [ [ '', $text{'field_none'} ],
			    [ 'unsigned', $text{'field_unsigned'} ],
			    [ 'zerofill', $text{'field_zerofill'} ] ]));

	# Display auto-increment option
	print &ui_table_row($text{'field_auto'},
		&ui_radio("ext", $f->{'extra'} =~ /auto_increment/ ?
					'auto_increment' : '',
			  [ [ 'auto_increment', $text{'yes'} ],
			    [ '', $text{'no'} ] ]));
	}
elsif ($type eq 'float' || $type eq 'double' || $type eq 'decimal') {
	# Display zerofill option
	$opts = $extra =~ /zerofill/ ? 'zerofill' : '';
	print &ui_hidden("oldopts", $opts);
	print &ui_table_row($text{'field_opts'},
		&ui_radio("opts", $opts,
			  [ [ '', $text{'field_none'} ],
			    [ 'zerofill', $text{'field_zerofill'} ] ]));
	}
elsif ($type eq 'char' || $type eq 'varchar') {
	# Display binary option
	$opts = $extra =~ /binary/ ? 'binary' : '';
	print &ui_hidden("oldopts", $opts);
	print &ui_table_row($text{'field_opts'},
		&ui_radio("opts", $opts,
			  [ [ '', $text{'field_ascii'} ],
			    [ 'binary', $text{'field_binary'} ] ]));
	}

# Allow nulls?
print &ui_table_row($text{'field_null'},
	&ui_radio("null", $in{'type'} || $f->{'null'} eq 'YES' ? 1 : 0,
		  [ [ 1, $text{'yes'} ], [ 0, $text{'no'} ] ]));

# Default value
$defmode = $f->{'default'} eq 'NULL' || !defined($f->{'default'}) ? 0 :
	   $f->{'default'} eq 'CURRENT_TIMESTAMP' ? 2 :
	   $f->{'default'} eq '' ? 3 : 1;
@defs = ( [ 0, 'NULL' ] );
if ($in{'type'}) {
	# Let MySQL decide
	push(@defs, [ 3, $text{'field_defdef'} ]);
	}
elsif ($type eq 'char' || $type eq 'varchar') {
	# Empty string
	push(@defs, [ 3, $text{'field_defempty'} ]);
	}
if ($type eq "timestamp") {
	push(@defs, [ 2, $text{'field_current'} ]);
	}
push(@defs, [ 1, $text{'field_defval'}." ".
	 &ui_textbox("default", $defmode == 1 ? $f->{'default'} : "", 40) ]);
print &ui_table_row($text{'field_default'},
	&ui_radio("default_def", $defmode, \@defs));

# Part of primary key
print &ui_table_row($text{'field_key'},
	&ui_yesno_radio("key", $f->{'key'} eq 'PRI' ? 1 : 0));
print &ui_hidden("oldkey", $f->{'key'} eq 'PRI' ? 1 : 0);

print &ui_table_end();
if ($in{'type'}) {
	print &ui_form_end([ [ undef, $text{'create'} ] ]);
	}
else {
	print &ui_form_end([ [ undef, $text{'save'} ],
		    @desc > 1 ? ( [ 'delete', $text{'delete'} ] ): ( ) ]);
	}

&ui_print_footer("edit_table.cgi?db=$in{'db'}&table=".&urlize($in{'table'}),
		 $text{'table_return'},
		 "edit_dbase.cgi?db=$in{'db'}", $text{'dbase_return'},
		 &get_databases_return_link($in{'db'}), $text{'index_return'});

