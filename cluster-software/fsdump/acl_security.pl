
do 'fsdump-lib.pl';

# acl_security_form(&options)
# Output HTML for editing security options for the acl module
sub acl_security_form
{
print "<tr> <td valign=top><b>$text{'acl_edit'}</b></td> <td valign=top>\n";
printf "<input type=radio name=edit value=1 %s> %s\n",
	$_[0]->{'edit'} ? "checked" : "", $text{'yes'};
printf "<input type=radio name=edit value=0 %s> %s</td>\n",
	$_[0]->{'edit'} ? "" : "checked", $text{'no'};

print "<td valign=top><b>$text{'acl_restore'}</b></td> <td valign=top>\n";
printf "<input type=radio name=restore value=1 %s> %s\n",
	$_[0]->{'restore'} ? "checked" : "", $text{'yes'};
printf "<input type=radio name=restore value=0 %s> %s</td> </tr>\n",
	$_[0]->{'restore'} ? "" : "checked", $text{'no'};

print "<tr> <td valign=top><b>$text{'acl_cmds'}</b></td> <td valign=top>\n";
printf "<input type=radio name=cmds value=1 %s> %s\n",
	$_[0]->{'cmds'} ? "checked" : "", $text{'yes'};
printf "<input type=radio name=cmds value=0 %s> %s</td>\n",
	$_[0]->{'cmds'} ? "" : "checked", $text{'no'};

print "<td valign=top><b>$text{'acl_extra'}</b></td> <td valign=top>\n";
printf "<input type=radio name=extra value=1 %s> %s\n",
	$_[0]->{'extra'} ? "checked" : "", $text{'yes'};
printf "<input type=radio name=extra value=0 %s> %s</td> </tr>\n",
	$_[0]->{'extra'} ? "" : "checked", $text{'no'};

print "<tr> <td valign=top><b>$text{'acl_dirs'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=dirs_def value=1 %s> %s\n",
	$_[0]->{'dirs'} eq "*" ? "checked" : "", $text{'acl_all'};
printf "<input type=radio name=dirs_def value=0 %s> %s<br>\n",
	$_[0]->{'dirs'} eq "*" ? "" : "checked", $text{'acl_list'};
print "<textarea name=dirs rows=5 cols=30>",
	$_[0]->{'dirs'} eq "*" ? "" :
	join("\n", split(/\t/, $_[0]->{'dirs'})),"</textarea></td> </tr>\n";


}

# acl_security_save(&options)
# Parse the form for security options for the acl module
sub acl_security_save
{
$_[0]->{'edit'} = $in{'edit'};
$_[0]->{'restore'} = $in{'restore'};
$_[0]->{'cmds'} = $in{'cmds'};
$_[0]->{'extra'} = $in{'extra'};
$in{'dirs'} =~ s/\r//g;
$_[0]->{'dirs'} = $in{'dirs_def'} ? "*" :
			join("\t", split(/\n/, $in{'dirs'}));
}

