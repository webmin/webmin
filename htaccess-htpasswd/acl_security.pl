
require 'htaccess-lib.pl';

# acl_security_form(&options)
# Output HTML for editing security options for the htaccess module
sub acl_security_form
{
print "<tr> <td nowrap><b>$text{'acl_user'}</b></td>\n";
printf "<td><input type=radio name=user_def value=1 %s> %s\n",
	$_[0]->{'user'} eq "*" ? "checked" : "", $text{'acl_same'};
printf "<input type=radio name=user_def value=0 %s>\n",
	$_[0]->{'user'} eq "*" ? "" : "checked";
print &unix_user_input("user", $_[0]->{'user'} eq "*" ? "" : $_[0]->{'user'});
print "</td> </tr>\n";

print "<tr> <td valign=top><b>$text{'acl_dirs'}</b></td>\n";
print "<td><textarea name=dirs rows=5 cols=50>",
	join("\n", split(/\t+/, $_[0]->{'dirs'})),
	"</textarea><br>\n";
printf "<input type=checkbox name=home value=1 %s> %s</td> </tr>\n",
	$_[0]->{'home'} ? "checked" : "", $text{'acl_home'};

print "<tr> <td><b>$text{'acl_sync'}</b></td> <td>\n";
printf "<input type=radio name=sync value=1 %s> $text{'yes'}\n",
	$_[0]->{'sync'} ? 'checked' : '';
printf "<input type=radio name=sync value=0 %s> $text{'no'}</td> </tr>\n",
	$_[0]->{'sync'} ? '' : 'checked';
}

# acl_security_save(&options)
# Parse the form for security options for the cron module
sub acl_security_save
{
$_[0]->{'user'} = $in{'user_def'} ? "*" : $in{'user'};
$in{'dirs'} =~ s/\r//g;
$_[0]->{'dirs'} = join("\t", split(/\n/, $in{'dirs'}));
$_[0]->{'home'} = $in{'home'};
$_[0]->{'sync'} = $in{'sync'};
}

