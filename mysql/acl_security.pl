
require 'mysql-lib.pl';

# acl_security_form(&options)
# Output HTML for editing security options for the mysql module
sub acl_security_form
{
print "<tr> <td valign=top rowspan=3><b>$text{'acl_dbs'}</b></td>\n";
print "<td rowspan=3 valign=top>\n";
printf "<input type=radio name=dbs_def value=1 %s> %s\n",
	$_[0]->{'dbs'} eq '*' ? 'checked' : '', $text{'acl_dall'};
printf "<input type=radio name=dbs_def value=0 %s> %s<br>\n",
	$_[0]->{'dbs'} eq '*' ? '' : 'checked', $text{'acl_dsel'};
print "<select name=dbs size=3 multiple width=100>\n";
map { $dcan{$_}++ } split(/\s+/, $_[0]->{'dbs'});
foreach $d (&list_databases()) {
	printf "<option %s>%s</option>\n",
		$dcan{$d} ? 'selected' : '', $d;
	}
print "</select></td>\n";

print "<td><b>$text{'acl_delete'}</b></td> <td>\n";
printf "<input type=radio name=delete value=1 %s> %s\n",
	$_[0]->{'delete'} ? 'checked' : '', $text{'yes'};
printf "<input type=radio name=delete value=0 %s> %s</td> </tr>\n",
	$_[0]->{'delete'} ? '' : 'checked', $text{'no'};

print "<tr> <td><b>$text{'acl_stop'}</b></td> <td>\n";
printf "<input type=radio name=stop value=1 %s> %s\n",
	$_[0]->{'stop'} ? 'checked' : '', $text{'yes'};
printf "<input type=radio name=stop value=0 %s> %s</td> </tr>\n",
	$_[0]->{'stop'} ? '' : 'checked', $text{'no'};

print "<tr> <td><b>$text{'acl_edonly'}</b></td> <td>\n";
printf "<input type=radio name=edonly value=1 %s> %s\n",
	$_[0]->{'edonly'} ? 'checked' : '', $text{'yes'};
printf "<input type=radio name=edonly value=0 %s> %s</td> </tr>\n",
	$_[0]->{'edonly'} ? '' : 'checked', $text{'no'};

print "<tr> <td><b>$text{'acl_indexes'}</b></td>\n";
print "<td>",&ui_yesno_radio("indexes", $_[0]->{'indexes'}),"</td>\n";

print "<td><b>$text{'acl_views'}</b></td>\n";
print "<td>",&ui_yesno_radio("views", $_[0]->{'views'}),"</td> </tr>\n";

print "<tr> <td><b>$text{'acl_create'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=create value=1 %s> %s\n",
	$_[0]->{'create'} == 1 ? 'checked' : '', $text{'yes'};
printf "<input type=radio name=create value=2 %s> %s\n",
	$_[0]->{'create'} == 2 ? 'checked' : '', $text{'acl_max'};
printf "<input name=max size=5 value='%s'>\n",
	$_[0]->{'max'};
printf "<input type=radio name=create value=0 %s> %s</td> </tr>\n",
	$_[0]->{'create'} == 0 ? 'checked' : '', $text{'no'};

print "<tr> <td><b>$text{'acl_perms'}</b></td> <td colspan=3>\n";
printf "<input name=perms type=radio value=1 %s> %s\n",
	$_[0]->{'perms'} == 1 ? 'checked' : '', $text{'yes'};
printf "<input name=perms type=radio value=2 %s> %s\n",
	$_[0]->{'perms'} == 2 ? 'checked' : '', $text{'acl_only'};
printf "<input name=perms type=radio value=0 %s> %s\n",
	$_[0]->{'perms'} == 0 ? 'checked' : '', $text{'no'};
print "</td> </tr>\n";

print "<tr> <td valign=top><b>$text{'acl_login'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=user_def value=1 %s> %s<br>\n",
	$_[0]->{'user'} ? '' : 'checked', $text{'acl_user_def'};
printf "<input type=radio name=user_def value=0 %s>\n",
	$_[0]->{'user'} ? 'checked' : '';
printf "%s <input name=user size=10 value='%s'>\n",
	$text{'acl_user'}, $_[0]->{'user'};
printf "%s <input name=pass type=password size=10 value='%s'></td> </tr>\n",
	$text{'acl_pass'}, $_[0]->{'pass'};

print "<tr> <td><b>$text{'acl_buser'}</b></td>\n";
printf "<td colspan=3><input type=radio name=buser_def value=1 %s> %s\n",
	$_[0]->{'buser'} ? "" : "checked", $text{'acl_bnone'};
printf "<input type=radio name=buser_def value=0 %s>\n",
	$_[0]->{'buser'} ? "checked" : "";
printf "<input name=buser size=8 value='%s'> %s</td> </tr>\n",
	$_[0]->{'buser'}, &user_chooser_button("buser");

print "<tr> <td><b>$text{'acl_bpath'}</b></td>\n";
printf "<td colspan=3><input name=bpath size=40 value='%s'> %s</td> </tr>\n",
	$_[0]->{'bpath'}, &file_chooser_button("bpath", 1);

}

# acl_security_save(&options)
# Parse the form for security options for the mysql module
sub acl_security_save
{
if ($in{'dbs_def'}) {
	$_[0]->{'dbs'} = '*';
	}
else {
	$_[0]->{'dbs'} = join(" ", split(/\0/, $in{'dbs'}));
	}
$_[0]->{'create'} = $in{'create'};
$_[0]->{'indexes'} = $in{'indexes'};
$_[0]->{'views'} = $in{'views'};
$_[0]->{'max'} = $in{'max'};
$_[0]->{'delete'} = $in{'delete'};
$_[0]->{'bpath'} = $in{'bpath'};
$_[0]->{'buser'} = $in{'buser_def'} ? undef : $in{'buser'};
$_[0]->{'stop'} = $in{'stop'};
$_[0]->{'perms'} = $in{'perms'};
$_[0]->{'edonly'} = $in{'edonly'};
if ($in{'user_def'}) {
	delete($_[0]->{'user'});
	delete($_[0]->{'pass'});
	}
else {
	$_[0]->{'user'} = $in{'user'};
	$_[0]->{'pass'} = $in{'pass'};
	}
}

