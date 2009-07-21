
require 'cluster-passwd-lib.pl';

# acl_security_form(&options)
# Output HTML for editing security options for the passwd module
sub acl_security_form
{
print "<tr> <td valign=top><b>$passwd::text{'acl_users'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=mode value=0 %s> %s\n",
	$_[0]->{'mode'} == 0 ? 'checked' : '', $passwd::text{'acl_mode0'};

printf "<input type=radio name=mode value=3 %s> %s<br>\n",
	$_[0]->{'mode'} == 3 ? 'checked' : '', $passwd::text{'acl_mode3'};

printf "<input type=radio name=mode value=1 %s> %s\n",
	$_[0]->{'mode'} == 1 ? 'checked' : '', $passwd::text{'acl_mode1'};
printf "<input name=users1 size=40 value='%s'> %s<br>\n",
	$_[0]->{'mode'} == 1 ? $_[0]->{'users'} : '',
	&user_chooser_button("users1", 1);

printf "<input type=radio name=mode value=2 %s> %s\n",
	$_[0]->{'mode'} == 2 ? 'checked' : '', $passwd::text{'acl_mode2'};
printf "<input name=users2 size=40 value='%s'> %s<br>\n",
	$_[0]->{'mode'} == 2 ? $_[0]->{'users'} : '',
	&user_chooser_button("users2", 1);

printf "<input type=radio name=mode value=4 %s> %s\n",
	$_[0]->{'mode'} == 4 ? 'checked' : '', $passwd::text{'acl_mode4'};
printf "<input name=low size=8 value='%s'> -\n",
	$_[0]->{'mode'} == 4 ? $_[0]->{'low'} : '';
printf "<input name=high size=8 value='%s'><br>\n",
	$_[0]->{'mode'} == 4 ? $_[0]->{'high'} : '';

printf "<input type=radio name=mode value=5 %s> %s\n",
	$_[0]->{'mode'} == 5 ? 'checked' : '', $passwd::text{'acl_mode5'};
printf "<input name=groups size=20 value='%s'> %s<br>\n",
	$_[0]->{'mode'} == 5 ? $_[0]->{'users'} : '',
	&group_chooser_button("groups", 1);
printf "%s <input type=checkbox name=sec value=1 %s> %s<br>\n",
        "&nbsp;" x 5, $_[0]->{'sec'} ? 'checked' : '',$passwd::text{'acl_sec'};

printf "<input type=radio name=mode value=6 %s> %s\n",
	$_[0]->{'mode'} == 6 ? 'checked' : '', $passwd::text{'acl_mode6'};
printf "<input name=match size=15 value='%s'></td> </tr>\n",
	$_[0]->{'mode'} == 6 ? $_[0]->{'users'} : '';

print "<tr> <td><b>$passwd::text{'acl_repeat'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=repeat value=1 %s> $passwd::text{'yes'}\n",
	$_[0]->{'repeat'} ? "checked" : "";
printf "<input type=radio name=repeat value=0 %s> $passwd::text{'no'}</td> </tr>\n",
	$_[0]->{'repeat'} ? "" : "checked";

print "<td><b>$passwd::text{'acl_others'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=others value=1 %s> $passwd::text{'yes'}\n",
	$_[0]->{'others'} == 1 ? "checked" : "";
printf "<input type=radio name=others value=2 %s> $passwd::text{'acl_opt'}\n",
	$_[0]->{'others'} == 2 ? "checked" : "";
printf "<input type=radio name=others value=0 %s> $passwd::text{'no'}</td> </tr>\n",
	$_[0]->{'others'} == 0 ? "checked" : "";

print "<tr> <td><b>$passwd::text{'acl_old'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=old value=1 %s> $passwd::text{'yes'}\n",
	$_[0]->{'old'} == 1 ? "checked" : "";
printf "<input type=radio name=old value=2 %s> $passwd::text{'acl_old_this'}\n",
	$_[0]->{'old'} == 2 ? "checked" : "";
printf "<input type=radio name=old value=0 %s> $passwd::text{'no'}</td> </tr>\n",
	$_[0]->{'old'} == 0 ? "checked" : "";
}

# acl_security_save(&options)
# Parse the form for security options for the bind8 module
sub acl_security_save
{
$_[0]->{'mode'} = $in{'mode'};
$_[0]->{'users'} = $in{'mode'} == 1 ? $in{'users1'} :
		   $in{'mode'} == 2 ? $in{'users2'} :
		   $in{'mode'} == 5 ? $in{'groups'} :
		   $in{'mode'} == 6 ? $in{'match'} : undef;
$_[0]->{'low'} = $in{'low'};
$_[0]->{'high'} = $in{'high'};
$_[0]->{'repeat'} = $in{'repeat'};
$_[0]->{'old'} = $in{'old'};
$_[0]->{'others'} = $in{'others'};
$_[0]->{'expire'} = $in{'expire'};
$_[0]->{'sec'} = $in{'sec'};
}

