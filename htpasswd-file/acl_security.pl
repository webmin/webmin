
require 'htpasswd-file-lib.pl';

# acl_security_form(&options)
# Output HTML for editing security options for the passwd module
sub acl_security_form
{
print "<tr> <td><b>$text{'acl_repeat'}</b></td> <td>\n";
printf "<input type=radio name=repeat value=1 %s> $text{'yes'}\n",
	$_[0]->{'repeat'} ? "checked" : "";
printf "<input type=radio name=repeat value=0 %s> $text{'no'}</td>\n",
	$_[0]->{'repeat'} ? "" : "checked";

print "<td><b>$text{'acl_create'}</b></td> <td>\n";
printf "<input type=radio name=create value=1 %s> $text{'yes'}\n",
	$_[0]->{'create'} ? "checked" : "";
printf "<input type=radio name=create value=0 %s> $text{'no'}</td> </tr>\n",
	$_[0]->{'create'} ? "" : "checked";

print "<tr> <td><b>$text{'acl_rename'}</b></td> <td>\n";
printf "<input type=radio name=rename value=1 %s> $text{'yes'}\n",
	$_[0]->{'rename'} ? "checked" : "";
printf "<input type=radio name=rename value=0 %s> $text{'no'}</td>\n",
	$_[0]->{'rename'} ? "" : "checked";

print "<td><b>$text{'acl_delete'}</b></td> <td>\n";
printf "<input type=radio name=delete value=1 %s> $text{'yes'}\n",
	$_[0]->{'delete'} ? "checked" : "";
printf "<input type=radio name=delete value=0 %s> $text{'no'}</td> </tr>\n",
	$_[0]->{'delete'} ? "" : "checked";

print "<tr> <td><b>$text{'acl_enable'}</b></td> <td>\n";
printf "<input type=radio name=enable value=1 %s> $text{'yes'}\n",
	$_[0]->{'enable'} ? "checked" : "";
printf "<input type=radio name=enable value=0 %s> $text{'no'}</td>\n",
	$_[0]->{'enable'} ? "" : "checked";

print "<td><b>$text{'acl_sync'}</b></td> <td>\n";
printf "<input type=radio name=sync value=1 %s> $text{'yes'}\n",
	$_[0]->{'sync'} ? "checked" : "";
printf "<input type=radio name=sync value=0 %s> $text{'no'}</td> </tr>\n",
	$_[0]->{'sync'} ? "" : "checked";

print "<tr> <td><b>$text{'acl_single'}</b></td> <td>\n";
printf "<input type=radio name=single value=1 %s> $text{'yes'}\n",
	$_[0]->{'single'} ? "checked" : "";
printf "<input type=radio name=single value=0 %s> $text{'no'}</td>\n",
	$_[0]->{'single'} ? "" : "checked";

print "</tr>\n";
}

# acl_security_save(&options)
# Parse the form for security options for the bind8 module
sub acl_security_save
{
$_[0]->{'repeat'} = $in{'repeat'};
$_[0]->{'create'} = $in{'create'};
$_[0]->{'rename'} = $in{'rename'};
$_[0]->{'delete'} = $in{'delete'};
$_[0]->{'enable'} = $in{'enable'};
$_[0]->{'sync'} = $in{'sync'};
$_[0]->{'single'} = $in{'single'};
}

