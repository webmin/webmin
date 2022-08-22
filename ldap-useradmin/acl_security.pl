# XXX need little module for assigning ACLs

require 'ldap-useradmin-lib.pl';

# acl_security_form(&options)
# Output HTML for editing security options for the useradmin module
sub acl_security_form
{
local $o = $_[0];

print "<tr> <td valign=top><b>$text{'acl_uedit'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=uedit_mode value=0 %s> $text{'acl_uedit_all'}&nbsp;&nbsp;\n",
	$o->{'uedit_mode'} == 0 ? "checked" : "";
printf "<input type=radio name=uedit_mode value=1 %s> $text{'acl_uedit_none'}&nbsp;\n",
	$o->{'uedit_mode'} == 1 ? "checked" : "";
printf "<input type=radio name=uedit_mode value=6 %s> $text{'acl_uedit_this'}<br>\n",
	$o->{'uedit_mode'} == 6 ? "checked" : "";
printf "<input type=radio name=uedit_mode value=2 %s> $text{'acl_uedit_only'}\n",
	$o->{'uedit_mode'} == 2 ? "checked" : "";
printf "<input name=uedit_can size=40 value='%s'> %s<br>\n",
	$o->{'uedit_mode'} == 2 ? $o->{'uedit'} : "",
	&user_chooser_button("uedit_can", 1);
printf "<input type=radio name=uedit_mode value=3 %s> $text{'acl_uedit_except'}\n",
	$o->{'uedit_mode'} == 3 ? "checked" : "";
printf "<input name=uedit_cannot size=40 value='%s'> %s<br>\n",
	$o->{'uedit_mode'} == 3 ? $o->{'uedit'} : "",
	&user_chooser_button("uedit_cannot", 1);
printf "<input type=radio name=uedit_mode value=4 %s> $text{'acl_uedit_uid'}\n",
	$o->{'uedit_mode'} == 4 ? "checked" : "";
printf "<input name=uedit_uid size=6 value='%s'> - \n",
	$o->{'uedit_mode'} == 4 ? $o->{'uedit'} : "";
printf "<input name=uedit_uid2 size=6 value='%s'><br>\n",
	$o->{'uedit_mode'} == 4 ? $o->{'uedit2'} : "";
printf "<input type=radio name=uedit_mode value=5 %s> $text{'acl_uedit_group'}\n",
	$o->{'uedit_mode'} == 5 ? "checked" : "";
printf "<input name=uedit_group size=40 value='%s'> %s<br>\n",
	$o->{'uedit_mode'} == 5 ?
	 join(" ", map { "".getgrgid($_) } split(/\s+/, $o->{'uedit'})) :"",
	&group_chooser_button("uedit_group", 1);
printf "%s <input type=checkbox name=uedit_sec value=1 %s> %s<br>\n",
	"&nbsp;" x 5, $o->{'uedit_sec'} ? 'checked' : '',$text{'acl_uedit_sec'};
printf "<input type=radio name=uedit_mode value=7 %s> $text{'acl_uedit_re'}\n",
	$o->{'uedit_mode'} == 7 ? "checked" : "";
printf "<input name=uedit_re size=40 value='%s'> %s<br>\n",
	$o->{'uedit_mode'} == 7 ? $o->{'uedit_re'} : "";
print "</td> </tr>\n";

print "<tr> <td><b>$text{'acl_ucreate'}</b></td> <td>\n";
printf "<input type=radio name=ucreate value=1 %s> $text{'yes'}\n",
	$o->{'ucreate'} ? "checked" : "";
printf "<input type=radio name=ucreate value=0 %s> $text{'no'}</td>\n",
	$o->{'ucreate'} ? "" : "checked";

print "<td><b>$text{'acl_batch'}</b></td> <td>\n";
printf "<input type=radio name=batch value=1 %s> $text{'yes'}\n",
	$o->{'batch'} ? "checked" : "";
printf "<input type=radio name=batch value=0 %s> $text{'no'}</td> </tr>\n",
	$o->{'batch'} ? "" : "checked";

print "<tr> <td valign=top><b>$text{'acl_home'}</b></td>\n";
printf "<td colspan=3><input name=home size=40 value='%s'> %s<br>\n",
	$o->{'home'}, &file_chooser_button("home", 1);
printf "<input type=checkbox name=autohome value=1 %s> %s</td> </tr>\n",
	$o->{'autohome'} ? "checked" : "",
	$text{'acl_autohome'};

print "<tr> <td valign=top><b>$text{'acl_uid'}</b></td>\n";
print "<td colspan=3>";
printf "<input type=checkbox name=umultiple value=1 %s> %s<br>\n",
        $o->{'umultiple'} ? "checked" : "", $text{'acl_umultiple'};
printf "<input type=checkbox name=gmultiple value=1 %s> %s<br>\n",
        $o->{'gmultiple'} ? "checked" : "", $text{'acl_gmultiple'};
print "</td> </tr>\n";

print "<tr> <td colspan=4><hr></td> </tr>\n";

print "<tr> <td valign=top><b>$text{'acl_gedit'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=gedit_mode value=0 %s> $text{'acl_gedit_all'}&nbsp;&nbsp;\n",
	$o->{'gedit_mode'} == 0 ? "checked" : "";
printf "<input type=radio name=gedit_mode value=1 %s> $text{'acl_gedit_none'}<br>\n",
	$o->{'gedit_mode'} == 1 ? "checked" : "";
printf "<input type=radio name=gedit_mode value=2 %s> $text{'acl_gedit_only'}\n",
	$o->{'gedit_mode'} == 2 ? "checked" : "";
printf "<input name=gedit_can size=40 value='%s'> %s<br>\n",
	$o->{'gedit_mode'} == 2 ? $o->{'gedit'} : "",
	&group_chooser_button("gedit_can", 1);
printf "<input type=radio name=gedit_mode value=3 %s> $text{'acl_gedit_except'}\n",
	$o->{'gedit_mode'} == 3 ? "checked" : "";
printf "<input name=gedit_cannot size=40 value='%s'> %s<br>\n",
	$o->{'gedit_mode'} == 3 ? $o->{'gedit'} : "",
	&group_chooser_button("gedit_cannot", 1);
printf "<input type=radio name=gedit_mode value=4 %s> $text{'acl_gedit_gid'}\n",
	$o->{'gedit_mode'} == 4 ? "checked" : "";
printf "<input name=gedit_gid size=6 value='%s'> -\n",
	$o->{'gedit_mode'} == 4 ? $o->{'gedit'} : "";
printf "<input name=gedit_gid2 size=6 value='%s'></td> </tr>\n",
	$o->{'gedit_mode'} == 4 ? $o->{'gedit2'} : "";

print "<tr> <td><b>$text{'acl_gcreate'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=gcreate value=1 %s> $text{'yes'}\n",
	$o->{'gcreate'}==1 ? "checked" : "";
printf "<input type=radio name=gcreate value=2 %s> $text{'acl_gnew'}\n",
	$o->{'gcreate'}==2 ? "checked" : "";
printf "<input type=radio name=gcreate value=0 %s> $text{'no'}</td> </tr>\n",
	$o->{'gcreate'}==0 ? "checked" : "";
}

