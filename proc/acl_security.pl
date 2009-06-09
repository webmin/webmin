
require 'proc-lib.pl';

# acl_security_form(&options)
# Output HTML for editing security options for the proc module
sub acl_security_form
{
# Run as user
print "<tr> <td><b>$text{'acl_manage'}</b></td> <td colspan=3>\n";
local $u = $_[0]->{'uid'} < 0 ? undef : getpwuid($_[0]->{'uid'});
printf "<input type=radio name=uid_def value=1 %s> %s\n",
	$_[0]->{'uid'} < 0 ? 'checked' : '', $text{'acl_manage_def'};
printf "<input type=radio name=uid_def value=0 %s>\n",
	$_[0]->{'uid'} < 0 ? '' : 'checked';
print "<input name=uid size=8 value='$u'> ",
	&user_chooser_button("uid", 0),"</td> </tr>\n";

# Who can be managed
if (!defined($_[0]->{'users'})) {
	$_[0]->{'users'} = $_[0]->{'uid'} < 0 ? "x" :
			   $_[0]->{'uid'} == 0 ? "*" : getpwuid($_[0]->{'uid'});
	}
local $who = $_[0]->{'users'} eq "x" ? 1 :
	     $_[0]->{'users'} eq "*" ? 0 : 2;
print "<tr> <td valign=top><b>$text{'acl_who'}</b></td> <td colspan=3>\n";
print &ui_radio("who", $who,
		[ [ 0, $text{'acl_who0'}."<br>\n" ],
		  [ 1, $text{'acl_who1'}."<br>\n" ],
		  [ 2, $text{'acl_who2'} ] ])." ".
		       &ui_textbox("users", $who == 2 ? $_[0]->{'users'} : "",
				   40),"</td> </tr>\n";

# Can do stuff to processes?
print "<tr> <td><b>$text{'acl_edit'}</b></td>\n";
printf "<td colspan=3><input type=radio name=edit value=1 %s> %s\n",
	$_[0]->{'edit'} ? 'checked' : '', $text{'yes'};
printf "<input type=radio name=edit value=0 %s> %s</td> </tr>\n",
	$_[0]->{'edit'} ? '' : 'checked', $text{'no'};

# Can run commands?
print "<tr> <td><b>$text{'acl_run'}</b></td>\n";
printf "<td colspan=3><input type=radio name=run value=1 %s> %s\n",
	$_[0]->{'run'} ? 'checked' : '', $text{'yes'};
printf "<input type=radio name=run value=0 %s> %s</td> </tr>\n",
	$_[0]->{'run'} ? '' : 'checked', $text{'no'};

# Can see other processes?
print "<tr> <td><b>$text{'acl_only'}</b></td>\n";
printf "<td colspan=3><input type=radio name=only value=1 %s> %s\n",
	$_[0]->{'only'} ? 'checked' : '', $text{'yes'};
printf "<input type=radio name=only value=0 %s> %s</td> </tr>\n",
	$_[0]->{'only'} ? '' : 'checked', $text{'no'};
}

# acl_security_save(&options)
# Parse the form for security options for the proc module
sub acl_security_save
{
$_[0]->{'uid'} = $in{'uid_def'} ? -1 : getpwnam($in{'uid'});
$_[0]->{'edit'} = $in{'edit'};
$_[0]->{'run'} = $in{'run'};
$_[0]->{'only'} = $in{'only'};
$_[0]->{'users'} = $in{'who'} == 0 ? "*" :
		   $in{'who'} == 1 ? "x" : $in{'users'};
}

