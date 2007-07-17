#!/usr/local/bin/perl
# edit_group.cgi
# Display a form for editing or creating a group

require './ldap-useradmin-lib.pl';
&ReadParse();
$ldap = &ldap_connect();
if ($in{'new'}) {
	$access{'gcreate'} || &error($text{'gedit_ecreate'});
	&ui_print_header(undef, $text{'gedit_title2'}, "");
	}
else {
	$rv = $ldap->search(base => $in{'dn'},
			    scope => 'base',
			    filter => '(objectClass=posixGroup)');
	($ginfo) = $rv->all_entries;
	$group = $ginfo->get_value('cn');
	$gid = $ginfo->get_value('gidNumber');
	$pass = $ginfo->get_value('userPassword');
	@members = $ginfo->get_value('memberUid');
	foreach $oc ($ginfo->get_value('objectClass')) {
		$oclass{$oc} = 1;
		}
	%ginfo = &dn_to_hash($ginfo);
	&can_edit_group(\%ginfo) || &error($text{'gedit_eedit'});
	&ui_print_header(undef, $text{'gedit_title'}, "");
	}

print "<form action=\"save_group.cgi\" method=post>\n";
print "<input type=hidden name=new value='$in{'new'}'>\n";
print "<input type=hidden name=dn value='$in{'dn'}'>\n";

# Show group details
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'gedit_details'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

if (!$in{'new'}) {
        print "<tr> <td><b>$text{'gedit_dn'}</b></td>\n";
        print "<td colspan=3><tt>$in{'dn'}</tt></td> </tr>\n";

	print "<tr> <td><b>$text{'uedit_classes'}</b></td>\n";
	print "<td colspan=3>",join(" , ", map { "<tt>$_</tt>" }
			$ginfo->get_value('objectClass')),"</td> </tr>\n";
        }

print "<tr> <td valign=top><b>$text{'gedit_group'}</b></td>\n";
print "<td valign=top><input name=group size=10 value='$group'></td>\n";

print "<td valign=top><b>$text{'gedit_gid'}</b></td>\n";
if ($in{'new'} && $config{'next_gid'}) {
	# Next GID comes from module config
	while(1) {
		$newgid = $config{'next_gid'};
		$config{'next_gid'}++;
		last if (!&check_uid_used($ldap, &get_group_base(),
					  "gidNumber", $newgid));
		}
	print "<td valign=top><input name=gid size=10 ",
	      "value='$newgid'></td>\n";
	&save_module_config();
	}
elsif ($in{'new'}) {
	# Find the first free GID above the base by checking all existing groups
	&build_group_used(\%gused);
	$newgid = &allocate_gid(\%gused);
	print "<td valign=top><input name=gid size=10 value='$newgid'></td>\n";
	}
else {
	print "<td valign=top><input name=gid size=10 ",
	      "value=\"$gid\"></td>\n";
	}
print "</tr>\n";

print "<tr> <td valign=top><b>$text{'pass'}</b></td>\n";
printf "<td valign=top><input type=radio name=passmode value=0 %s> $text{'none2'}<br>\n",
	$pass eq "" ? "checked" : "";
printf "<input type=radio name=passmode value=1 %s> $text{'encrypted'}\n",
	$pass eq "" ? "" : "checked";
print "<input name=encpass size=20 value=\"$pass\"><br>\n";
print "<input type=radio name=passmode value=2 %s> $text{'clear'}\n";
print "<input name=pass size=15></td>\n";

print "<td valign=top><b>$text{'gedit_members'}</b></td>\n";
print "<td><table><tr><td><textarea wrap=auto name=members rows=5 cols=10>",
	join("\n", @members),"</textarea></td>\n";
print "<td valign=top>",&user_chooser_button("members", 1),
      "</td></tr></table></td></tr>\n";
print "</table></td></tr></table><p>\n";

# Show extra fields (if any)
&extra_fields_input($config{'group_fields'}, $ginfo);

# Show capabilties section
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'gedit_cap'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td><b>$text{'gedit_samba'}</b></td>\n";
printf "<td><input type=radio name=samba value=1 %s> %s\n",
	$oclass{$samba_group_class} ? "checked" : "", $text{'yes'};
printf "<input type=radio name=samba value=0 %s> %s</td>\n",
	$oclass{$samba_group_class} ? "" : "checked", $text{'no'};

print "<td colspan=2 width=50%></td>\n";

print "</table></td></tr></table><p>\n";

# Show section for on-save or on-creation options
if (!$in{'new'}) {
	print "<table border width=100%>\n";
	print "<tr $tb> <td><b>$text{'onsave'}</b></td> </tr>\n";
	print "<tr $cb> <td><table>\n";

	print "<tr> <td><b>$text{'chgid'}</b></td>\n";
	print "<td><input type=radio name=chgid value=0 checked> $text{'no'}\n";
	print "<input type=radio name=chgid value=1> $text{'gedit_homedirs'}\n";
	print "<input type=radio name=chgid value=2> $text{'gedit_allfiles'}</td> </tr>\n";

	print "<tr> <td><b>$text{'gedit_mothers'}</b></td>\n";
	printf "<td><input type=radio name=others value=1 %s> $text{'yes'}\n",
		$mconfig{'default_other'} ? "checked" : "";
	printf "<input type=radio name=others value=0 %s> $text{'no'}</td> </tr>\n",
		$mconfig{'default_other'} ? "" : "checked";

	print "</table></td> </tr></table>\n";
	}
else {
	print "<table border width=100%>\n";
	print "<tr $tb> <td><b>$text{'uedit_oncreate'}</b></td> </tr>\n";
	print "<tr $cb> <td><table>\n";

	print "<tr> <td><b>$text{'gedit_cothers'}</b></td>\n";
	printf "<td><input type=radio name=others value=1 %s> $text{'yes'}\n",
		$mconfig{'default_other'} ? "checked" : "";
	printf "<input type=radio name=others value=0 %s> $text{'no'}</td> </tr>\n",
		$mconfig{'default_other'} ? "" : "checked";

	print "</table></td> </tr></table>\n";

	}

print "<table width=100%><tr>\n";
if ($in{'new'}) {
        print "<td><input type=submit value='$text{'create'}'></td>\n";
        }
else {
        print "<td><input type=submit value='$text{'save'}'></td>\n";
	print "<td align=center><input type=submit name=raw ",
	      "value='$text{'uedit_raw'}'></td>\n";
        print "<td align=right><input type=submit name=delete ",
              "value='$text{'delete'}'></td>\n";
        }
print "</tr></table>\n";

&ui_print_footer("", $text{'index_return'});

