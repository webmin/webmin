
require 'samba-lib.pl';

# acl_security_form(&options)
# Output HTML for editing security options for the samba module
sub acl_security_form
{
print "<tr>\n<td><b>$text{'acl_apply'}</b></td> <td>\n";
printf "<input type=radio name=apply value=1 %s> $text{'yes'}\n",
		$_[0]->{'apply'} ? "checked" : "";
printf "<input type=radio name=apply value=0 %s> $text{'no'}</td>\n",
		$_[0]->{'apply'} ? "" : "checked";
print "</tr>\n";

print "<tr>\n<td><b>$text{'acl_view_all_con'}</b></td> <td>\n";
printf "<input type=radio name=view_all_con value=1 %s> $text{'yes'}\n",
		$_[0]->{'view_all_con'} ? "checked" : "";
printf "<input type=radio name=view_all_con value=0 %s> $text{'no'}</td>\n",
		$_[0]->{'view_all_con'} ? "" : "checked";
print "</tr>\n";

print "<tr>\n<td><b>$text{'acl_kill_con'}</b></td> <td>\n";
printf "<input type=radio name=kill_con value=1 %s> $text{'yes'}\n",
		$_[0]->{'kill_con'} ? "checked" : "";
printf "<input type=radio name=kill_con value=0 %s> $text{'no'}</td>\n",
		$_[0]->{'kill_con'} ? "" : "checked";
print "</tr>\n";

print "<tr> <td colspan=4><hr></td> </tr>\n";

print "<tr>\n<td><b>$text{'acl_conf_net'}</b></td> <td>\n";
printf "<input type=radio name=conf_net value=1 %s> $text{'yes'}\n",
		$_[0]->{'conf_net'} ? "checked" : "";
printf "<input type=radio name=conf_net value=0 %s> $text{'no'}</td>\n",
		$_[0]->{'conf_net'} ? "" : "checked";
print "</tr>\n";

print "<tr>\n<td><b>$text{'acl_conf_smb'}</b></td> <td>\n";
printf "<input type=radio name=conf_smb value=1 %s> $text{'yes'}\n",
		$_[0]->{'conf_smb'} ? "checked" : "";
printf "<input type=radio name=conf_smb value=0 %s> $text{'no'}</td>\n",
		$_[0]->{'conf_smb'} ? "" : "checked";
print "</tr>\n";

print "<tr>\n<td><b>$text{'acl_conf_pass'}</b></td> <td>\n";
printf "<input type=radio name=conf_pass value=1 %s> $text{'yes'}\n",
		$_[0]->{'conf_pass'} ? "checked" : "";
printf "<input type=radio name=conf_pass value=0 %s> $text{'no'}</td>\n",
		$_[0]->{'conf_pass'} ? "" : "checked";
print "</tr>\n";

print "<tr>\n<td><b>$text{'acl_conf_print'}</b></td> <td>\n";
printf "<input type=radio name=conf_print value=1 %s> $text{'yes'}\n",
		$_[0]->{'conf_print'} ? "checked" : "";
printf "<input type=radio name=conf_print value=0 %s> $text{'no'}</td>\n",
		$_[0]->{'conf_print'} ? "" : "checked";
print "</tr>\n";

print "<tr>\n<td><b>$text{'acl_conf_misc'}</b></td> <td>\n";
printf "<input type=radio name=conf_misc value=1 %s> $text{'yes'}\n",
		$_[0]->{'conf_misc'} ? "checked" : "";
printf "<input type=radio name=conf_misc value=0 %s> $text{'no'}</td>\n",
		$_[0]->{'conf_misc'} ? "" : "checked";
print "</tr>\n";

print "<tr>\n<td><b>$text{'acl_swat'}</b></td> <td>\n";
printf "<input type=radio name=swat value=1 %s> $text{'yes'}\n",
		$_[0]->{'swat'} ? "checked" : "";
printf "<input type=radio name=swat value=0 %s> $text{'no'}</td>\n",
		$_[0]->{'swat'} ? "" : "checked";
print "</tr>\n";

print "<tr>\n<td><b>$text{'acl_manual'}</b></td> <td>\n";
printf "<input type=radio name=manual value=1 %s> $text{'yes'}\n",
		$_[0]->{'manual'} ? "checked" : "";
printf "<input type=radio name=manual value=0 %s> $text{'no'}</td>\n",
		$_[0]->{'manual'} ? "" : "checked";
print "</tr>\n";

print "<tr>\n<td><b>$text{'acl_winbind'}</b></td> <td>\n";
printf "<input type=radio name=winbind value=1 %s> $text{'yes'}\n",
		$_[0]->{'winbind'} ? "checked" : "";
printf "<input type=radio name=winbind value=0 %s> $text{'no'}</td>\n",
		$_[0]->{'winbind'} ? "" : "checked";
print "</tr>\n";

print "<tr>\n<td><b>$text{'acl_bind'}</b></td> <td>\n";
printf "<input type=radio name=conf_bind value=1 %s> $text{'yes'}\n",
                $_[0]->{'conf_bind'} ? "checked" : "";
printf "<input type=radio name=conf_bind value=0 %s> $text{'no'}</td>\n",
                $_[0]->{'conf_bind'} ? "" : "checked";
print "</tr>\n";

print "<tr> <td colspan=4><hr></td> </tr>\n";

# encripted passwords
print "<tr>\n<td $tb><b>$text{'acl_enc_passwd_opts'}</b></td></tr> \n";

print "<tr>\n<td><b>$text{'acl_view_users'}</b></td> <td>\n";
printf "<input type=radio name=view_users value=1 %s> $text{'yes'}\n",
		$_[0]->{'view_users'} ? "checked" : "";
printf "<input type=radio name=view_users value=0 %s> $text{'no'}</td>\n",
		$_[0]->{'view_users'} ? "" : "checked";
print "</tr>\n";

print "<tr>\n<td><b>$text{'acl_maint_users'}</b></td> <td>\n";
printf "<input type=radio name=maint_users value=1 %s> $text{'yes'}\n",
		$_[0]->{'maint_users'} ? "checked" : "";
printf "<input type=radio name=maint_users value=0 %s> $text{'no'}</td>\n",
		$_[0]->{'maint_users'} ? "" : "checked";
print "</tr>\n";

print "<tr>\n<td><b>$text{'acl_maint_makepass'}</b></td> <td>\n";
printf "<input type=radio name=maint_makepass value=1 %s> $text{'yes'}\n",
		$_[0]->{'maint_makepass'} ? "checked" : "";
printf "<input type=radio name=maint_makepass value=0 %s> $text{'no'}</td>\n",
		$_[0]->{'maint_makepass'} ? "" : "checked";
print "</tr>\n";

print "<tr>\n<td><b>$text{'acl_maint_sync'}</b></td> <td>\n";
printf "<input type=radio name=maint_sync value=1 %s> $text{'yes'}\n",
		$_[0]->{'maint_sync'} ? "checked" : "";
printf "<input type=radio name=maint_sync value=0 %s> $text{'no'}</td>\n",
		$_[0]->{'maint_sync'} ? "" : "checked";
print "</tr>\n";

print "<tr> <td colspan=4><hr></td> </tr>\n";

# encripted passwords
print "<tr>\n<td $tb><b>$text{'acl_group_opts'}</b></td></tr> \n";

print "<tr>\n<td><b>$text{'acl_maint_groups'}</b></td> <td>\n";
printf "<input type=radio name=maint_groups value=1 %s> $text{'yes'}\n",
		$_[0]->{'maint_groups'} ? "checked" : "";
printf "<input type=radio name=maint_groups value=0 %s> $text{'no'}</td>\n",
		$_[0]->{'maint_groups'} ? "" : "checked";
print "</tr>\n";

print "<tr>\n<td><b>$text{'acl_maint_gsync'}</b></td> <td>\n";
printf "<input type=radio name=maint_gsync value=1 %s> $text{'yes'}\n",
		$_[0]->{'maint_gsync'} ? "checked" : "";
printf "<input type=radio name=maint_gsync value=0 %s> $text{'no'}</td>\n",
		$_[0]->{'maint_gsync'} ? "" : "checked";
print "</tr>\n";

print "<tr> <td colspan=4><hr></td> </tr>\n";

# hide
print "<tr>\n<td><b>$text{'acl_hide'}</b></td> <td>\n";
printf "<input type=radio name=hide value=1 %s> $text{'yes'}\n",
		$_[0]->{'hide'} == 1 ? "checked" : "";
printf "<input type=radio name=hide value=0 %s> $text{'no'}</td>\n",
		$_[0]->{'hide'} == 0 ? "checked" : "";
print "</tr>\n";

print "<tr> <td colspan=4><hr></td> </tr>\n";

# global acls
print "<tr>\n<td><b>$text{'acl_afs'}</b></td>\n";
print "<td colspan=3>\n";
printf "<input type=checkbox name=c_fs value=1 %s> %s\n",
		$_[0]->{'c_fs'} ? "checked" : "", $text{"acl_c"};
printf "<input type=checkbox name=r_fs value=1 %s> %s\n",
		$_[0]->{'r_fs'} ? "checked" : "", $text{"acl_r"};
printf "<input type=checkbox name=w_fs value=1 %s> %s\n",
		$_[0]->{'w_fs'} ? "checked" : "", $text{"acl_w"};
print "</td> </tr>\n";

print "<tr>\n<td><b>$text{'acl_aps'}</b></td>\n";
print "<td colspan=3>\n";
printf "<input type=checkbox name=c_ps value=1 %s> %s\n",
		$_[0]->{'c_ps'} ? "checked" : "", $text{"acl_c"};
printf "<input type=checkbox name=r_ps value=1 %s> %s\n",
		$_[0]->{'r_ps'} ? "checked" : "", $text{"acl_r"};
printf "<input type=checkbox name=w_ps value=1 %s> %s\n",
		$_[0]->{'w_ps'} ? "checked" : "", $text{"acl_w"};
print "</td> </tr>\n";

print "<tr>\n<td><b>$text{'acl_copy'}</b></td> <td>\n";
printf "<input type=radio name=copy value=1 %s> $text{'yes'}\n",
		$_[0]->{'copy'} ? "checked" : "";
printf "<input type=radio name=copy value=0 %s> $text{'no'}</td>\n",
		$_[0]->{'copy'} ? "" : "checked";
print "</tr>\n";

print "<tr> <td colspan=4><hr></td> </tr>\n";

# per-share acls
print "<tr><td><b>$text{'acl_per_fs_acls'}</b></td> <td>\n";
printf "<input type=radio name=per_fs_acls value=1 %s> $text{'yes'}\n",
		$_[0]->{'per_fs_acls'} ? "checked" : "";
printf "<input type=radio name=per_fs_acls value=0 %s> $text{'no'}\n",
		$_[0]->{'per_fs_acls'} ? "" : "checked";
print "</td></tr>\n";

print "<tr><td><b>$text{'acl_per_ps_acls'}</b></td> <td>\n";
printf "<input type=radio name=per_ps_acls value=1 %s> $text{'yes'}\n",
		$_[0]->{'per_ps_acls'} ? "checked" : "";
printf "<input type=radio name=per_ps_acls value=0 %s> $text{'no'}\n",
		$_[0]->{'per_ps_acls'} ? "" : "checked";
print "</td></tr>\n";

print "<tr> <td colspan=4><hr></td> </tr>\n";

# table
print "<tr> <td colspan=4>\n<table border width=100%>\n";
printf "<th $tb colspan=7><b>%s</b></th>\n", $text{'acl_per_share_acls'};
print "<tr $tb>\n";
printf "<td rowspan=2><b>%s</b></td>\n", $text{'acl_sname'};
printf "<td rowspan=2><b>%s</b></td>\n", $text{'acl_saccess'};
printf "<td rowspan=2><b>%s</b></td>\n", $text{'acl_sconn'};
printf "<th colspan=4><b>%s</b></th>\n", $text{'acl_sopthdr'};
print "</tr>\n<tr $tb>\n";
printf "<td><b>%s</b></td>\n", $text{'acl_ssec'};
printf "<td><b>%s</b></td>\n", $text{'acl_sperm'};
printf "<td><b>%s</b></td>\n", $text{'acl_snaming'};
printf "<td><b>%s<br>%s</b></td>\n", $text{'acl_smisc'}, $text{'acl_sprn'};
print "</tr>\n";

foreach (&list_shares()) {
	&display_acl_row($_[0], $_);
	}
print "</table> </td> </tr>\n";
}

