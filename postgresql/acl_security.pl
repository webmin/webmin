
require 'postgresql-lib.pl';

# acl_security_form(&options)
# Output HTML for editing security options for the postgresql module
sub acl_security_form
{
my (@listdb)=&list_databases();
print "<tr> <td valign=top rowspan=4><b>$text{'acl_dbs'}</b>\n";
print "<br>$text{'acl_dbscannot'}" unless @listdb;
print "</td>\n";
print "<td rowspan=4 valign=top>\n";
if (@listdb) {
	printf "<input type=radio name=dbs_def value=1 %s> %s\n",
		$_[0]->{'dbs'} eq '*' ? 'checked' : '', $text{'acl_dall'};
	printf "<input type=radio name=dbs_def value=0 %s> %s<br>\n",
		$_[0]->{'dbs'} eq '*' ? '' : 'checked', $text{'acl_dsel'};
	print "<select name=dbs size=5 multiple width=100>\n";
		map { $dcan{$_}++ } split(/\s+/, $_[0]->{'dbs'});
	foreach $d (@listdb) {
		printf "<option %s>%s</option>\n",
			$dcan{$d} ? 'selected' : '', $d;
		}
	print "</select>";
	print "<input type=hidden name=dblist value=\"1\">\n";
	} 
else {
	print "<input type=hidden name=dblist value=\"0 ".$_[0]->{'dbs'}."\">\n";
	}
print "</td>\n";

print "<td><b>$text{'acl_create'}</b></td> <td>\n";
printf "<input type=radio name=create value=1 %s> %s\n",
	$_[0]->{'create'} == 1 ? 'checked' : '', $text{'yes'};
printf "<input type=radio name=create value=2 %s> %s\n",
	$_[0]->{'create'} == 2 ? 'checked' : '', $text{'acl_max'};
printf "<input name=max size=5 value='%s'>\n",
	$_[0]->{'max'};
printf "<input type=radio name=create value=0 %s> %s</td> </tr>\n",
	$_[0]->{'create'} == 0 ? 'checked' : '', $text{'no'};

print "<tr> <td><b>$text{'acl_delete'}</b></td> <td>\n";
printf "<input type=radio name=delete value=1 %s> %s\n",
	$_[0]->{'delete'} ? 'checked' : '', $text{'yes'};
printf "<input type=radio name=delete value=0 %s> %s</td> </tr>\n",
	$_[0]->{'delete'} ? '' : 'checked', $text{'no'};

print "<tr> <td><b>$text{'acl_stop'}</b></td> <td>\n";
printf "<input type=radio name=stop value=1 %s> %s\n",
	$_[0]->{'stop'} ? 'checked' : '', $text{'yes'};
printf "<input type=radio name=stop value=0 %s> %s</td> </tr>\n",
	$_[0]->{'stop'} ? '' : 'checked', $text{'no'};

print "<tr> <td><b>$text{'acl_users'}</b></td> <td>\n";
printf "<input type=radio name=users value=1 %s> %s\n",
	$_[0]->{'users'} ? 'checked' : '', $text{'yes'};
printf "<input type=radio name=users value=0 %s> %s</td> </tr>\n",
	$_[0]->{'users'} ? '' : 'checked', $text{'no'};

print "<tr> <td valign=top><b>$text{'acl_login'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=user_def value=1 %s> %s<br>\n",
	$_[0]->{'user'} ? '' : 'checked', $text{'acl_user_def'};
printf "<input type=radio name=user_def value=0 %s>\n",
	$_[0]->{'user'} ? 'checked' : '';
printf "%s <input name=user size=10 value='%s'>\n",
	$text{'acl_user'}, $_[0]->{'user'};
printf "%s <input name=pass type=password size=10 value='%s'><br>\n",
	$text{'acl_pass'}, $_[0]->{'pass'};
print "&nbsp;&nbsp;&nbsp;\n";
printf "<input type=checkbox name=sameunix value=1 %s> %s</td> </tr>\n",
	$_[0]->{'sameunix'} ? "checked" : "", $text{'acl_sameunix'};

print "<tr> <td><b>$text{'acl_backup'}</b></td> <td>\n";
printf "<input type=radio name=backup value=1 %s> %s\n",
	$_[0]->{'backup'} ? 'checked' : '', $text{'yes'};
printf "<input type=radio name=backup value=0 %s> %s</td>\n",
	$_[0]->{'backup'} ? '' : 'checked', $text{'no'};

print "<td><b>$text{'acl_restore'}</b></td> <td>\n";
printf "<input type=radio name=restore value=1 %s> %s\n",
	$_[0]->{'restore'} ? 'checked' : '', $text{'yes'};
printf "<input type=radio name=restore value=0 %s> %s</td> </tr>\n",
	$_[0]->{'restore'} ? '' : 'checked', $text{'no'};

print "<tr> <td valign=top><b>$text{'acl_cmds'}</b></td> <td>\n";
printf "<input type=radio name=cmds value=1 %s> %s\n",
        $_[0]->{'cmds'} ? "checked" : "", $text{'yes'};
printf "<input type=radio name=cmds value=0 %s> %s</td>\n",
        $_[0]->{'cmds'} ? "" : "checked", $text{'no'};

print "<td><b>$text{'acl_views'}</b></td> <td>\n";
printf "<input type=radio name=views value=1 %s> %s\n",
	$_[0]->{'views'} ? 'checked' : '', $text{'yes'};
printf "<input type=radio name=views value=0 %s> %s</td> </tr>\n",
	$_[0]->{'views'} ? '' : 'checked', $text{'no'};

print "<tr> <td valign=top><b>$text{'acl_indexes'}</b></td> <td>\n";
printf "<input type=radio name=indexes value=1 %s> %s\n",
        $_[0]->{'indexes'} ? "checked" : "", $text{'yes'};
printf "<input type=radio name=indexes value=0 %s> %s</td>\n",
        $_[0]->{'indexes'} ? "" : "checked", $text{'no'};

print "<td><b>$text{'acl_seqs'}</b></td> <td>\n";
printf "<input type=radio name=seqs value=1 %s> %s\n",
	$_[0]->{'seqs'} ? 'checked' : '', $text{'yes'};
printf "<input type=radio name=seqs value=0 %s> %s</td> </tr>\n",
	$_[0]->{'seqs'} ? '' : 'checked', $text{'no'};

print "</tr>\n";
}

