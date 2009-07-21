
require 'init-lib.pl';

# acl_security_form(&options)
# Output HTML for editing security options for the init module
sub acl_security_form
{
if ($config{'local_script'}) {
	print "<tr> <td><b>$text{'acl_script'}</b></td> <td colspan=3>\n";
	}
else {
	print "<tr> <td><b>$text{'acl_actions'}</b></td> <td colspan=3>\n";
	}
printf "<input type=radio name=bootup value=1 %s> $text{'yes'}\n",
	$_[0]->{'bootup'} == 1 ? "checked" : "";
if (!$config{'local_script'}) {
	printf "<input type=radio name=bootup value=2 %s> $text{'acl_runonly'}\n",
		$_[0]->{'bootup'} == 2 ? "checked" : "";
	}
printf "<input type=radio name=bootup value=0 %s> $text{'no'}</td> </tr>\n",
	$_[0]->{'bootup'} == 0 ? "checked" : "";

print "<tr> <td><b>$text{'acl_reboot'}</b></td> <td>\n";
printf "<input type=radio name=reboot value=1 %s> $text{'yes'}\n",
	$_[0]->{'reboot'} ? "checked" : "";
printf "<input type=radio name=reboot value=0 %s> $text{'no'}</td>\n",
	$_[0]->{'reboot'} ? "" : "checked";

print "<td><b>$text{'acl_shutdown'}</b></td> <td>\n";
printf "<input type=radio name=shutdown value=1 %s> $text{'yes'}\n",
	$_[0]->{'shutdown'} ? "checked" : "";
printf "<input type=radio name=shutdown value=0 %s> $text{'no'}</td> </tr>\n",
	$_[0]->{'shutdown'} ? "" : "checked";
}

# acl_security_save(&options)
# Parse the form for security options for the init module
sub acl_security_save
{
$_[0]->{'bootup'} = $in{'bootup'};
$_[0]->{'reboot'} = $in{'reboot'};
$_[0]->{'shutdown'} = $in{'shutdown'};
}

