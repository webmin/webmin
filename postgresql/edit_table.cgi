#!/usr/local/bin/perl
# edit_table.cgi
# Display the structure of some table

require './postgresql-lib.pl';
&ReadParse();
&can_edit_db($in{'db'}) || &error($text{'dbase_ecannot'});
$desc = &text('table_header', "<tt>$in{'table'}</tt>", "<tt>$in{'db'}</tt>");
&ui_print_header($desc, $text{'table_title'}, "", "edit_table");

@desc = &table_structure($in{'db'}, $in{'table'});
print "<form action=edit_field.cgi>\n";
print "<input type=hidden name=db value='$in{'db'}'>\n";
print "<input type=hidden name=table value='$in{'table'}'>\n";

$mid = int((@desc / 2)+0.5);
print "<table border=0 width=100%> <tr><td valign=top width=50%>\n";
&type_table(0, $mid);
print "</td><td valign=top width=50%>\n";
&type_table($mid, scalar(@desc)) if (@desc > 1);
print "</td></tr> </table>\n";

print "<table width=100%><tr>\n";
print "<td width=33% nowrap><input type=submit value='$text{'table_add'}'>\n";
print "<select name=type>\n";
foreach $t (&list_types()) {
	print "<option>$t\n";
	}
print "</select></td></form>\n";

print "<form action=view_table.cgi>\n";
print "<input type=hidden name=db value='$in{'db'}'>\n";
print "<input type=hidden name=table value='$in{'table'}'>\n";
print "<td align=middle width=22%>\n";
print "<input type=submit value='$text{'table_data'}'></td>\n";
print "</form>\n";

print "<form action=csv_form.cgi>\n";
print "<input type=hidden name=db value='$in{'db'}'>\n";
print "<input type=hidden name=table value='$in{'table'}'>\n";
print "<td align=middle width=22%>\n";
print "<input type=submit value='$text{'table_csv'}'></td>\n";
print "</form>\n";

if (!&can_drop_fields()) {
	print "<form action=drop_field.cgi>\n";
	print "<input type=hidden name=db value='$in{'db'}'>\n";
	print "<input type=hidden name=table value='$in{'table'}'>\n";
	print "<td align=right width=22%>\n";
	print "<input type=submit name=drop_a_fld value='$text{'table_fielddrop'}'></td>\n";
	print "</form>\n";
	}

# Create index button
if (&supports_indexes() && $access{'indexes'}) {
	print "<form action=edit_index.cgi>\n";
	print "<input type=hidden name=db value='$in{'db'}'>\n";
	print "<input type=hidden name=table value='$in{'table'}'>\n";
	print "<td align=center width=25%>\n";
	print "<input type=submit value='$text{'table_index'}'></td>\n";
	print "</form>\n";
	}

print "<form action=drop_table.cgi>\n";
print "<input type=hidden name=db value='$in{'db'}'>\n";
print "<input type=hidden name=table value='$in{'table'}'>\n";
print "<td align=right width=22%>\n";
print "<input type=submit value='$text{'table_drop'}'></td>\n";
print "</form>\n";

print "</tr></table>\n";

&ui_print_footer("edit_dbase.cgi?db=$in{'db'}", $text{'dbase_return'},
	"", $text{'index_return'});

sub type_table
{
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'table_field'}</b></td> ",
      "<td><b>$text{'table_type'}</b></td> ",
      "<td><b>$text{'table_arr'}</b></td> ",
      "<td><b>$text{'table_null'}</b></td> </tr>\n";
local $i;
for($i=$_[0]; $i<$_[1]; $i++) {
	local $r = $desc[$i];
	print "<tr $cb>\n";
	print "<td><a href='edit_field.cgi?db=$in{'db'}&table=$in{'table'}&",
	      "idx=$i'>",&html_escape($r->{'field'}),"</a></td>\n";
	print "<td>",&html_escape($r->{'type'}),"</td>\n";
	print "<td>",$r->{'arr'} eq 'YES' ? $text{'yes'}
					  : $text{'no'},"</td>\n";
	print "<td>",$r->{'null'} eq 'YES' ? $text{'yes'}
					   : $text{'no'},"</td>\n";
	print "</tr>\n";
	}
print "</table>\n";
}

