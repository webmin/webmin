
require 'updown-lib.pl';

# acl_security_form(&options)
# Output HTML for editing security options for the updown module
sub acl_security_form
{
print "<tr> <td><b>$text{'acl_upload'}</b></td>\n";
printf "<td colspan=3><input type=radio name=upload value=1 %s> %s\n",
	$_[0]->{'upload'} ? "checked" : "", $text{'yes'};
printf "<input type=radio name=upload value=0 %s> %s</td> </tr>\n",
	$_[0]->{'upload'} ? "" : "checked", $text{'no'};

print "<tr> <td nowrap><b>$text{'acl_max'}</b></td>\n";
printf "<td colspan=3><input type=radio name=max_def value=1 %s> %s\n",
	$_[0]->{'max'} ? "" : "checked", $text{'acl_unlim'};
printf "<input type=radio name=max_def value=0 %s>\n",
	$_[0]->{'max'} ? "checked" : "";
printf "<input name=max size=8 value='%s'> %s</td> </tr>\n",
	$_[0]->{'max'}, $text{'acl_b'};

print "<tr> <td><b>$text{'acl_download'}</b></td>\n";
printf "<td colspan=3><input type=radio name=download value=1 %s> %s\n",
	$_[0]->{'download'} == 1 ? "checked" : "", $text{'yes'};
printf "<input type=radio name=download value=2 %s> %s\n",
	$_[0]->{'download'} == 2 ? "checked" : "", $text{'acl_nosched'};
printf "<input type=radio name=download value=0 %s> %s</td> </tr>\n",
	$_[0]->{'download'} == 0 ? "checked" : "", $text{'no'};

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

print "<tr> <td valign=top><b>$text{'acl_dirs'}</b></td> <td colspan=3>\n";
print "<textarea name=dirs rows=3 cols=50>",
	join("\n", split(/\s+/, $_[0]->{'dirs'})),"</textarea><br>\n";
printf "<input type=checkbox name=home value=1 %s> %s</td> </tr>\n",
	$_[0]->{'home'} ? 'checked' : '', $text{'acl_home'};

print "<tr> <td><b>$text{'acl_fetch'}</b></td>\n";
printf "<td colspan=3><input type=radio name=fetch value=1 %s> %s\n",
	$_[0]->{'fetch'} ? "checked" : "", $text{'yes'};
printf "<input type=radio name=fetch value=0 %s> %s</td> </tr>\n",
	$_[0]->{'fetch'} ? "" : "checked", $text{'no'};
}

# acl_security_save(&options)
# Parse the form for security options for the cron module
sub acl_security_save
{
$_[0]->{'upload'} = $in{'upload'};
$_[0]->{'max'} = $in{'max_def'} ? undef : $in{'max'};
$_[0]->{'download'} = $in{'download'};
$_[0]->{'mode'} = $in{'mode'};
$_[0]->{'users'} = $in{'mode'} == 0 || $in{'mode'} == 3 ? "" :
		   $in{'mode'} == 1 ? $in{'userscan'}
				    : $in{'userscannot'};
local @dirs = split(/\s+/, $in{'dirs'});
map { s/\/+/\//g } @dirs;
map { s/([^\/])\/+$/$1/ } @dirs;
$_[0]->{'dirs'} = join(" ", @dirs);
$_[0]->{'home'} = $in{'home'};
$_[0]->{'fetch'} = $in{'fetch'};
}

