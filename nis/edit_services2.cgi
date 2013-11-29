#!/usr/local/bin/perl
# edit_services2.cgi
# Edit a NIS services table entry

require './nis-lib.pl';
&ReadParse();
&ui_print_header(undef, $text{'services_title'}, "");

($t, $lnums, $service) = &table_edit_setup($in{'table'}, $in{'line'}, '\s+');
print "<form action=save_services2.cgi method=post>\n";
print "<input type=hidden name=table value='$in{'table'}'>\n";
print "<input type=hidden name=line value='$in{'line'}'>\n";

print "<table border>\n";
print "<tr $tb> <td><b>$text{'services_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";

($name, $proto) = split(/\//, $service->[0]);
print "<tr> <td><b>$text{'services_name'}</b></td>\n";
print "<td><input name=name size=15 value='$name'></td>\n";

&foreign_require("inetd", "inetd-lib.pl");
print "<td><b>$text{'services_proto'}</b></td>\n";
print "<td><select name=proto>\n";
foreach $p (&foreign_call("inetd", "list_protocols")) {
	printf "<option value=%s %s>%s</option>\n",
		$p, $proto eq $p || !$proto && $p eq 'tcp' ? 'selected' : '',
		uc($p);
	}
print "</select></td> </tr>\n";

print "<tr> <td><b>$text{'services_port'}</b></td>\n";
print "<td><input name=port size=6 value='$service->[1]'></td> </tr>\n";

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

