#!/usr/local/bin/perl
# table_form.cgi
# Display a form for creating a table

require './postgresql-lib.pl';
&ReadParse();
&can_edit_db($in{'db'}) || &error($text{'dbase_ecannot'});
&ui_print_header(undef, $text{'table_title2'}, "", "table_form");

print "<form action=create_table.cgi method=post>\n";
print "<input type=hidden name=db value='$in{'db'}'>\n";
print "<table border>\n";
print "<tr $tb> <td><b>$text{'table_header2'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";

print "<tr> <td><b>$text{'table_name'}</b></td>\n";
print "<td><input name=name size=30></td> </tr>\n";

print "<tr> <td valign=top><b>$text{'table_initial'}</b></td>\n";
print "<td><table border>\n";
print "<tr $tb> <td><b>$text{'field_name'}</b></td> ",
      "<td><b>$text{'field_type'}</b></td> ",
      "<td><b>$text{'field_size'}</b></td> ",
      "<td><b>$text{'table_opts'}</b></td> </tr>\n";
@type_list = &list_types();
for($i=0; $i<(int($in{'fields'}) || 4); $i++) {
	print "<tr $cb>\n";
	print "<td><input name=field_$i size=20></td>\n";
	print "<td><select name=type_$i>\n";
	print "<option selected>\n";
	foreach $t (@type_list) {
		print "<option>$t\n";
		}
	print "</select></td>\n";
	print "<td><input name=size_$i size=10></td> <td>\n";
	print "<input name=arr_$i type=checkbox value=1> $text{'table_arr'}\n";
	print "<input name=null_$i type=checkbox value=1 checked> $text{'field_null'}\n";
	print "<input name=key_$i type=checkbox value=1> $text{'field_key'}\n";
	print "<input name=uniq_$i type=checkbox value=1> $text{'field_uniq'}\n";
	print "</td> </tr>\n";
	}
print "</table></td> </tr>\n";

print "<tr> <td colspan=2 align=right><input type=submit ",
      "value='$text{'create'}'></td> </tr>\n";

print "</table></td></tr></table></form>\n";

&ui_print_footer("edit_dbase.cgi?db=$in{'db'}", $text{'dbase_return'});

