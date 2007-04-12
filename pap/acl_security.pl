
require 'pap-lib.pl';

# acl_security_form(&options)
# Output HTML for editing security options for the pap module
sub acl_security_form
{
print "<tr> <td valign=top><b>$text{'acl_pages'}</b></td> <td colspan=3>\n";
foreach $a ('mgetty', 'options', 'dialin', 'secrets', 'sync') {
	print "&nbsp;&nbsp;\n" if ($a eq 'sync');
	printf "<input type=checkbox name=%s value=1 %s> %s<br>\n",
		$a, $_[0]->{$a} ? "checked" : "", $text{$a."_title"};
	}
print "</td> </tr>\n";

print "<tr> <td><b>$text{'acl_direct'}</b></td>\n";
printf "<td><input type=radio name=direct value=1 %s> %s\n",
	$_[0]->{'direct'} ? "checked" : "", $text{'yes'};
printf "<input type=radio name=direct value=0 %s> %s</td> </tr>\n",
	$_[0]->{'direct'} ? "" : "checked", $text{'no'};
}

# acl_security_save(&options)
# Parse the form for security options for the squid module
sub acl_security_save
{
foreach $a ('mgetty', 'options', 'dialin', 'secrets', 'sync') {
	$_[0]->{$a} = $in{$a};
	}
$_[0]->{'direct'} = $in{'direct'};
}

