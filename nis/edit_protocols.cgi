#!/usr/local/bin/perl
# edit_protocols.cgi
# Edit a NIS protocols table entry

require './nis-lib.pl';
&ReadParse();
&ui_print_header(undef, $text{'protocols_title'}, "");

($t, $lnums, $protocol) = &table_edit_setup($in{'table'}, $in{'line'}, '\s+');
print "<form action=save_protocols.cgi method=post>\n";
print "<input type=hidden name=table value='$in{'table'}'>\n";
print "<input type=hidden name=line value='$in{'line'}'>\n";

print "<table border>\n";
print "<tr $tb> <td><b>$text{'protocols_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";

print "<tr> <td><b>$text{'protocols_name'}</b></td>\n";
print "<td><input name=name size=15 value='$protocol->[0]'></td>\n";

print "<td><b>$text{'protocols_number'}</b></td>\n";
print "<td><input name=number size=6 value='$protocol->[1]'></td> </tr>\n";

$al = join(" ", @$protocol[2 .. @$protocol-1]);
print "<tr> <td><b>$text{'protocols_aliases'}</b></td>\n";
print "<td colspan=3><input name=aliases size=30 value='$al'></td> </tr>\n";

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