# acl_security_save(&options)
# Parse the form for security options for the ldap-useradmin module
sub acl_security_save
{
$_[0]->{'uedit_mode'} = $in{'uedit_mode'};
$_[0]->{'uedit'} = $in{'uedit_mode'} == 2 ? $in{'uedit_can'} :
		   $in{'uedit_mode'} == 3 ? $in{'uedit_cannot'} :
		   $in{'uedit_mode'} == 4 ? $in{'uedit_uid'} :
		   $in{'uedit_mode'} == 5 ?
			join(" ", map { "".getgrnam($_) }
			     split(/\s+/, $in{'uedit_group'})) : "";
$_[0]->{'uedit2'} = $in{'uedit_mode'} == 4 ? $in{'uedit_uid2'} : undef;
$_[0]->{'uedit_sec'} = $in{'uedit_mode'} == 5 ? $in{'uedit_sec'} : undef;
$_[0]->{'uedit_re'} = $in{'uedit_mode'} == 7 ? $in{'uedit_re'} : undef;
$_[0]->{'gedit_mode'} = $in{'gedit_mode'};
$_[0]->{'gedit'} = $in{'gedit_mode'} == 2 ? $in{'gedit_can'} :
		   $in{'gedit_mode'} == 3 ? $in{'gedit_cannot'} :
		   $in{'gedit_mode'} == 4 ? $in{'gedit_gid'} : "";
$_[0]->{'gedit2'} = $in{'gedit_mode'} == 4 ? $in{'gedit_gid2'} : undef;
$_[0]->{'ucreate'} = $in{'ucreate'};
$_[0]->{'gcreate'} = $in{'gcreate'};

$_[0]->{'batch'} = $in{'batch'};
$_[0]->{'home'} = $in{'home'};
$_[0]->{'autohome'} = $in{'autohome'};
$_[0]->{'umultiple'} = $in{'umultiple'};
$_[0]->{'gmultiple'} = $in{'gmultiple'};
}
