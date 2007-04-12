
do 'burner-lib.pl';

# acl_security_form(&options)
# Output HTML for editing security options for the acl module
sub acl_security_form
{
print "<tr> <td><b>$text{'acl_create'}</b></td> <td>\n";
printf "<input type=radio name=create value=1 %s> $text{'yes'}\n",
	$_[0]->{'create'} ? 'checked' : '';
printf "<input type=radio name=create value=0 %s> $text{'no'}</td>\n",
	$_[0]->{'create'} ? '' : 'checked';

print "<td><b>$text{'acl_edit'}</b></td> <td>\n";
printf "<input type=radio name=edit value=1 %s> $text{'yes'}\n",
	$_[0]->{'edit'} ? 'checked' : '';
printf "<input type=radio name=edit value=0 %s> $text{'no'}</td> </tr>\n",
	$_[0]->{'edit'} ? '' : 'checked';

print "<tr> <td><b>$text{'acl_global'}</b></td> <td>\n";
printf "<input type=radio name=global value=1 %s> $text{'yes'}\n",
	$_[0]->{'global'} ? 'checked' : '';
printf "<input type=radio name=global value=0 %s> $text{'no'}</td>\n",
	$_[0]->{'global'} ? '' : 'checked';
print "</tr>\n";

print "<tr> <td valign=top><b>$text{'acl_profiles'}</b></td>\n";
print "<td colspan=3>\n";
printf "<input type=radio name=all value=1 %s> %s\n",
	$_[0]->{'profiles'} eq "*" ? "checked" : "", $text{'acl_all'};
printf "<input type=radio name=all value=0 %s> %s<br>\n",
	$_[0]->{'profiles'} eq "*" ? "" : "checked", $text{'acl_sel'};
print "<select name=profiles multiple size=5>\n";
local $p;
local %can = map { $_, 1 } split(/\s+/, $_[0]->{'profiles'});
foreach $p (&list_profiles()) {
	printf "<option value=%s %s>%s (%s)\n",
		$p->{'id'}, $can{$p->{'id'}} ? "selected" : "",
		$text{'index_type'.$p->{'type'}},
		$p->{'type'} == 1 ? $p->{'iso'} :
		$p->{'type'} == 4 ? $p->{'sdesc'} : $p->{'source_0'}.
					    ($p->{'source_1'} ? ", ..." : "");
	}
print "</select></td> </tr>\n";

print "<tr> <td><b>$text{'acl_dirs'}</b></td> <td colspan=2>\n";
printf "<input name=dirs size=40 value='%s'></td> </tr>\n",
	$_[0]->{'dirs'};
}

# acl_security_save(&options)
# Parse the form for security options for the acl module
sub acl_security_save
{
$_[0]->{'create'} = $in{'create'};
$_[0]->{'edit'} = $in{'edit'};
$_[0]->{'global'} = $in{'global'};
$_[0]->{'profiles'} = $in{'all'} ? "*" :
			join(" ", split(/\0/, $in{'profiles'}));
$_[0]->{'dirs'} = $in{'dirs'};
}

