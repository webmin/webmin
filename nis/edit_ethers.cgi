#!/usr/local/bin/perl
# edit_ethers.cgi
# Edit a NIS ethers table entry

require './nis-lib.pl';
&ReadParse();
&ui_print_header(undef, $text{'ethers_title'}, "");

($t, $lnums, $ether) = &table_edit_setup($in{'table'}, $in{'line'}, '\s+');
print "<form action=save_ethers.cgi method=post>\n";
print "<input type=hidden name=table value='$in{'table'}'>\n";
print "<input type=hidden name=line value='$in{'line'}'>\n";

print "<table border>\n";
print "<tr $tb> <td><b>$text{'ethers_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";

print "<tr> <td><b>$text{'ethers_mac'}</b></td>\n";
print "<td><input name=mac size=17 value='$ether->[0]'></td> </tr>\n";

print "<tr> <td><b>$text{'ethers_ip'}</b></td>\n";
print "<td><input name=ip size=17 value='$ether->[1]'></td> </tr>\n";

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