# acl_security_save(&options)
# Parse the form for security options for the samba module
sub acl_security_save
{
if ($in{'r_fs'} < $in{'w_fs'} || $in{'r_ps'} < $in{'w_ps'}) {
	&error($text{'acl_ernow'});
	}

# If create, read, AND write are all turned off... don't SHOW file shares...
$_[0]->{'conf_fs'}=1;
if ($in{'c_fs'} == "" && $in{'r_fs'} == "" && $in{'w_fs'} == "") {
        $_[0]->{'conf_fs'}=0;
        }
# If create, read, AND write are all turned off... don't SHOW print shares...
$_[0]->{'conf_ps'}=1;
if ($in{'c_ps'} == "" && $in{'r_ps'} == "" && $in{'w_ps'} == "") {
        $_[0]->{'conf_ps'}=0;
        }

$_[0]->{'apply'}=$in{'apply'};
$_[0]->{'view_all_con'}=$in{'view_all_con'};
$_[0]->{'kill_con'}=$in{'kill_con'};
$_[0]->{'conf_net'}=$in{'conf_net'};
$_[0]->{'conf_smb'}=$in{'conf_smb'};
$_[0]->{'conf_pass'}=$in{'conf_pass'};
$_[0]->{'conf_print'}=$in{'conf_print'};
$_[0]->{'conf_misc'}=$in{'conf_misc'};
$_[0]->{'swat'}=$in{'swat'};
$_[0]->{'manual'}=$in{'manual'};
$_[0]->{'hide'}=$in{'hide'};
$_[0]->{'per_fs_acls'}=$in{'per_fs_acls'};
$_[0]->{'per_ps_acls'}=$in{'per_ps_acls'};
$_[0]->{'c_fs'}=$in{'c_fs'};
$_[0]->{'r_fs'}=$in{'r_fs'};
$_[0]->{'w_fs'}=$in{'w_fs'};
$_[0]->{'c_ps'}=$in{'c_ps'};
$_[0]->{'r_ps'}=$in{'r_ps'};
$_[0]->{'w_ps'}=$in{'w_ps'};
$_[0]->{'copy'}=$in{'copy'};
$_[0]->{'view_users'}=$in{'view_users'};
$_[0]->{'maint_users'}=$in{'maint_users'};
$_[0]->{'maint_makepass'}=$in{'maint_makepass'};
$_[0]->{'maint_sync'}=$in{'maint_sync'};
$_[0]->{'maint_groups'}=$in{'maint_groups'};
$_[0]->{'maint_gsync'}=$in{'maint_gsync'};
$_[0]->{'winbind'}=$in{'winbind'};
$_[0]->{'conf_bind'}=$in{'conf_bind'};

foreach (keys %in) {
	  $_[0]->{$1} .= $in{$_} if /^\w\w_(ACL\w\w_\w+)$/;
	  }
}

