
do 'web-lib.pl';
&init_config();
do 'ui-lib.pl';

# acl_security_form(&options)
# Output HTML for editing global security options
sub acl_security_form
{
local $o = $_[0];

# Root directory for file browser
print "<tr> <td><b>$text{'acl_root'}</b></td>\n";
printf "<td><input type=radio name=root_def value=1 %s> %s\n",
	$o->{'root'} ? '' : 'checked', $text{'acl_home'};
printf "<input type=radio name=root_def value=0 %s>\n",
	$o->{'root'} ? 'checked' : '';
print "<input name=root size=40 value='$o->{'root'}'> ",
      &file_chooser_button("root", 1),"</td> </tr>\n";

print &ui_table_row($text{'acl_otherdirs'},
	&ui_textarea("otherdirs", join("\n", split(/\t+/, $o->{'otherdirs'})),
		     5, 40), 3);

# Can see dot files?
print "<tr> <td><b>$text{'acl_nodot'}</b></td>\n";
print "<td>",&ui_yesno_radio("nodot", int($o->{'nodot'})),"</td> </tr>\n";

# Browse as Unix user
print "<tr> <td><b>$text{'acl_fileunix'}</b></td>\n";
print "<td>",&ui_opt_textbox("fileunix", $o->{'fileunix'}, 13,
			     $text{'acl_sameunix'})." ".
	     &user_chooser_button("fileunix"),"</td> </tr>\n";

print "<tr> <td colspan=2><hr></td> </tr>\n";

# Users visible in chooser
print "<tr> <td valign=top><b>$text{'acl_uedit'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=uedit_mode value=0 %s> $text{'acl_uedit_all'}\n",
	$o->{'uedit_mode'} == 0 ? "checked" : "";
printf "<input type=radio name=uedit_mode value=1 %s> $text{'acl_uedit_none'}<br>\n",
	$o->{'uedit_mode'} == 1 ? "checked" : "";
printf "<input type=radio name=uedit_mode value=2 %s> $text{'acl_uedit_only'}\n",
	$o->{'uedit_mode'} == 2 ? "checked" : "";
printf "<input name=uedit_can size=40 value='%s'> %s<br>\n",
	$o->{'uedit_mode'} == 2 ? $o->{'uedit'} : "",
	&user_chooser_button("uedit_can", 1);
printf "<input type=radio name=uedit_mode value=3 %s> $text{'acl_uedit_except'}\n",
	$o->{'uedit_mode'} == 3 ? "checked" : "";
printf "<input name=uedit_cannot size=40 value='%s'> %s<br>\n",
	$o->{'uedit_mode'} == 3 ? $o->{'uedit'} : "",
	&user_chooser_button("uedit_cannot", 1);
printf "<input type=radio name=uedit_mode value=4 %s> $text{'acl_uedit_uid'}\n",
	$o->{'uedit_mode'} == 4 ? "checked" : "";
printf "<input name=uedit_uid size=6 value='%s'> - \n",
	$o->{'uedit_mode'} == 4 ? $o->{'uedit'} : "";
printf "<input name=uedit_uid2 size=6 value='%s'><br>\n",
	$o->{'uedit_mode'} == 4 ? $o->{'uedit2'} : "";
printf "<input type=radio name=uedit_mode value=5 %s> $text{'acl_uedit_group'}\n",
	$o->{'uedit_mode'} == 5 ? "checked" : "";
printf "<input name=uedit_group size=8 value='%s'> %s</td> </tr>\n",
	$o->{'uedit_mode'} == 5 ? $dummy=getgrgid($o->{'uedit'}) : "",
	&group_chooser_button("uedit_group", 0);

# Groups visible in chooser
print "<tr> <td valign=top><b>$text{'acl_gedit'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=gedit_mode value=0 %s> $text{'acl_gedit_all'}\n",
	$o->{'gedit_mode'} == 0 ? "checked" : "";
printf "<input type=radio name=gedit_mode value=1 %s> $text{'acl_gedit_none'}<br>\n",
	$o->{'gedit_mode'} == 1 ? "checked" : "";
printf "<input type=radio name=gedit_mode value=2 %s> $text{'acl_gedit_only'}\n",
	$o->{'gedit_mode'} == 2 ? "checked" : "";
printf "<input name=gedit_can size=40 value='%s'> %s<br>\n",
	$o->{'gedit_mode'} == 2 ? $o->{'gedit'} : "",
	&group_chooser_button("gedit_can", 1);
printf "<input type=radio name=gedit_mode value=3 %s> $text{'acl_gedit_except'}\n",
	$o->{'gedit_mode'} == 3 ? "checked" : "";
printf "<input name=gedit_cannot size=40 value='%s'> %s<br>\n",
	$o->{'gedit_mode'} == 3 ? $o->{'gedit'} : "",
	&group_chooser_button("gedit_cannot", 1);
printf "<input type=radio name=gedit_mode value=4 %s> $text{'acl_gedit_gid'}\n",
	$o->{'gedit_mode'} == 4 ? "checked" : "";
printf "<input name=gedit_gid size=6 value='%s'> -\n",
	$o->{'gedit_mode'} == 4 ? $o->{'gedit'} : "";
printf "<input name=gedit_gid2 size=6 value='%s'></td> </tr>\n",
	$o->{'gedit_mode'} == 4 ? $o->{'gedit2'} : "";

print "<tr> <td colspan=2><hr></td> </tr>\n";

# Can submit feedback?
print "<tr> <td><b>$text{'acl_feedback'}</b></td> <td>\n";
printf "<input type=radio name=feedback value=2 %s> %s\n",
	$o->{'feedback'} == 2 ? "checked" : "", $text{'acl_feedback2'};
printf "<input type=radio name=feedback value=3 %s> %s\n",
	$o->{'feedback'} == 3 ? "checked" : "", $text{'acl_feedback3'};
printf "<input type=radio name=feedback value=1 %s> %s\n",
	$o->{'feedback'} == 1 ? "checked" : "", $text{'acl_feedback1'};
printf "<input type=radio name=feedback value=0 %s> %s</td> </tr>\n",
	$o->{'feedback'} == 0 ? "checked" : "", $text{'acl_feedback0'};

# Can accept RPC calls?
print "<tr> <td colspan=2><hr></td> </tr>\n";
print "<tr> <td><b>$text{'acl_rpc'}</b></td> <td>\n";
printf "<input type=radio name=rpc value=1 %s> %s\n",
	$o->{'rpc'} == 1 ? "checked" : "", $text{'acl_rpc1'};
if ($o->{'rpc'} == 2) {
	printf "<input type=radio name=rpc value=2 %s> %s\n",
		$o->{'rpc'} == 2 ? "checked" : "", $text{'acl_rpc2'};
	}
printf "<input type=radio name=rpc value=0 %s> %s</td> </tr>\n",
	$o->{'rpc'} == 0 ? "checked" : "", $text{'acl_rpc0'};

# Readonly mode
print "<tr> <td><b>$text{'acl_readonly'}</b></td>\n";
print "<td>",&ui_yesno_radio("readonly", $o->{'readonly'}),"</td> </tr>\n";
}

