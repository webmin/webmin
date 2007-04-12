
do 'bandwidth-lib.pl';

# acl_security_form(&options)
# Output HTML for editing security options for the acl module
sub acl_security_form
{
print "<tr> <td><b>$text{'acl_setup'}</b></td> <td>\n";
printf "<input type=radio name=setup value=1 %s> $text{'yes'}\n",
	$o->{'setup'} ? 'checked' : '';
printf "<input type=radio name=setup value=0 %s> $text{'no'}</td> </tr>\n",
	$o->{'setup'} ? '' : 'checked';
}

# acl_security_save(&options)
# Parse the form for security options for the acl module
sub acl_security_save
{
$_[0]->{'setup'} = $in{'setup'};
}

