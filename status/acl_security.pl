
do 'status-lib.pl';

# acl_security_form(&options)
# Output HTML for editing security options for the status module
sub acl_security_form
{
print "<tr> <td><b>$text{'acl_edit'}</b></td> <td>\n";
printf "<input type=radio name=edit value=1 %s> $text{'yes'}\n",
	$_[0]->{'edit'} ? 'checked' : '';
printf "<input type=radio name=edit value=0 %s> $text{'no'}</td>\n",
	$_[0]->{'edit'} ? '' : 'checked';

print "<td><b>$text{'acl_sched'}</b></td> <td>\n";
printf "<input type=radio name=sched value=1 %s> $text{'yes'}\n",
	$_[0]->{'sched'} ? 'checked' : '';
printf "<input type=radio name=sched value=0 %s> $text{'no'}</td> </tr>\n",
	$_[0]->{'sched'} ? '' : 'checked';
}

# acl_security_save(&options)
# Parse the form for security options for the acl module
sub acl_security_save
{
$_[0]->{'edit'} = $in{'edit'};
$_[0]->{'sched'} = $in{'sched'};
}

