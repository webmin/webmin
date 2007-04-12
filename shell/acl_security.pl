
do 'shell-lib.pl';

# acl_security_form(&options)
# Output HTML for editing security options for the shell module
sub acl_security_form
{
print "<tr> <td><b>$text{'acl_user'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=user_def value=1 %s> %s\n",
	$_[0]->{'user'} ? '' : 'checked', $text{'acl_user_def'};
printf "<input type=radio name=user_def value=0 %s>\n",
	$_[0]->{'user'} ? 'checked' : '';
print "<input name=user size=8 value='$_[0]->{'user'}'> ",
      &user_chooser_button("user"),"</td> </tr>\n";
}

# acl_security_save(&options)
# Parse the form for security options for the shell module
sub acl_security_save
{
$_[0]->{'user'} = $in{'user_def'} ? undef : $in{'user'};
}