# acl_security_save(&options)
# Parse the form for security options for the postgresql module
sub acl_security_save
{
if ($in{'dblist'} eq '1') {
	if ($in{'dbs_def'}) {
		$_[0]->{'dbs'} = '*';
		}
	else {
		$_[0]->{'dbs'} = join(" ", split(/\0/, $in{'dbs'}));
		}
	} 
else {
	$_[0]->{'dbs'} = $in{'dblist'};
	$_[0]->{'dbs'} =~ s/^0 //;
	}
$_[0]->{'create'} = $in{'create'};
$_[0]->{'max'} = $in{'max'};
$_[0]->{'delete'} = $in{'delete'};
$_[0]->{'stop'} = $in{'stop'};
$_[0]->{'users'} = $in{'users'};
$_[0]->{'backup'} = $in{'backup'};
$_[0]->{'restore'} = $in{'restore'};
$_[0]->{'cmds'} = $in{'cmds'};
$_[0]->{'views'} = $in{'views'};
$_[0]->{'indexes'} = $in{'indexes'};
$_[0]->{'seqs'} = $in{'seqs'};
if ($in{'user_def'}) {
	delete($_[0]->{'user'});
	delete($_[0]->{'pass'});
	}
else {
	$_[0]->{'user'} = $in{'user'};
	$_[0]->{'pass'} = $in{'pass'};
	}
$_[0]->{'sameunix'} = $in{'sameunix'};
}

