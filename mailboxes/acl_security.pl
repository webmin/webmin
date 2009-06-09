
require 'mailboxes-lib.pl';

# acl_security_form(&options)
# Output HTML for editing security options for the sendmail module
sub acl_security_form
{
# Users whose mail can be read
print "<tr> <td valign=top><b>$text{'acl_read'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=mmode value=0 %s> $text{'acl_none'}\n",
	$_[0]->{'mmode'} == 0 ? "checked" : "";

printf "<input type=radio name=mmode value=4 %s> $text{'acl_same'}\n",
	$_[0]->{'mmode'} == 4 ? "checked" : "";

printf "<input type=radio name=mmode value=1 %s> $text{'acl_all'}<br>\n",
	$_[0]->{'mmode'} == 1 ? "checked" : "";

printf "<input type=radio name=mmode value=2 %s> $text{'acl_users'}\n",
	$_[0]->{'mmode'} == 2 ? "checked" : "";
printf "<input name=musers size=40 value='%s'> %s<br>\n",
	$_[0]->{'mmode'} == 2 ? $_[0]->{'musers'} : "",
	&user_chooser_button("musers", 1);

printf "<input type=radio name=mmode value=3 %s> $text{'acl_userse'}\n",
	$_[0]->{'mmode'} == 3 ? "checked" : "";
printf "<input name=muserse size=40 value='%s'> %s<br>\n",
	$_[0]->{'mmode'} == 3 ? $_[0]->{'musers'} : "",
	&user_chooser_button("muserse", 1);

printf "<input type=radio name=mmode value=5 %s> $text{'acl_usersg'}\n",
	$_[0]->{'mmode'} == 5 ? "checked" : "";
printf "<input name=musersg size=30 value='%s'> %s\n",
	$_[0]->{'mmode'} == 5 ? join(" ", map { scalar(getgrgid($_)) }
				     split(/\s+/, $_[0]->{'musers'})) : "",
	&group_chooser_button("musersg", 1);
printf "<input type=checkbox name=msec value=1 %s> %s<br>\n",
	$_[0]->{'msec'} ? "checked" : "", $text{'acl_sec'};

printf "<input type=radio name=mmode value=7 %s> $text{'acl_usersu'}\n",
	$_[0]->{'mmode'} == 7 ? "checked" : "";
printf "<input name=musersu1 size=6 value='%s'> -\n",
	$_[0]->{'mmode'} == 7 ? $_[0]->{'musers'} : "";
printf "<input name=musersu2 size=6 value='%s'><br>\n",
	$_[0]->{'mmode'} == 7 ? $_[0]->{'musers2'} : "";

printf "<input type=radio name=mmode value=6 %s> $text{'acl_usersm'}\n",
	$_[0]->{'mmode'} == 6 ? "checked" : "";
printf "<input name=musersm size=15 value='%s'></td> </tr>\n",
	$_[0]->{'mmode'} == 6 ? $_[0]->{'musers'} : "";

# Directory for arbitrary files
print "<tr> <td valign=top><b>$text{'acl_dir'}</b></td> <td colspan=3>\n";
print &ui_opt_textbox("dir", $_[0]->{'dir'}, 40, $text{'acl_dirauto'}."<br>");
print "</td> </tr>\n";

# Allowed From: addresses
print "<tr> <td valign=top><b>$text{'acl_from'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=fmode value=0 %s> $text{'acl_any'}<br>\n",
	$_[0]->{'fmode'} == 0 ? "checked" : "";
printf "<input type=radio name=fmode value=1 %s> $text{'acl_fdoms'}\n",
	$_[0]->{'fmode'} == 1 ? "checked" : "";
printf "<input name=fdoms size=40 value='%s'><br>\n",
	$_[0]->{'fmode'} == 1 ? $_[0]->{'from'} : '';
printf "<input type=radio name=fmode value=2 %s> $text{'acl_faddrs'}\n",
	$_[0]->{'fmode'} == 2 ? "checked" : "";
printf "<input name=faddrs size=40 value='%s'><br>\n",
	$_[0]->{'fmode'} == 2 ? $_[0]->{'from'} : '';
printf "<input type=radio name=fmode value=3 %s> $text{'acl_fdom'}\n",
	$_[0]->{'fmode'} == 3 ? "checked" : "";
printf "<input name=fdom size=20 value='%s'><br>\n",
	$_[0]->{'fmode'} == 3 ? $_[0]->{'from'} : '';
print "</td> </tr>\n";

print "<tr> <td><b>$text{'acl_fromname'}</b></td>\n";
print "<td colspan=3><input name=fromname size=40 ",
      "value='$_[0]->{'fromname'}'></td> </tr>\n";

print "<tr> <td><b>$text{'acl_attach'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=attach_def value=1 %s> %s\n",
	$_[0]->{'attach'}<0 ? 'checked' : '', $text{'acl_unlimited'};
printf "<input type=radio name=attach_def value=0 %s>\n",
	$_[0]->{'attach'}<0 ? '' : 'checked';
printf "<input name=attach size=5 value='%s'> kB\n",
	$_[0]->{'attach'}<0 ? '' : $_[0]->{'attach'};
print "</td> </tr>\n";

print "<tr> <td><b>$text{'acl_canattach'}</b></td>\n";
printf "<td colspan=3><input type=radio name=canattach value=1 %s> %s\n",
	$_[0]->{'canattach'} ? 'checked' : '', $text{'yes'};
printf "<input type=radio name=canattach value=0 %s> %s</td> </tr>\n",
	$_[0]->{'canattach'} ? '' : 'checked', $text{'no'};

print "<tr> <td><b>$text{'acl_candetach'}</b></td>\n";
printf "<td colspan=3><input type=radio name=candetach value=1 %s> %s\n",
	$_[0]->{'candetach'} ? 'checked' : '', $text{'yes'};
printf "<input type=radio name=candetach value=0 %s> %s</td> </tr>\n",
	$_[0]->{'candetach'} ? '' : 'checked', $text{'no'};
}

# acl_security_save(&options)
# Parse the form for security options for the sendmail module
sub acl_security_save
{
$_[0]->{'mmode'} = $in{'mmode'};
$_[0]->{'musers'} = $in{'mmode'} == 2 ? $in{'musers'} :
		    $in{'mmode'} == 3 ? $in{'muserse'} :
		    $in{'mmode'} == 5 ? join(" ", map { scalar(getgrnam($_)) }
					     split(/\s+/, $in{'musersg'})) :
		    $in{'mmode'} == 6 ? $in{'musersm'} :
		    $in{'mmode'} == 7 ? $in{'musersu1'} : "";
$_[0]->{'musers2'} = $in{'mmode'} == 7 ? $in{'musersu2'} : "";
$_[0]->{'msec'} = $in{'msec'};
$_[0]->{'fmode'} = $in{'fmode'};
$_[0]->{'from'} = $in{'fmode'} == 0 ? undef :
		  $in{'fmode'} == 1 ? $in{'fdoms'} :
		  $in{'fmode'} == 2 ? $in{'faddrs'} : $in{'fdom'};
$_[0]->{'fromname'} = $in{'fromname'};
$_[0]->{'attach'} = $in{'attach_def'} ? -1 : $in{'attach'};
$_[0]->{'canattach'} = $in{'canattach'};
$_[0]->{'candetach'} = $in{'candetach'};
$_[0]->{'dir'} = $in{'dir_def'} ? undef : $in{'dir'};
}

