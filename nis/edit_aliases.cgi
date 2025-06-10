#!/usr/local/bin/perl
# edit_aliases.cgi
# Edit a NIS aliases table entry

require './nis-lib.pl';
&ReadParse();
&ui_print_header(undef, $text{'aliases_title'}, "");

($t, $lnums, $alias) = &table_edit_setup($in{'table'}, $in{'line'}, '[\s:]+');
print "<form action=save_aliases.cgi method=post>\n";
print "<input type=hidden name=table value='$in{'table'}'>\n";
print "<input type=hidden name=line value='$in{'line'}'>\n";

print "<table border>\n";
print "<tr $tb> <td><b>$text{'aliases_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";

print "<tr> <td><b>$text{'aliases_from'}</b></td>\n";
print "<td><input name=from size=20 value='$alias->[0]'></td> </tr>\n";

print "<tr> <td valign=top><b>$text{'aliases_to'}</b></td>\n";
print "<td><textarea name=to rows=3 cols=30>",
	join("\n", split(/,/, $alias->[1])),"</textarea></td> </tr>\n";

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

