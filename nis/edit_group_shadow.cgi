#!/usr/local/bin/perl
# edit_group_shadow.cgi
# Edit a NIS group table entry

require './nis-lib.pl';
&ReadParse();
&ui_print_header(undef, $text{'group_title'}, "");

($t, $lnums, $group, $shadow) = &table_edit_setup($in{'table'}, $in{'line'}, ':');
print "<form action=save_group_shadow.cgi method=post>\n";
print "<input type=hidden name=table value='$in{'table'}'>\n";
print "<input type=hidden name=line value='$in{'line'}'>\n";

print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'group_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td><b>$text{'group_name'}</b></td>\n";
print "<td><input name=name size=15 value='$group->[0]'></td>\n";

print "<td><b>$text{'group_gid'}</b></td>\n";
print "<td><input name=gid size=10 value='$group->[2]'></td> </tr>\n";

print "<tr> <td valign=top><b>$text{'group_pass'}</b></td> <td>\n";
printf "<input type=radio name=passmode value=0 %s> $text{'group_none'}<br>\n",
	$shadow->[1] eq "" ? "checked" : "";
printf "<input type=radio name=passmode value=1 %s> $text{'group_encrypted'}\n",
	$shadow->[1] eq "" ? "" : "checked";
print "<input name=encpass size=13 value=\"$shadow->[1]\"><br>\n";
print "<input type=radio name=passmode value=2 %s> $text{'group_clear'}\n";
print "<input name=pass size=15></td>\n";

print "<td valign=top><b>$text{'group_members'}</b></td>\n";
print "<td><textarea wrap=auto name=members rows=5 cols=10>",
	join("\n", split(/,/ , $group->[3])),"</textarea></td> </tr>\n";

print "</table></td></tr></table>\n";
if (defined($in{'line'})) {
	print "<input type=submit value='$text{'save'}'>\n";
	print "<input type=submit name=delete value='$text{'delete'}'>\n";
	}
else {
	print "<input type=submit value='$text{'create'}'>\n";
	}
print "</form>\n";
&ui_print_footer("edit_tables.cgi?table=$in{'table'}", $text{'tables_return'},
	"", $text{'index_return'});

