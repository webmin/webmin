#!/usr/local/bin/perl
# create_form.cgi
# Display a form for creating a new PAM service

require './pam-lib.pl';
&ui_print_header(undef, $text{'create_title'}, "");

print "<form action=create_pam.cgi>\n";
print "<table border style=\"width: 100%\">\n";
print "<tr $tb> <td><b>$text{'create_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td><b>$text{'create_name'}</b></td>\n";
print "<td><input name=name size=20></td> </tr>\n";

print "<tr> <td><b>$text{'create_desc'}</b></td>\n";
print "<td><input name=desc size=30></td> </tr>\n";

print "<tr> <td valign=top><b>$text{'create_mods'}</b></td> <td>\n";
print "<input type=radio name=mods value=0> $text{'create_0'}<br>\n";
print "<input type=radio name=mods value=1 checked> $text{'create_1'}<br>\n";
print "<input type=radio name=mods value=2> $text{'create_2'}\n";
print "</td> </tr>\n";

print "</table></td></tr></table>\n";
print "<input type=submit value='$text{'create'}'></form>\n";

&ui_print_footer("", $text{'index_return'});
