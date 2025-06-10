#!/usr/local/bin/perl
# sync_form.cgi
# Display a form for creating some or all missing users and groups on
# some or all servers

require './cluster-webmin-lib.pl';
&ui_print_header(undef, $text{'sync_title'}, "");

print "$text{'sync_desc'}<p>\n";
print "<form action=sync.cgi>\n";
print "<table width='100%'>\n";

print "<tr> <td valign=top><b>$text{'sync_hosts'}</b></td> <td>\n";
&create_on_input(undef, 1, 1, 1);
print "</td> </tr>\n";

print "<tr> <td valign=top><b>$text{'sync_users'}</b></td> <td>\n";
print "<input type=radio name=users_mode value=1> ",
      "$text{'sync_uall'}&nbsp;&nbsp;\n";
print "<input type=radio name=users_mode value=0 checked> ",
      "$text{'sync_unone'}<br>\n";
print "<input type=radio name=users_mode value=2> ",
      "$text{'sync_usel'}\n";
print "<input name=usel size=30><br>\n";
print "<input type=radio name=users_mode value=3> ",
      "$text{'sync_unot'}\n";
print "<input name=unot size=30><br>\n";
print "</td> </tr>\n";

print "<tr> <td valign=top><b>$text{'sync_groups'}</b></td> <td>\n";
print "<input type=radio name=groups_mode value=1> ",
      "$text{'sync_gall'}&nbsp;&nbsp;\n";
print "<input type=radio name=groups_mode value=0 checked> ",
      "$text{'sync_gnone'}<br>\n";
print "<input type=radio name=groups_mode value=2> ",
      "$text{'sync_gsel'}\n";
print "<input name=gsel size=30><br>\n";
print "<input type=radio name=groups_mode value=3> ",
      "$text{'sync_gnot'}\n";
print "<input name=gnot size=30><br>\n";
print "</td> </tr>\n";

print "<tr> <td><b>$text{'sync_test'}</b></td>\n";
print "<td><input type=radio name=test value=1> $text{'yes'}\n";
print "<input type=radio name=test value=0 checked> $text{'no'}</td> </tr>\n";

print "</table><p></p><p></p>\n";
print "<input type=submit value='$text{'sync_ok'}'></form>\n";

&ui_print_footer("", $text{'index_return'});

