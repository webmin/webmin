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

print "<form action=save_field.cgi>\n";
print "<input type=hidden name=db value='$in{'db'}'>\n";
print "<input type=hidden name=table value='$in{'table'}'>\n";
print "<input type=hidden name=new value='$in{'type'}'>\n";
print "<table border>\n";
print "<tr $tb> <td><b>$text{'field_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";

print "<tr> <td><b>$text{'field_name'}</b></td>\n";
print "<td><input name=field size=20 value='$f->{'field'}'></td> </tr>\n";
print "<input type=hidden name=old value='$f->{'field'}'>\n" if (!$in{'type'});

if ($type =~ /^(\S+)\((.*)\)/) {
	$type = $1;
	$size = $2;
	}
print "<input type=hidden name=type value='$type'>\n";
print "<tr> <td><b>$text{'field_type'}</b></td>\n";
print "<td>$type</td> </tr>\n";

if ($type eq 'char' || $type eq 'varchar' || $type eq 'numeric' ||
    $type eq 'bit') {
	if ($in{'type'}) {
		# Type has a size
		print "<tr> <td><b>$text{'field_size'}</b></td>\n";
		print "<td><input name=size size=10 value='$size'></td></tr>\n";
		}
	else {
		# Type cannot be edited
		print "<tr> <td><b>$text{'field_size'}</b></td>\n";
		print "<td>$size</td> </tr>\n";
		}
	}

print "<tr> <td><b>$text{'field_arr'}</b></td> <td>\n";
if ($in{'type'}) {
	# Ask if this is an array
	print "<input name=arr type=radio value=1> $text{'yes'}\n";
	print "<input name=arr type=radio value=0 checked> $text{'no'}\n";
	}
else {
	# Display if array or not
	print $f->{'arr'} eq 'YES' ? $text{'yes'} : $text{'no'};
	}
print "</td> </tr>\n";

if (!$in{'type'}) {
	# Display nulls
	print "<tr> <td><b>$text{'field_null'}</b></td>\n";
	print "<td>",$f->{'null'} eq 'YES' ? $text{'yes'}
					   : $text{'no'},"</td> </tr>\n";
	}

print "</table></td></tr></table>\n";
if ($in{'type'}) {
	print "<input type=submit value='$text{'create'}'>\n";
	}
else {
	print "<input type=submit value='$text{'save'}'>\n";
	if (&can_drop_fields() && @desc > 1) {
		print "<input type=submit name=delete value='$text{'delete'}'>\n";
		}
	}
print "</form>\n";

&ui_print_footer("edit_table.cgi?db=$in{'db'}&table=$in{'table'}",$text{'table_return'},
	"edit_dbase.cgi?db=$in{'db'}", $text{'dbase_return'},
	"", $text{'index_return'});

