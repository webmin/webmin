
do 'pserver-lib.pl';

# acl_security_form(&options)
# Output HTML for editing security options for the pserver module
sub acl_security_form
{
local $i = 0;
foreach $f (@features, 'setup', 'init') {
	print "<tr>\n" if ($i%2 == 0);
	print "<td><b>",$text{'acl_'.$f},"</b></td> <td>\n";
	printf "<input type=radio name=%s value=1 %s> $text{'yes'}\n",
		$f, $_[0]->{$f} ? 'checked' : '';
	printf "<input type=radio name=%s value=0 %s> $text{'no'}</td>\n",
		$f, $_[0]->{$f} ? '' : 'checked';
	print "</tr>\n" if ($i++%2 == 1);
	}
print "</tr>\n" if ($i%2 == 1);
}

# acl_security_save(&options)
# Parse the form for security options for the acl module
sub acl_security_save
{
foreach $f (@features, 'setup', 'init') {
	$_[0]->{$f} = $in{$f};
	}
}

