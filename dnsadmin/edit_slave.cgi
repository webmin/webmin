#!/usr/local/bin/perl
# edit_slave.cgi
# Display options for an existing slave or stub zone

require './dns-lib.pl';
&ReadParse();
$conf = &get_config();
@v = @{$conf->[$in{'index'}]->{'values'}};
%access = &get_module_acl();
&can_edit_zone(\%access, $v[0]) ||
        &error("You are not allowed to edit this zone");
&header("Edit Slave Zone", "");
print "<center><font size=+2>",&arpa_to_ip($v[0]),"</font></center>\n";

print &ui_hr();
print "<form action=save_slave.cgi>\n";
print "<input type=hidden name=index value=\"$in{'index'}\">\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>Slave Zone Options</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";

for($i=1; $i<@v; $i++) {
	if (&check_ipaddress($v[$i])) { push(@mast, $v[$i]); }
	else { $file = $v[$i]; }
	}
print "<tr> <td valign=top><b>Master servers</b></td>\n";
print "<td><textarea name=masters rows=4 cols=30>",
      join("\n", @mast),"</textarea></td> </tr>\n";
print "<tr><td valign=top><b>Records file</b></td> <td valign=top>\n";
printf "<input type=radio name=file_def value=1 %s> None\n",
	$file ? "" : "checked";
printf "<input type=radio name=file_def value=0 %s>\n",
	$file ? "checked" : "";
print "<input name=file size=30 value=\"$file\">",
	&file_chooser_button("file"),"</td> </tr>\n";

print "</table></td></tr> </table>\n";
print "<table width=100%><tr><td align=left>\n";
print "<input type=submit value=Save></td></form>\n";
print "<form action=delete_zone.cgi>\n";
print "<input type=hidden name=index value=\"$in{'index'}\">\n";
print "<td align=right><input type=submit value=Delete></td></form>\n";
print "</tr></table>\n";
print &ui_hr();
&footer("", "zone list");