# display_acl_row(\%access, $share_name)									
sub display_acl_row
{
local($acc,$name)=@_;
local %share;
&get_share($name);
local $stype=&istrue('printable') ? 'ps' : 'fs';
local $aclname='ACL' . $stype . '_' . $name;

#display row
print "<tr>\n";
printf $stype eq 'fs' ? "<td><b>%s</b></td>\n" : 
						"<td><b><i>%s</i></td>\n", $name;
&display_acl_cell($acc, $name, 'r', 'w', $aclname, 
				  $text{'acl_na'}, $text{'acl_r1'}, $text{'acl_rw'});
&display_acl_cell($acc, $name, 'v', 'V', $aclname, 
				  $text{'acl_na'}, $text{'acl_view'}, $text{'acl_kill'});
&display_acl_cell($acc, $name, 's', 'S', $aclname, 
				  $text{'acl_na'}, $text{'acl_view'}, $text{'acl_edit'});
$stype eq 'fs' ? &display_acl_cell($acc, $name, 'p', 'P', $aclname, 
				  $text{'acl_na'}, $text{'acl_view'}, $text{'acl_edit'}) : 
				  print "<td> </td>\n";
$stype eq 'fs' ? &display_acl_cell($acc, $name, 'n', 'N', $aclname, 
				$text{'acl_na'}, $text{'acl_view'}, $text{'acl_edit'}) :
				print "<td> </td>\n";
&display_acl_cell($acc, $name, 'o', 'O', $aclname, 
				  $text{'acl_na'}, $text{'acl_view'}, $text{'acl_edit'});
print "</tr>\n";		
}

