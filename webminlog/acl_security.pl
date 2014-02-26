
do 'webminlog-lib.pl';
&foreign_require("acl", "acl-lib.pl");

# acl_security_form(&options)
# Output HTML for editing security options for the acl module
sub acl_security_form
{
# Allowed modules
print "<tr> <td valign=top><b>$text{'acl_mods'}</b></td> <td>\n";
printf "<input type=radio name=mods_def value=1 %s> %s\n",
	$_[0]->{'mods'} eq "*" ? "checked" : "", $text{'acl_all'};
printf "<input type=radio name=mods_def value=0 %s> %s<br>\n",
	$_[0]->{'mods'} eq "*" ? "" : "checked", $text{'acl_sel'};
local %gotmod = map { $_, 1 } split(/\s+/, $_[0]->{'mods'});
print "<select name=mods multiple size=10 width=400>\n";
my $m;
foreach $m (sort { $a->{'desc'} cmp $b->{'desc'} } &get_all_module_infos()) {
	printf "<option value=%s %s>%s</option>\n",
		$m->{'dir'}, $gotmod{$m->{'dir'}} ? "selected" : "",
		$m->{'desc'};
	}
print "</select></td> </tr>\n";

# Allowed users
print "<tr> <td valign=top><b>$text{'acl_users'}</b></td> <td>\n";
printf "<input type=radio name=users_def value=1 %s> %s\n",
	$_[0]->{'users'} eq "*" ? "checked" : "", $text{'acl_all'};
printf "<input type=radio name=users_def value=0 %s> %s<br>\n",
	$_[0]->{'users'} eq "*" ? "" : "checked", $text{'acl_sel'};
local %gotuser = map { $_, 1 } split(/\s+/, $_[0]->{'users'});
print "<select name=users multiple size=10 width=400>\n";
my $u;
foreach $u (sort { $a->{'name'} cmp $b->{'name'} } &acl::list_users()) {
	printf "<option value=%s %s>%s</option>\n",
		$u->{'name'}, $gotuser{$u->{'name'}} ? "selected" : "",
		$u->{'name'};
	}
print "</select></td> </tr>\n";

# Rollback
print "<tr> <td><b>$text{'acl_rollback'}</b></td>\n";
print "<td>",&ui_radio("rollback", $_[0]->{'rollback'},
		[ [ 1, $text{'yes'} ], [ 0, $text{'no'} ] ]),"</td> </tr>\n";
}

# acl_security_save(&options)
# Parse the form for security options for the acl module
sub acl_security_save
{
$_[0]->{'mods'} = $in{'mods_def'} ? "*" : join(" ", split(/\0/, $in{'mods'}));
$_[0]->{'users'} = $in{'users_def'} ? "*" : join(" ", split(/\0/,$in{'users'}));
$_[0]->{'rollback'} = $in{'rollback'};
}

