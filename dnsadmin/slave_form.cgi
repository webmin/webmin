#!/usr/local/bin/perl
# slave_form.cgi
# A form for creating a new slave zone

require './dns-lib.pl';
%access = &get_module_acl();
$access{'slave'} || &error("You are not allowed to create slave zones");
&header("Create Slave Zone", "");
print &ui_hr();

print "<form action=create_slave.cgi>\n";
print "<input type=hidden name=type value=\"$lctype\">\n";
print "<table border width=100%>\n";
print "<tr> <td $tb><b>New slave zone options</b></td> </tr>\n";
print "<tr> <td $cb><table width=100%>\n";

print "<tr> <td><b>Zone type</b></td>\n";
print "<td colspan=3><input type=radio name=rev value=0 checked>\n";
print "Forward (Names to Addresses)\n";
print "&nbsp;&nbsp;<input type=radio name=rev value=1>\n";
print "Reverse (Addresses to Names)</td> </tr>\n";

print "<tr> <td><b>Domain name / Network</b></td>\n";
print "<td colspan=3><input name=zone size=40></td> </tr>\n";

print "<tr> <td><b>Records file</b></td> <td colspan=3>\n";
print "<input type=radio name=file_def value=1> None\n";
print "<input type=radio name=file_def value=2 checked> Automatic\n";
print "<input type=radio name=file_def value=0>\n";
print "<input name=file size=30>",&file_chooser_button("file"),"</td> </tr>\n";

print "<tr> <td valign=top><b>Master servers</b></td> <td colspan=3>\n";
print "<textarea name=masters rows=4 cols=30></textarea></td> </tr>\n";

print "</table></td></tr></table><br>\n";
print "<input type=submit value=\"Create Zone\"></form>\n";

print &ui_hr();
&footer("", "zone list");