# acl_security_save(&options)
# Parse the form for global security options
sub acl_security_save
{
$_[0]->{'root'} = $in{'root_def'} ? undef : $in{'root'};
$_[0]->{'otherdirs'} = join("\t", split(/\r?\n/, $in{'otherdirs'}));
$_[0]->{'nodot'} = $in{'nodot'};

$_[0]->{'uedit_mode'} = $in{'uedit_mode'};
$_[0]->{'uedit'} = $in{'uedit_mode'} == 2 ? $in{'uedit_can'} :
		   $in{'uedit_mode'} == 3 ? $in{'uedit_cannot'} :
		   $in{'uedit_mode'} == 4 ? $in{'uedit_uid'} :
		   $in{'uedit_mode'} == 5 ? getgrnam($in{'uedit_group'}) : "";
$_[0]->{'uedit2'} = $in{'uedit_mode'} == 4 ? $in{'uedit_uid2'} : undef;

$_[0]->{'gedit_mode'} = $in{'gedit_mode'};
$_[0]->{'gedit'} = $in{'gedit_mode'} == 2 ? $in{'gedit_can'} :
		   $in{'gedit_mode'} == 3 ? $in{'gedit_cannot'} :
		   $in{'gedit_mode'} == 4 ? $in{'gedit_gid'} : "";
$_[0]->{'gedit2'} = $in{'gedit_mode'} == 4 ? $in{'gedit_gid2'} : undef;
$_[0]->{'feedback'} = $in{'feedback'};
$_[0]->{'rpc'} = $in{'rpc'};
$_[0]->{'readonly'} = $in{'readonly'};
$_[0]->{'fileunix'} = $in{'fileunix_def'} ? undef : $in{'fileunix'};
}

