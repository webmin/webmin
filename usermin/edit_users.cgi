#!/usr/local/bin/perl
# edit_users.cgi
# Display user access control form

require './usermin-lib.pl';
$access{'users'} || &error($text{'acl_ecannot'});
&ui_print_header(undef, $text{'users_title'}, "");
&get_usermin_miniserv_config(\%miniserv);

print $text{'users_desc'}," ",$text{'users_desc2'},"<p>\n";

print "<form action=change_users.cgi method=post>\n";
print "<table border>\n";
print "<tr $tb> <td><b>$text{'users_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table><tr><td valign=top nowrap>\n";
printf "<input type=radio name=access value=0 %s>\n",
	$miniserv{"allowusers"} || $miniserv{"denyusers"} ? "" : "checked";
print "$text{'users_all'}<br>\n";
printf "<input type=radio name=access value=1 %s>\n",
	$miniserv{"allowusers"} ? "checked" : "";
print "$text{'users_allow'}<br>\n";
printf "<input type=radio name=access value=2 %s>\n",
	$miniserv{"denyusers"} ? "checked" : "";
print "$text{'users_deny'}<br>\n";
print "</td> <td valign=top>\n";
printf "<textarea name=user rows=6 cols=30>%s</textarea></td> </tr>\n",
 $miniserv{"allowusers"} ? join("\n", split(/\s+/, $miniserv{"allowusers"})) :
 $miniserv{"denyusers"} ? join("\n", split(/\s+/, $miniserv{"denyusers"})) : "";

if (&get_usermin_version() > 0.95) {
	print "<tr> <td colspan=2>\n";
	printf "<input type=checkbox name=shells_deny value=1 %s> %s\n",
		$miniserv{'shells_deny'} ? "checked" : "",$text{'users_shells'};
	printf "<input name=shells size=25 value='%s'> %s</td> </tr>\n",
		$miniserv{'shells_deny'} || "/etc/shells",
		&file_chooser_button("shells");
	}

print "</table></td> </tr></table>\n";
print "<input type=submit value=\"$text{'save'}\"></form>\n";

&ui_print_footer("", $text{'index_return'});

