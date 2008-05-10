#!/usr/local/bin/perl
# master_form.cgi
# Form for creating a new master zone

require './dns-lib.pl';
&ReadParse();
&header("Create Master Zone", "");
%access = &get_module_acl();
$access{'master'} || &error("You cannot create master zones");
print &ui_hr();

print "<form action=create_master.cgi>\n";
print "<table border width=100%>\n";
print "<tr> <td $tb><b>New master zone options</b></td> </tr>\n";
print "<tr> <td $cb><table width=100%>\n";

print "<tr> <td><b>Zone type</b></td>\n";
print "<td colspan=3><input type=radio name=rev value=0 checked>\n";
print "Forward (Names to Addresses)\n";
print "&nbsp;&nbsp;<input type=radio name=rev value=1>\n";
print "Reverse (Addresses to Names)</td> </tr>\n";

print "<tr> <td><b>Domain name / Network</b></td>\n";
print "<td colspan=3><input name=zone size=40></td> </tr>\n";

print "<tr> <td><b>Records file</b></td> <td colspan=3>\n";
print "<input type=radio name=file_def value=1 checked> Automatic\n";
print "<input type=radio name=file_def value=0>\n";
print "<input name=file size=30>",&file_chooser_button("file"),"</td> </tr>\n";

print "<tr> <td><b>Master server</b></td>\n";
printf "<td colspan=3><input name=master size=30 value=\"%s\"></td> </tr>\n",
        &get_system_hostname();

print "<tr> <td><b>Owner's email address</b></td>\n";
print "<td colspan=3><input name=email size=40></td> </tr>\n";

&get_zone_defaults(\%zd);
print "<tr> <td><b>Refresh time</b></td>\n";
print "<td><input name=refresh size=8 value=$zd{'refresh'}> seconds</td>\n";

print "<td><b>Transfer retry time</b></td>\n";
print "<td><input name=retry size=8 value=$zd{'retry'}> seconds</td> </tr>\n";

print "<tr> <td><b>Expiry time</b></td>\n";
print "<td><input name=expiry size=8 value=$zd{'expiry'}> seconds</td>\n";

print "<td><b>Default time-to-live</b></td>\n";
print "<td><input name=minimum size=8 value=$zd{'minimum'}> seconds</td> </tr>\n";

print "</table></td></tr></table><br>\n";
print "<input type=submit value=\"Create Zone\"></form>\n";

print &ui_hr();
&footer("", "zone list");