#display_acl_cell(\%access, $name, 
#				  $rperm, $wperm, $aclname, 
#				  $text1, $text2, $text3)
sub display_acl_cell
{
local ($acc, $name, $rp, $wp, $aclname, $text1, $text2, $text3) = @_;
local $rn = $rp . $wp . '_' . $aclname;

print "<td>\n";
if($acc->{$aclname}) { 
	printf "<input type=radio name=$rn value='' %s> %s<br>\n",
			!&perm_to($rp, $acc, $aclname) ? 
				"checked" : "", $text1;
	printf "<input type=radio name=$rn value='$rp' %s> %s<br>\n",
			&perm_to($rp, $acc, $aclname) && 
			!&perm_to($rp.$wp, $acc, $aclname) ? 
				"checked" : "",$text2;
	printf "<input type=radio name=$rn value='$rp$wp' %s> %s\n",
			&perm_to($rp.$wp, $acc, $aclname) ? 
				"checked" : "", $text3;
	}
else {
	printf "<input type=radio name=$rn value='' checked> %s<br>\n",
			$text1;
	printf "<input type=radio name=$rn value='$rp'> %s<br>\n", 
			$text2;
	printf "<input type=radio name=$rn value='$rp$wp'> %s\n",
			$text3;
	}
print "</td>\n";
}

# perm_to($permissions_string,\%access,$ACLname)
# check only per-share permissions
sub perm_to
{
local $acl=$_[1]->{$_[2]};
foreach (split //,$_[0]) {
	return 0 if index($acl,$_) == -1;
	}
return 1;
}
		
1;
