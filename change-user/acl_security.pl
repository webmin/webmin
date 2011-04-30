
use strict;
use warnings;
do 'change-user-lib.pl';
our (%text, %in);

# acl_security_form(&options)
# Output HTML for editing security options for the acl module
sub acl_security_form
{
print "<tr> <td><b>$text{'acl_lang'}</b></td> <td nowrap>\n";
printf "<input type=radio name=lang value=1 %s> $text{'yes'}\n",
	$_[0]->{'lang'} ? 'checked' : '';
printf "<input type=radio name=lang value=0 %s> $text{'no'}</td>\n",
	$_[0]->{'lang'} ? '' : 'checked';

print "<td><b>$text{'acl_theme'}</b></td> <td nowrap>\n";
printf "<input type=radio name=theme value=1 %s> $text{'yes'}\n",
	$_[0]->{'theme'} ? 'checked' : '';
printf "<input type=radio name=theme value=0 %s> $text{'no'}</td> </tr>\n",
	$_[0]->{'theme'} ? '' : 'checked';

print "<tr> <td><b>$text{'acl_pass'}</b></td> <td nowrap>\n";
printf "<input type=radio name=pass value=1 %s> $text{'yes'}\n",
	$_[0]->{'pass'} ? 'checked' : '';
printf "<input type=radio name=pass value=0 %s> $text{'no'}</td> </tr>\n",
	$_[0]->{'pass'} ? '' : 'checked';
}

# acl_security_save(&options)
# Parse the form for security options for the acl module
sub acl_security_save
{
$_[0]->{'lang'} = $in{'lang'};
$_[0]->{'theme'} = $in{'theme'};
$_[0]->{'pass'} = $in{'pass'};
}

