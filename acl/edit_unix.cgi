#!/usr/local/bin/perl
# edit_unix.cgi
# Choose a user whose permissions will be used for logins that don't
# match any webmin user, but have unix accounts

require './acl-lib.pl';
$access{'unix'} && $access{'create'} && $access{'delete'} ||
	&error($text{'unix_ecannot'});
&ui_print_header(undef, $text{'unix_title'}, "");

print "$text{'unix_desc'}<p>\n";
&get_miniserv_config(\%miniserv);

print "<form action=save_unix.cgi>\n";
print "<table>\n";

# Enable Unix auth
@unixauth = &get_unixauth(\%miniserv);
print "<tr> <td colspan=2>\n";
print &ui_radio("unix_def", @unixauth ? 0 : 1,
	[ [ 1, $text{'unix_def'} ], [ 0, $text{'unix_sel'} ] ]),"<br>\n";
print &ui_columns_start([ $text{'unix_mode'}, $text{'unix_who'},
			  $text{'unix_to'} ]);
$i = 0;
@webmins = map { [ $_->{'name'} ] }
	       sort { $a->{'name'} cmp $b->{'name'} } &list_users();
foreach $ua (@unixauth, [ ], [ ]) {
	print &ui_columns_row([
		&ui_select("mode_$i", $ua->[0] eq "" ? 0 :
				      $ua->[0] eq "*" ? 1 :
				      $ua->[0] =~ /^\@/ ? 2 : 3,
			   [ [ 0, " " ],
			     [ 1, $text{'unix_mall'} ],
			     [ 2, $text{'unix_group'} ],
			     [ 3, $text{'unix_user'} ] ]),
		&ui_textbox("who_$i", $ua->[0] eq "*" || $ua->[0] eq "" ? "" :
			      $ua->[0] =~ /^\@(.*)$/ ? $1 : $ua->[0], 20),
		&ui_select("to_$i", $ua->[1], \@webmins),
		]);
	$i++;
	}
print &ui_columns_end(),"\n";

# Allow users who can sudo to root?
print &ui_checkbox("sudo", 1, $text{'unix_sudo'},
		   $miniserv{'sudo'}),"<br>\n";

# Allow PAM-only users?
print &ui_checkbox("pamany", 1, &text('unix_pamany',
				      &ui_select("pamany_user",
						 $miniserv{'pamany'}, 
						 \@webmins)),
		   $miniserv{'pamany'}),"<br>\n";
print "</td> </tr>\n";

print "<tr> <td colspan=2><hr></td> </tr>\n";
print "<tr> <td colspan=2>$text{'unix_restrict'}<p></td> </tr>\n";

# Who can do Unix auth?
print "<tr> <td valign=top>\n";
printf "<input type=radio name=access value=0 %s>\n",
	$miniserv{"allowusers"} || $miniserv{"denyusers"} ? "" : "checked";
print "$text{'unix_all'}<br>\n";
printf "<input type=radio name=access value=1 %s>\n",
	$miniserv{"allowusers"} ? "checked" : "";
print "$text{'unix_allow'}<br>\n";
printf "<input type=radio name=access value=2 %s>\n",
	$miniserv{"denyusers"} ? "checked" : "";
print "$text{'unix_deny'}<br>\n";
print "</td> <td valign=top>\n";
printf "<textarea name=users rows=6 cols=30>%s</textarea></td> </tr>\n",
 $miniserv{"allowusers"} ? join("\n", split(/\s+/, $miniserv{"allowusers"})) :
 $miniserv{"denyusers"} ? join("\n", split(/\s+/, $miniserv{"denyusers"})) : "";

# Block login by shell?
print "<tr> <td colspan=2>\n";
printf "<input type=checkbox name=shells_deny value=1 %s> %s\n",
	$miniserv{'shells_deny'} ? "checked" : "",$text{'unix_shells'};
printf "<input name=shells size=25 value='%s'> %s</td> </tr>\n",
	$miniserv{'shells_deny'} || "/etc/shells",
	&file_chooser_button("shells");

print "</table>\n";
print "<input type=submit value='$text{'save'}'></form>\n";

&ui_print_footer("", $text{'index_return'});

