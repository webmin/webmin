
require 'usermin-lib.pl';

# acl_security_form(&options)
# Output HTML for editing security options for the usermin module
sub acl_security_form
{
print "<tr> <td valign=top><b>$text{'acl_icons'}</b></td>\n";
print "<td colspan=3><select name=icons multiple size=10>\n";
foreach $i (&get_icons()) {
	printf "<option value=%s %s>%s</option>\n",
		$i, $_[0]->{$i} ? "selected" : "", $text{"${i}_title"};
	}
print "</select></td> </tr>\n";

print "<tr> <td valign=top><b>$text{'acl_mods'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=mods_def value=1 %s> %s\n",
	$_[0]->{'mods'} eq '*' ? 'checked' : '', $text{'acl_all'};
printf "<input type=radio name=mods_def value=0 %s> %s<br>\n",
	$_[0]->{'mods'} eq '*' ? '' : 'checked', $text{'acl_sel'};
local %mods = map { $_, 1 } split(/\s+/, $_[0]->{'mods'});
print "<select name=mods multiple size=10>\n";
foreach $m (&list_modules()) {
	printf "<option value=%s %s>%s</option>\n",
		$m->{'dir'}, $mods{$m->{'dir'}} ? "selected" : "", $m->{'desc'};
	}
print "</select></td> </tr>\n";

print "<tr> <td><b>$text{'acl_stop'}</b></td>\n";
printf "<td><input type=radio name=stop value=1 %s> %s\n",
	$_[0]->{'stop'} ? "checked" : "", $text{'yes'};
printf "<input type=radio name=stop value=0 %s> %s</td>\n",
	$_[0]->{'stop'} ? "" : "checked", $text{'no'};

print "<td><b>$text{'acl_bootup'}</b></td>\n";
printf "<td><input type=radio name=bootup value=1 %s> %s\n",
	$_[0]->{'bootup'} ? "checked" : "", $text{'yes'};
printf "<input type=radio name=bootup value=0 %s> %s</td> </tr>\n",
	$_[0]->{'bootup'} ? "" : "checked", $text{'no'};
}

# acl_security_save(&options)
# Parse the form for security options for the usermin module
sub acl_security_save
{
local %icons = map { $_, 1 } split(/\0/, $in{'icons'});
foreach $i (&get_icons()) {
	$_[0]->{$i} = $icons{$i};
	}
$_[0]->{'mods'} = $in{'mods_def'} ? "*" : join(" ", split(/\0/, $in{'mods'}));
$_[0]->{'stop'} = $in{'stop'};
$_[0]->{'bootup'} = $in{'bootup'};
}

sub get_icons
{
return ( "access" ,"bind" ,"ui" ,"umods" ,"os" ,"lang" ,"upgrade" ,"session" ,"assignment" ,"categories" ,"themes", "referers", "anon", "ssl" ,"configs" ,"acl" ,"restrict" ,"users" ,"defacl", "sessions", "blocked", "advanced" );
}

