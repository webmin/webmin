
do 'certmgr-lib.pl';

# acl_security_form(&options)
# Output HTML for editing security options for the acl module
sub acl_security_form
{
print "<tr> <td valign=top><b>$text{'acl_pages'}</b></td> <td colspan=3>\n";
foreach $p (@pages) {
	printf "<input type=checkbox name=%s value=1 %s> %s<br>\n",
		$p, $_[0]->{$p} ? "checked" : "", $text{'index_'.$p};
	}
print "</td> </tr>\n";
}

# acl_security_save(&options)
# Parse the form for security options for the acl module
sub acl_security_save
{
foreach $p (@pages) {
	$_[0]->{$p} = $in{$p};
	}
}

