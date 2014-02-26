
require 'apache-lib.pl';

# acl_security_form(&options)
# Output HTML for editing security options for the apache module
sub acl_security_form
{
print "<tr> <td valign=top rowspan=4><b>$text{'acl_virts'}</b></td>\n";
print "<td rowspan=4 valign=top>\n";
printf "<input type=radio name=virts_def value=1 %s> %s\n",
	$_[0]->{'virts'} eq '*' ? 'checked' : '', $text{'acl_vall'};
printf "<input type=radio name=virts_def value=0 %s> %s<br>\n",
	$_[0]->{'virts'} eq '*' ? '' : 'checked', $text{'acl_vsel'};
print "<select name=virts multiple size=5>\n";
local $conf = &get_config();
local @virts = ( { 'value' => '__default__' },
		 &find_directive_struct("VirtualHost", $conf) );
local %vcan = map { $_, 1 } split(/\s+/, $_[0]->{'virts'});
local $v;
foreach $v (@virts) {
	local @vn = &virt_acl_name($v);
	local ($can) = grep { $vcan{$_} } @vn;
	local $vn = $can || $vn[0];
	printf "<option value=\"%s\" %s>%s</option>\n",
		$vn, $can ? "selected" : "",
		$vn eq "__default__" ? $text{'acl_defserv'} : $vn;
	delete($vcan{$can}) if ($can);
	}
foreach $vn (keys %vcan) {
	next if ($vn eq "*");
	printf "<option value=\"%s\" %s>%s</option>\n",
		$vn, "selected",
		$vn eq "__default__" ? $text{'acl_defserv'} : $vn;
	}
print "</select></td>\n";

print "<td><b>$text{'acl_global'}</b></td> <td><select name=global>\n";
printf "<option value=1 %s>$text{'yes'}</option>\n",
	$_[0]->{'global'} == 1 ? "selected" : "";
printf "<option value=2 %s>$text{'acl_htaccess'}</option>\n",
	$_[0]->{'global'} == 2 ? "selected" : "";
printf "<option value=0 %s>$text{'no'}</option></select></td> </tr>\n",
	$_[0]->{'global'} == 0 ? "selected" : "";

print "<tr> <td><b>$text{'acl_create'}</b></td> <td>\n";
printf "<input type=radio name=create value=1 %s> $text{'yes'}\n",
	$_[0]->{'create'} ? "checked" : "";
printf "<input type=radio name=create value=0 %s> $text{'no'}</td> </tr>\n",
	$_[0]->{'create'} ? "" : "checked";

print "<tr> <td><b>$text{'acl_vuser'}</b></td> <td>\n";
printf "<input type=radio name=vuser value=1 %s> $text{'yes'}\n",
	$_[0]->{'vuser'} ? "checked" : "";
printf "<input type=radio name=vuser value=0 %s> $text{'no'}</td> </tr>\n",
	$_[0]->{'vuser'} ? "" : "checked";

print "<tr> <td><b>$text{'acl_vaddr'}</b></td> <td>\n";
printf "<input type=radio name=vaddr value=1 %s> $text{'yes'}\n",
	$_[0]->{'vaddr'} ? "checked" : "";
printf "<input type=radio name=vaddr value=0 %s> $text{'no'}</td> </tr>\n",
	$_[0]->{'vaddr'} ? "" : "checked";

print "<tr> <td><b>$text{'acl_pipe'}</b></td> <td>\n";
printf "<input type=radio name=pipe value=1 %s> $text{'yes'}\n",
	$_[0]->{'pipe'} ? "checked" : "";
printf "<input type=radio name=pipe value=0 %s> $text{'no'}</td>\n",
	$_[0]->{'pipe'} ? "" : "checked";

print "<td><b>$text{'acl_stop'}</b></td> <td>\n";
printf "<input type=radio name=stop value=1 %s> $text{'yes'}\n",
	$_[0]->{'stop'} ? "checked" : "";
printf "<input type=radio name=stop value=0 %s> $text{'no'}</td> </tr>\n",
	$_[0]->{'stop'} ? "" : "checked";

print "<tr> <td><b>$text{'acl_apply'}</b></td> <td>\n";
printf "<input type=radio name=apply value=1 %s> $text{'yes'}\n",
	$_[0]->{'apply'} ? "checked" : "";
printf "<input type=radio name=apply value=0 %s> $text{'no'}</td>\n",
	$_[0]->{'apply'} ? "" : "checked";

print "<td><b>$text{'acl_names'}</b></td> <td>\n";
printf "<input type=radio name=names value=1 %s> $text{'yes'}\n",
	$_[0]->{'names'} ? "checked" : "";
printf "<input type=radio name=names value=0 %s> $text{'no'}</td> </tr>\n",
	$_[0]->{'names'} ? "" : "checked";

print "<tr> <td><b>$text{'acl_dir'}</b></td>\n";
printf "<td colspan=3><input name=dir size=30 value='%s'> %s</td> </tr>\n",
	$_[0]->{'dir'}, &file_chooser_button("dir", 1);

print "<tr> <td><b>$text{'acl_aliasdir'}</b></td>\n";
printf "<td colspan=3><input name=aliasdir size=30 value='%s'> %s</td> </tr>\n",
	$_[0]->{'aliasdir'}, &file_chooser_button("aliasdir", 1);

print "<tr> <td valign=top><b>$text{'acl_types'}</b></td>\n";
print "<td colspan=3>\n";
printf "<input type=radio name=types_def value=1 %s> $text{'acl_all'}&nbsp;\n",
	$_[0]->{'types'} eq '*' ? "checked" : "";
printf "<input type=radio name=types_def value=0 %s> $text{'acl_sel'}<br>\n",
	$_[0]->{'types'} eq '*' ? "" : "checked";
map { $types{$_}++ } split(/\s+/, $_[0]->{'types'});
print "<select name=types size=5 multiple>\n";
for($i=0; $text{"type_$i"}; $i++) {
	printf "<option value=\"%d\" %s>%s</option>\n",
		$i, $types{$i} ? "selected" : "", $text{"type_$i"};
	}
print "</select></td> </tr>\n";

print "<tr> <td valign=top><b>$text{'acl_dirs'}</b></td>\n";
print "<td colspan=3>\n";
print &ui_radio("dirsmode", $_[0]->{'dirsmode'},
		[ [ 0, $text{'acl_dirs0'} ],
		  [ 1, $text{'acl_dirs1'} ],
		  [ 2, $text{'acl_dirs2'} ] ]),"<br>\n";
print &ui_textarea("dirs", join("\n", split(/\s+/, $_[0]->{'dirs'})), 5, 50);
print "</td> </tr>\n";
}

# acl_security_save(&options)
# Parse the form for security options for the apache module
sub acl_security_save
{
if ($in{'virts_def'}) {
	$_[0]->{'virts'} = "*";
	}
else {
	$_[0]->{'virts'} = join(" ", split(/\0/, $in{'virts'}));
	}
$_[0]->{'global'} = $in{'global'};
$_[0]->{'create'} = $in{'create'};
$_[0]->{'vuser'} = $in{'vuser'};
$_[0]->{'stop'} = $in{'stop'};
$_[0]->{'apply'} = $in{'apply'};
$_[0]->{'vaddr'} = $in{'vaddr'};
$_[0]->{'dir'} = $in{'dir'};
$_[0]->{'aliasdir'} = $in{'aliasdir'};
$_[0]->{'types'} = $in{'types_def'} ? '*'
				    : join(" ", split(/\0/, $in{'types'}));
$_[0]->{'pipe'} = $in{'pipe'};
$_[0]->{'names'} = $in{'names'};
$_[0]->{'dirsmode'} = $in{'dirsmode'};
$_[0]->{'dirs'} = join(" ", split(/\s+/, $in{'dirs'}));
}

