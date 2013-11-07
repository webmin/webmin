
do 'acl-lib.pl';

# acl_security_form(&options)
# Output HTML for editing security options for the acl module
sub acl_security_form
{
my ($o) = @_;
print "<tr> <td valign=top><b>$text{'acl_users'}</b></td>\n";
print "<td valign=top>\n";
printf "<input type=radio name=users_def value=1 %s> %s\n",
	$o->{'users'} eq '*' ? 'checked' : '', $text{'acl_uall'};
printf "<input type=radio name=users_def value=2 %s> %s<br>\n",
	$o->{'users'} eq '~' ? 'checked' : '', $text{'acl_uthis'};
printf "<input type=radio name=users_def value=0 %s> %s<br>\n",
	$o->{'users'} eq '*' || $o->{'users'} eq '~' ? '' : 'checked',
	$text{'acl_usel'};
print "<select name=users multiple size=6 width=150>\n";
map { $ucan{$_}++ } split(/\s+/, $o->{'users'});
foreach $u (&list_users()) {
	printf "<option %s>%s\n",
		$ucan{$u->{'name'}} ? 'selected' : '',
		$u->{'name'},
		"</option>";
	}
foreach $g (&list_groups()) {
	printf "<option %s value=%s>%s\n",
		$ucan{'_'.$g->{'name'}} ? 'selected' : '',
		'_'.$g->{'name'}, &text('acl_gr', $g->{'name'}),
		"</option>";
	}
print "</select></td>\n";

print "<td valign=top><b>$text{'acl_mods'}</b></td> ",
      "<td valign=top>\n";
printf "<input type=radio name=mode value=0 %s> %s&nbsp;\n",
	$o->{'mode'} == 0 ? 'checked' : '', $text{'acl_all'};
printf "<input type=radio name=mode value=1 %s> %s<br>\n",
	$o->{'mode'} == 1 ? 'checked' : '', $text{'acl_own'};
printf "<input type=radio name=mode value=2 %s> %s<br>\n",
	$o->{'mode'} == 2 ? 'checked' : '', $text{'acl_sel'};
print "&nbsp;&nbsp;&nbsp;<select name=mods multiple size=6>\n";
map { $mcan{$_}++ } split(/\s+/, $o->{'mods'});
foreach $m (&list_module_infos()) {
	printf "<option value=%s %s>%s\n",
		$m->{'dir'}, $mcan{$m->{'dir'}} ? 'selected' :'',
		$m->{'desc'},
		"</option>";
	}
print "</select></td> </tr>\n";

print "<tr> <td><b>$text{'acl_create'}</b></td> <td>\n";
printf "<input type=radio name=create value=1 %s> $text{'yes'}\n",
	$o->{'create'} ? 'checked' : '';
printf "<input type=radio name=create value=0 %s> $text{'no'}</td>\n",
	$o->{'create'} ? '' : 'checked';

print "<td><b>$text{'acl_delete'}</b></td> <td>\n";
printf "<input type=radio name=delete value=1 %s> $text{'yes'}\n",
	$o->{'delete'} ? 'checked' : '';
printf "<input type=radio name=delete value=0 %s> $text{'no'}</td> </tr>\n",
	$o->{'delete'} ? '' : 'checked';

print "<tr> <td><b>$text{'acl_rename'}</b></td> <td>\n";
printf "<input type=radio name=rename value=1 %s> $text{'yes'}\n",
	$o->{'rename'} ? 'checked' : '';
printf "<input type=radio name=rename value=0 %s> $text{'no'}</td>\n",
	$o->{'rename'} ? '' : 'checked';

print "<td><b>$text{'acl_acl'}</b></td> <td>\n";
printf "<input type=radio name=acl value=1 %s> $text{'yes'}\n",
	$o->{'acl'} ? 'checked' : '';
printf "<input type=radio name=acl value=0 %s> $text{'no'}</td> </tr>\n",
	$o->{'acl'} ? '' : 'checked';

print "<tr> <td><b>$text{'acl_cert'}</b></td> <td>\n";
printf "<input type=radio name=cert value=1 %s> $text{'yes'}\n",
	$o->{'cert'} ? 'checked' : '';
printf "<input type=radio name=cert value=0 %s> $text{'no'}</td>\n",
	$o->{'cert'} ? '' : 'checked';

print "<td><b>$text{'acl_others'}</b></td> <td>\n";
printf "<input type=radio name=others value=1 %s> $text{'yes'}\n",
	$o->{'others'} ? 'checked' : '';
printf "<input type=radio name=others value=0 %s> $text{'no'}</td> </tr>\n",
	$o->{'others'} ? '' : 'checked';

print "<tr> <td><b>$text{'acl_chcert'}</b></td> <td>\n";
printf "<input type=radio name=chcert value=1 %s> $text{'yes'}\n",
	$o->{'chcert'} ? 'checked' : '';
printf "<input type=radio name=chcert value=0 %s> $text{'no'}</td>\n",
	$o->{'chcert'} ? '' : 'checked';

print "<td><b>$text{'acl_lang'}</b></td> <td>\n";
printf "<input type=radio name=lang value=1 %s> $text{'yes'}\n",
	$o->{'lang'} ? 'checked' : '';
printf "<input type=radio name=lang value=0 %s> $text{'no'}</td> </tr>\n",
	$o->{'lang'} ? '' : 'checked';

print "<tr> <td><b>$text{'acl_cats'}</b></td> <td>\n";
printf "<input type=radio name=cats value=1 %s> $text{'yes'}\n",
	$o->{'cats'} ? 'checked' : '';
printf "<input type=radio name=cats value=0 %s> $text{'no'}</td>\n",
	$o->{'cats'} ? '' : 'checked';

print "<td><b>$text{'acl_theme'}</b></td> <td>\n";
printf "<input type=radio name=theme value=1 %s> $text{'yes'}\n",
	$o->{'theme'} ? 'checked' : '';
printf "<input type=radio name=theme value=0 %s> $text{'no'}</td> </tr>\n",
	$o->{'theme'} ? '' : 'checked';

print "<tr> <td><b>$text{'acl_ips'}</b></td> <td>\n";
printf "<input type=radio name=ips value=1 %s> $text{'yes'}\n",
	$o->{'ips'} ? 'checked' : '';
printf "<input type=radio name=ips value=0 %s> $text{'no'}</td>\n",
	$o->{'ips'} ? '' : 'checked';

print "<tr> <td><b>$text{'acl_perms'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=perms value=1 %s> $text{'acl_perms_1'}\n",
	$o->{'perms'} ? 'checked' : '';
printf "<input type=radio name=perms value=0 %s> $text{'acl_perms_0'}</td>\n",
	$o->{'perms'} ? '' : 'checked';
print "</tr>\n";

print "<tr> <td><b>$text{'acl_sync'}</b></td> <td>\n";
printf "<input type=radio name=sync value=1 %s> $text{'yes'}\n",
	$o->{'sync'} ? 'checked' : '';
printf "<input type=radio name=sync value=0 %s> $text{'no'}</td>\n",
	$o->{'sync'} ? '' : 'checked';

print "<td><b>$text{'acl_unix'}</b></td> <td>\n";
printf "<input type=radio name=unix value=1 %s> $text{'yes'}\n",
	$o->{'unix'} ? 'checked' : '';
printf "<input type=radio name=unix value=0 %s> $text{'no'}</td> </tr>\n",
	$o->{'unix'} ? '' : 'checked';

print "<tr> <td><b>$text{'acl_sessions'}</b></td> <td>\n";
printf "<input type=radio name=sessions value=1 %s> $text{'yes'}\n",
	$o->{'sessions'} ? 'checked' : '';
printf "<input type=radio name=sessions value=0 %s> $text{'no'}</td>\n",
	$o->{'sessions'} ? '' : 'checked';

print "<td><b>$text{'acl_switch'}</b></td> <td>\n";
printf "<input type=radio name=switch value=1 %s> $text{'yes'}\n",
	$o->{'switch'} ? 'checked' : '';
printf "<input type=radio name=switch value=0 %s> $text{'no'}</td> </tr>\n",
	$o->{'switch'} ? '' : 'checked';

print "<tr> <td><b>$text{'acl_times'}</b></td> <td>\n";
printf "<input type=radio name=times value=1 %s> $text{'yes'}\n",
	$o->{'times'} ? 'checked' : '';
printf "<input type=radio name=times value=0 %s> $text{'no'}</td>\n",
	$o->{'times'} ? '' : 'checked';

print "<td><b>$text{'acl_pass'}</b></td> <td>\n";
printf "<input type=radio name=pass value=1 %s> $text{'yes'}\n",
	$o->{'pass'} ? 'checked' : '';
printf "<input type=radio name=pass value=0 %s> $text{'no'}</td> </tr>\n",
	$o->{'pass'} ? '' : 'checked';

print "<tr> <td><b>$text{'acl_sqls'}</b></td> <td>\n";
printf "<input type=radio name=sqls value=1 %s> $text{'yes'}\n",
	$o->{'sqls'} ? 'checked' : '';
printf "<input type=radio name=sqls value=0 %s> $text{'no'}</td>\n",
	$o->{'sqls'} ? '' : 'checked';

print "</tr>\n";

print "<tr> <td colspan=4><hr></td> </tr>\n";

print "<tr> <td valign=top><b>$text{'acl_groups'}</b></td> <td valign=top>\n";
printf "<input type=radio name=groups value=1 %s> $text{'yes'}\n",
	$o->{'groups'} == 1 ? 'checked' : '';
printf "<input type=radio name=groups value=0 %s> $text{'no'}</td>\n",
	$o->{'groups'} == 0 ? 'checked' : '';

print "<td valign=top><b>$text{'acl_gassign'}</b></td> <td>\n";
printf "<input type=radio name=gassign_def value=1 %s> %s\n",
	$o->{'gassign'} eq '*' ? 'checked' : '', $text{'acl_gall'};
printf "<input type=radio name=gassign_def value=0 %s> %s<br>\n",
	$o->{'gassign'} eq '*' ? '' : 'checked', $text{'acl_gsel'};
print "<select name=gassign multiple size=3 width=150>\n";
map { $gcan{$_}++ } split(/\s+/, $o->{'gassign'});
printf "<option value=_none %s>&lt;%s&gt;\n",
	$gcan{'_none'} ? 'selected' : '', $text{'acl_gnone'},
	"</option>";
foreach $g (&list_groups()) {
	printf "<option %s>%s\n",
		$gcan{$g->{'name'}} ? 'selected' : '', $g->{'name'},
		"</option>";
	}
print "</select></td> </tr>\n";
}

