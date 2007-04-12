#!/usr/local/bin/perl
# sync_form.cgi
# Display a form for creating some or all missing users and groups on
# some or all servers

require './cluster-useradmin-lib.pl';
&ui_print_header(undef, $text{'sync_title'}, "");

print "$text{'sync_desc'}<p>\n";
print "<form action=sync.cgi>\n";
print "<table>\n";

print "<tr> <td valign=top><b>$text{'sync_hosts'}</b></td> <td>\n";
&create_on_input(undef, 1, 1);
print "</td> </tr>\n";

print "<tr> <td valign=top><b>$text{'sync_users'}</b></td> <td>\n";
print "<input type=radio name=users_mode value=1> ",
      "$text{'sync_uall'}&nbsp;&nbsp;\n";
print "<input type=radio name=users_mode value=0 checked> ",
      "$text{'sync_unone'}<br>\n";
print "<input type=radio name=users_mode value=2> ",
      "$text{'sync_usel'}\n";
print "<input name=usel size=30> ",&user_chooser_button("usel", 1),"<br>\n";
print "<input type=radio name=users_mode value=3> ",
      "$text{'sync_unot'}\n";
print "<input name=unot size=30> ",&user_chooser_button("unot", 1),"<br>\n";
print "<input type=radio name=users_mode value=4> ",
      "$text{'sync_uuid'}\n";
print "<input name=uuid1 size=6> - <input name=uuid2 size=6><br>\n";
print "<input type=radio name=users_mode value=5> ",
      "$text{'sync_ugid'}\n";
print &unix_group_input("ugid"),"<br>\n";
print "</td> </tr>\n";

print "<tr> <td valign=top><b>$text{'sync_groups'}</b></td> <td>\n";
print "<input type=radio name=groups_mode value=1> ",
      "$text{'sync_gall'}&nbsp;&nbsp;\n";
print "<input type=radio name=groups_mode value=0 checked> ",
      "$text{'sync_gnone'}<br>\n";
print "<input type=radio name=groups_mode value=2> ",
      "$text{'sync_gsel'}\n";
print "<input name=gsel size=30> ",&group_chooser_button("gsel", 1),"<br>\n";
print "<input type=radio name=groups_mode value=3> ",
      "$text{'sync_gnot'}\n";
print "<input name=gnot size=30> ",&group_chooser_button("gnot", 1),"<br>\n";
print "<input type=radio name=groups_mode value=4> ",
      "$text{'sync_ggid'}\n";
print "<input name=ggid1 size=6> - <input name=ggid2 size=6><br>\n";
print "</td> </tr>\n";

print "<tr> <td><b>$text{'sync_test'}</b></td>\n";
print "<td><input type=radio name=test value=1> $text{'yes'}\n";
print "<input type=radio name=test value=0 checked> $text{'no'}</td> </tr>\n";

print "<tr> <td><b>$text{'sync_makehome'}</b></td>\n";
print "<td><input type=radio name=makehome value=1 checked> $text{'yes'}\n";
print "<input type=radio name=makehome value=0> $text{'no'}</td>\n";
print "</tr>\n";

print "<tr> <td><b>$text{'sync_copy'}</b></td>\n";
print "<td><input type=radio name=copy_files value=1 checked> $text{'yes'}\n";
print "<input type=radio name=copy_files value=0> $text{'no'}</td>\n";
print "</tr>\n";

print "<tr> <td><b>$text{'sync_others'}</b></td>\n";
print "<td><input type=radio name=others value=1 checked> $text{'yes'}\n";
print "<input type=radio name=others value=0> $text{'no'}</td> </tr>\n";

print "</table>\n";
print "<input type=submit value='$text{'sync_ok'}'></form>\n";

&ui_print_footer("", $text{'index_return'});

