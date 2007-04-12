
require 'cron-lib.pl';
do '../ui-lib.pl';

# acl_security_form(&options)
# Output HTML for editing security options for the cron module
sub acl_security_form
{
print "<tr> <td valign=top><b>$text{'acl_users'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=mode value=0 %s> $text{'acl_all'}<br>\n",
	$_[0]->{'mode'} == 0 ? "checked" : "";

printf "<input type=radio name=mode value=3 %s> $text{'acl_this'}<br>\n",
	$_[0]->{'mode'} == 3 ? "checked" : "";

printf "<input type=radio name=mode value=1 %s> $text{'acl_only'}\n",
	$_[0]->{'mode'} == 1 ? "checked" : "";
printf "<input name=userscan size=40 value='%s'> %s<br>\n",
	$_[0]->{'mode'} == 1 ? $_[0]->{'users'} : "",
	&user_chooser_button("userscan", 1);

printf "<input type=radio name=mode value=2 %s> $text{'acl_except'}\n",
	$_[0]->{'mode'} == 2 ? "checked" : "";
printf "<input name=userscannot size=40 value='%s'> %s<br>\n",
	$_[0]->{'mode'} == 2 ? $_[0]->{'users'} : "",
	&user_chooser_button("userscannot", 1);

printf "<input type=radio name=mode value=5 %s> $text{'acl_gid'}\n",
	$_[0]->{'mode'} == 5 ? "checked" : "";
printf "<input name=gid size=8 value='%s'> %s<br>\n",
	$_[0]->{'mode'} == 5 ? scalar(getgrgid($_[0]->{'users'})) : "",
	&group_chooser_button("gid", 0);

printf "<input type=radio name=mode value=4 %s> $text{'acl_uid'}\n",
	$_[0]->{'mode'} == 4 ? "checked" : "";
printf "<input name=uidmin size=6 value='%s'> -\n",
	$_[0]->{'mode'} == 4 ? $_[0]->{'uidmin'} : "";
printf "<input name=uidmax size=6 value='%s'></td> </tr>\n",
	$_[0]->{'mode'} == 4 ? $_[0]->{'uidmax'} : "";

print "<tr> <td><b>$text{'acl_control'}</b></td>\n";
print "<td>",&ui_radio("allow", $_[0]->{'allow'},
	[ [ 1, $text{'yes'} ], [ 0, $text{'no'} ] ]),"</td>\n";

print "<td><b>$text{'acl_command'}</b></td>\n";
print "<td>",&ui_radio("command", $_[0]->{'command'},
	[ [ 1, $text{'yes'} ], [ 0, $text{'no'} ] ]),"</td> </tr>\n";

print "<tr> <td><b>$text{'acl_create'}</b></td>\n";
print "<td>",&ui_radio("create", $_[0]->{'create'},
	[ [ 1, $text{'yes'} ], [ 0, $text{'no'} ] ]),"</td>\n";

print "<td><b>$text{'acl_delete'}</b></td>\n";
print "<td>",&ui_radio("delete", $_[0]->{'delete'},
	[ [ 1, $text{'yes'} ], [ 0, $text{'no'} ] ]),"</td> </tr>\n";

print "<tr> <td><b>$text{'acl_move'}</b></td>\n";
print "<td>",&ui_radio("move", $_[0]->{'move'},
	[ [ 1, $text{'yes'} ], [ 0, $text{'no'} ] ]),"</td>\n";

print "<td><b>$text{'acl_kill'}</b></td>\n";
print "<td>",&ui_radio("kill", $_[0]->{'kill'},
	[ [ 1, $text{'yes'} ], [ 0, $text{'no'} ] ]),"</td> </tr>\n";

print "</tr>\n";
}

# acl_security_save(&options)
# Parse the form for security options for the cron module
sub acl_security_save
{
$_[0]->{'mode'} = $in{'mode'};
$_[0]->{'users'} = $in{'mode'} == 0 || $in{'mode'} == 3 ||
		   $in{'mode'} == 4 ? "" :
		   $in{'mode'} == 5 ? scalar(getgrnam($in{'gid'})) :
		   $in{'mode'} == 1 ? $in{'userscan'}
				    : $in{'userscannot'};
$_[0]->{'uidmin'} = $in{'mode'} == 4 ? $in{'uidmin'} : "";
$_[0]->{'uidmax'} = $in{'mode'} == 4 ? $in{'uidmax'} : "";
$_[0]->{'allow'} = $in{'allow'};
$_[0]->{'command'} = $in{'command'};
$_[0]->{'create'} = $in{'create'};
$_[0]->{'delete'} = $in{'delete'};
$_[0]->{'move'} = $in{'move'};
$_[0]->{'kill'} = $in{'kill'};
}