# acl_security_save(&options)
# Parse the form for security options for the acl module
sub acl_security_save
{
if ($in{'users_def'} == 1) {
	$_[0]->{'users'} = '*';
	}
elsif ($in{'users_def'} == 2) {
	$_[0]->{'users'} = '~';
	}
else {
	$_[0]->{'users'} = join(" ", split(/\0/, $in{'users'}));
	}
$_[0]->{'mode'} = $in{'mode'};
$_[0]->{'mods'} = $in{'mode'} == 2 ? join(" ", split(/\0/, $in{'mods'}))
				   : undef;
$_[0]->{'create'} = $in{'create'};
$_[0]->{'groups'} = $in{'groups'};
$_[0]->{'delete'} = $in{'delete'};
$_[0]->{'rename'} = $in{'rename'};
$_[0]->{'acl'} = $in{'acl'};
$_[0]->{'others'} = $in{'others'};
$_[0]->{'cert'} = $in{'cert'};
$_[0]->{'chcert'} = $in{'chcert'};
$_[0]->{'lang'} = $in{'lang'};
$_[0]->{'perms'} = $in{'perms'};
$_[0]->{'gassign'} = $in{'gassign_def'} ? '*' :
		     join(" ", split(/\0/, $in{'gassign'}));
$_[0]->{'sync'} = $in{'sync'};
$_[0]->{'unix'} = $in{'unix'};
$_[0]->{'switch'} = $in{'switch'};
$_[0]->{'sessions'} = $in{'sessions'};
$_[0]->{'cats'} = $in{'cats'};
$_[0]->{'theme'} = $in{'theme'};
$_[0]->{'ips'} = $in{'ips'};
$_[0]->{'times'} = $in{'times'};
$_[0]->{'pass'} = $in{'pass'};
$_[0]->{'sql'} = $in{'sql'};
}

