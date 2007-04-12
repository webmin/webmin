#!/usr/local/bin/perl
# edit_other.cgi
# Edit or create a boot partition

require './lilo-lib.pl';
&foreign_require("fdisk", "fdisk-lib.pl");

&ReadParse();
if ($in{'new'}) {
	&ui_print_header(undef, $text{'other_title1'}, "");
	$members = [ ];
	}
else {
	&ui_print_header(undef, $text{'other_title2'}, "");
	$conf = &get_lilo_conf();
	$other = $conf->[$in{'idx'}];
	$members = $other->{'members'};
	}

print "<form action=save_other.cgi>\n";
print "<input type=hidden name=idx value='$in{'idx'}'>\n";
print "<input type=hidden name=new value='$in{'new'}'>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'other_details'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td><b>$text{'other_name'}</b></td>\n";
printf "<td valign=top><input name=label size=15 value='%s'></td>\n",
	&find_value("label", $members);

print "<td><b>$text{'other_part'}</b></td> <td>\n";
print &foreign_call("fdisk", "partition_select", "other", $other->{'value'}, 0);
print "</td> </tr>\n";

$table = &find_value("table", $members);
print "<tr> <td><b>$text{'other_pass'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=tablemode value=0 %s> $text{'no'}\n",
	$table ? "" : "checked";
printf "<input type=radio name=tablemode value=1 %s> $text{'other_yes'}\n",
	$table ? "checked" : "";
print &foreign_call("fdisk", "partition_select", "table", $table, 1);
print "</td> </tr>\n";

$password = &find_value("password", $members);
print "<tr> <td><b>$text{'other_password'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=passmode value=0 %s> $text{'other_none'}\n",
	$password ? "" : "checked";
printf "<input type=radio name=passmode value=1 %s>\n",
	$password ? "checked" : "";
print "<input name=password size=25 value=\"$password\"></td> </tr>\n";

print "</table></td></tr></table>\n";

print "<table width=100%><tr>\n";
print "<td align=left><input type=submit value=\"$text{'save'}\"></td>\n";
if (!$in{'new'}) {
	print "<td align=right>",
	      "<input type=submit name=delete value=\"$text{'delete'}\"></td>\n";
	}
print "</tr></table></form>\n";

&ui_print_footer("", $text{'index_return'});

