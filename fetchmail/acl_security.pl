
require 'fetchmail-lib.pl';

# acl_security_form(&options)
# Output HTML for editing security options for the fetchmail module
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
printf "<input name=userscannot size=40 value='%s'> %s</td> </tr>\n",
	$_[0]->{'mode'} == 2 ? $_[0]->{'users'} : "",
	&user_chooser_button("userscannot", 1);

print "<tr> <td valign=top><b>$text{'acl_cron'}</b></td> <td>\n";
print &ui_radio("cron", $_[0]->{'cron'},
		[ [ 1, $text{'yes'} ], [ 0, $text{'no'} ] ]),"</td>\n";

print "<td valign=top><b>$text{'acl_daemon'}</b></td> <td>\n";
print &ui_radio("daemon", $_[0]->{'daemon'},
		[ [ 1, $text{'yes'} ], [ 0, $text{'no'} ] ]),"</td> </tr>\n";
}

# acl_security_save(&options)
# Parse the form for security options for the fetchmail module
sub acl_security_save
{
$_[0]->{'mode'} = $in{'mode'};
$_[0]->{'users'} = $in{'mode'} == 0 || $in{'mode'} == 3 ? "" :
		   $in{'mode'} == 1 ? $in{'userscan'}
				    : $in{'userscannot'};
$_[0]->{'cron'} = $in{'cron'};
$_[0]->{'daemon'} = $in{'daemon'};

}

