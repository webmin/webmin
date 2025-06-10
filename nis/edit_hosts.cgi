#!/usr/local/bin/perl
# edit_hosts.cgi
# Edit a NIS hosts table entry

require './nis-lib.pl';
&ReadParse();
&ui_print_header(undef, $text{'hosts_title'}, "");

($t, $lnums, $host) = &table_edit_setup($in{'table'}, $in{'line'}, '\s+');
print "<form action=save_hosts.cgi method=post>\n";
print "<input type=hidden name=table value='$in{'table'}'>\n";
print "<input type=hidden name=line value='$in{'line'}'>\n";

print "<table border>\n";
print "<tr $tb> <td><b>$text{'hosts_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";

print "<tr> <td><b>$text{'hosts_ip'}</b></td>\n";
print "<td><input name=ip size=15 value='$host->[0]'></td> </tr>\n";

print "<tr> <td><b>$text{'hosts_name'}</b></td>\n";
print "<td><input name=name size=30 value='$host->[1]'></td> </tr>\n";

print "<tr> <td valign=top><b>$text{'hosts_aliases'}</b></td>\n";
print "<td><textarea name=aliases rows=3 cols=30>",
	join("\n", @$host[2 .. @$host-1]),"</textarea></td> </tr>\n";

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

