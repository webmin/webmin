
do 'webalizer-lib.pl';

# acl_security_form(&options)
# Output HTML for editing security options for the webalizer module
sub acl_security_form
{
print "<tr> <td><b>$text{'acl_view'}</b></td>\n";
printf "<td nowrap><input type=radio name=view value=1 %s> %s\n",
	$_[0]->{'view'} ? "checked" : "", $text{'yes'};
printf "<input type=radio name=view value=0 %s> %s</td>\n",
	$_[0]->{'view'} ? "" : "checked", $text{'no'};

print "<td><b>$text{'acl_global'}</b></td>\n";
printf "<td nowrap><input type=radio name=global value=1 %s> %s\n",
	$_[0]->{'global'} ? "checked" : "", $text{'yes'};
printf "<input type=radio name=global value=0 %s> %s</td> </tr>\n",
	$_[0]->{'global'} ? "" : "checked", $text{'no'};

print "<tr> <td><b>$text{'acl_add'}</b></td>\n";
printf "<td nowrap><input type=radio name=add value=1 %s> %s\n",
	$_[0]->{'add'} ? "checked" : "", $text{'yes'};
printf "<input type=radio name=add value=0 %s> %s</td> </tr>\n",
	$_[0]->{'add'} ? "" : "checked", $text{'no'};

print "<tr> <td><b>$text{'acl_user'}</b></td>\n";
printf "<td colspan=3><input type=radio name=user_def value=1 %s> %s\n",
	$_[0]->{'user'} eq "" ? "checked" : "", $text{'acl_this'};
printf "<input type=radio name=user_def value=2 %s> %s\n",
	$_[0]->{'user'} eq "*" ? "checked" : "", $text{'acl_any'};
printf "<input type=radio name=user_def value=0 %s>\n",
	$_[0]->{'user'} eq "*" || $_[0]->{'user'} eq "" ? "" : "checked";
printf "<input name=user size=8 value='%s'> %s</td> </tr>\n",
	$_[0]->{'user'} eq "*" ? "" : $_[0]->{'user'},
	&user_chooser_button("user");

print "<tr> <td><b>$text{'acl_dir'}</b></td>\n";
print "<td colspan=3><input name=dir size=50 value='$_[0]->{'dir'}'></td> </tr>\n";
}

# acl_security_save(&options)
# Parse the form for security options for the shell module
sub acl_security_save
{
$_[0]->{'view'} = $in{'view'};
$_[0]->{'global'} = $in{'global'};
$_[0]->{'add'} = $in{'add'};
$_[0]->{'dir'} = $in{'dir'};
$_[0]->{'user'} = $in{'user_def'} == 2 ? "*" :
		  $in{'user_def'} == 1 ? "" : $in{'user'};
}

