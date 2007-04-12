#!/usr/local/bin/perl
# edit_sec.cgi
# Edit security options for some file or print share

require './samba-lib.pl';
&ReadParse();
# check acls
%access = &get_module_acl();
&error_setup("<blink><font color=red>$text{'eacl_aviol'}</font></blink>");
&error("$text{'eacl_np'} $text{'eacl_pvsec'}")
        unless &can('rs', \%access, $in{'share'});
# display
$s = $in{'share'};
if ($s eq "global") {
	&ui_print_header(undef, $text{'sec_index1'}, "");
	}
else {
	&ui_print_header(undef, $text{'sec_index2'}, "");
	print "<center><font size=+1>",&text('fmisc_for', $s), "</font></center>\n";
	}
&get_share($s);

print "<form action=save_sec.cgi>\n";
print "<input type=hidden name=old_name value=\"$s\">\n";
print "<input type=hidden name=printer value=\"$in{'printer'}\">\n";

print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'share_security'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td align=right><b>$text{'sec_writable'}</b></td>\n";
print "<td>",&yesno_input("writeable"),"</td>\n";

print "<td align=right><b>$text{'sec_guest'}</b></td>\n";
printf "<td><input type=radio name=guest value=0 %s> $text{'config_none'}\n",
	&istrue("public") ? "" : "checked";
printf "<input type=radio name=guest value=1 %s> $text{'yes'}\n",
	&istrue("public") && !&istrue("guest only") ? "checked" : "";
printf "<input type=radio name=guest value=2 %s> $text{'sec_guestonly'}</td> </tr>\n",
	&istrue("public") && &istrue("guest only") ? "checked" : "";

print "<tr> <td align=right><b>$text{'sec_guestaccount'}</b></td>\n";
&username_input("guest account", "Default");

print "<td align=right><b>$text{'sec_limit'}</b></td>\n";
print "<td>",&yesno_input("only user"),"</td> </tr>\n";

print "<tr> <td align=right><b>$text{'sec_allowhost'}</b></td>\n";
printf "<td colspan=3><input type=radio name=allow_hosts_all value=1 %s> $text{'config_all'}\n",
	&getval("allow hosts") eq "" ? "checked" : "";
print "&nbsp;&nbsp;\n";
printf "<input type=radio name=allow_hosts_all value=0 %s> $text{'sec_onlyallow'}:\n",
	&getval("allow hosts") eq "" ? "" : "checked";
printf "<input name=allow_hosts size=35 value=\"%s\"></td> </tr>\n",
	&getval("allow hosts");

print "<tr> <td align=right><b>$text{'sec_denyhost'}</b></td>\n";
printf "<td colspan=3><input type=radio name=deny_hosts_all value=1 %s> $text{'config_none'}\n",
	&getval("deny hosts") eq "" ? "checked" : "";
print "&nbsp;&nbsp;\n";
printf "<input type=radio name=deny_hosts_all value=0 %s> $text{'sec_onlydeny'}:\n",
	&getval("deny hosts") eq "" ? "" : "checked";
printf "<input name=deny_hosts size=35 value=\"%s\"></td> </tr>\n",
	&getval("deny hosts");

print "<tr> <td align=right><b>$text{'sec_revalidate'}</b></td>\n";
print "<td>",&yesno_input("revalidate"),"</td> </tr>\n";

@valid_users = &split_users(&getval("valid users"));
print "<tr> <td align=right><b>$text{'sec_validuser'}</b></td> <td colspan=3>\n";
printf "<input name=valid_users_u size=60 value='%s'> %s</td> </tr>\n",
	join(' ', grep { !/^@/ } @valid_users),
	&user_chooser_button("valid_users_u", 1);
print "<tr> <td align=right><b>$text{'sec_validgroup'}</b></td> <td colspan=3>\n";
printf "<input name=valid_users_g size=60 value='%s'> %s</td> </tr>\n",
	join(' ', map { s/@//;$_ } grep { /^@/ } @valid_users),
	&group_chooser_button("valid_users_g", 1);

@invalid_users = &split_users(&getval("invalid users"));
print "<tr> <td align=right><b>$text{'sec_invaliduser'}</b></td> <td colspan=3>\n";
printf "<input name=invalid_users_u size=60 value='%s'> %s</td> </tr>\n",
	join(' ', grep { !/^@/ } @invalid_users),
	&user_chooser_button("invalid_users_u", 1);
print "<tr> <td align=right><b>$text{'sec_invalidgroup'}</b></td> <td colspan=3>\n";
printf "<input name=invalid_users_g size=60 value='%s'> %s</td> </tr>\n",
	join(' ', map { s/@//;$_ } grep { /^@/ } @invalid_users),
	&group_chooser_button("invalid_users_g", 1);

print "<tr> <td colspan=4><hr></td> </tr>\n";

@user = &split_users(&getval("user"));
print "<tr> <td align=right><b>$text{'sec_possibleuser'}</b></td> <td>\n";
printf "<input name=user_u size=30 value='%s'> %s</td>\n",
	join(' ', grep { !/^@/ } @user),
	&user_chooser_button("user_u", 1);
print "<td align=right><b>$text{'sec_possiblegroup'}</b></td> <td colspan=3>\n";
printf "<input name=user_g size=30 value='%s'> %s</td> </tr>\n",
	join(' ', map { s/@//;$_ } grep { /^@/ } @user),
	&group_chooser_button("user_g", 1);

@read_list = &split_users(&getval("read list"));
print "<tr> <td align=right><b>$text{'sec_rouser'}</b></td> <td>\n";
printf "<input name=read_list_u size=30 value='%s'> %s</td>\n",
	join(' ', grep { !/^@/ } @read_list),
	&user_chooser_button("read_list_u", 1);
print "<td align=right><b>$text{'sec_rogroup'}</b></td> <td colspan=3>\n";
printf "<input name=read_list_g size=30 value='%s'> %s</td> </tr>\n",
	join(' ', map { s/@//;$_ } grep { /^@/ } @read_list),
	&group_chooser_button("read_list_g", 1);

@write_list = &split_users(&getval("write list"));
print "<tr> <td align=right><b>$text{'sec_rwuser'}</b></td> <td>\n";
printf "<input name=write_list_u size=30 value='%s'> %s</td>\n",
	join(' ', grep { !/^@/ } @write_list),
	&user_chooser_button("write_list_u", 1);
print "<td align=right><b>$text{'sec_rwgroup'}</b></td> <td>\n";
printf "<input name=write_list_g size=30 value='%s'> %s</td> </tr>\n",
	join(' ', map { s/@//;$_ } grep { /^@/ } @write_list),
	&group_chooser_button("write_list_g", 1);

print "</table><table border width=100%>\n";

print "</table> </td></tr></table><p>\n";
print "<input type=submit value=$text{'save'}>" 
	if &can('wS', \%access, $in{'share'});
print "</form>\n";

if (&istrue("printable") || $in{'printer'}) {
	&ui_print_footer("edit_pshare.cgi?share=".&urlize($s), $text{'index_printershare'}, "", $text{'index_sharelist'});
	}
else {
	&ui_print_footer("edit_fshare.cgi?share=".&urlize($s), $text{'index_fileshare'}, "", $text{'index_sharelist'});
	}


sub split_users
{
return split(/\s*,\s*/, $_[0]);
}

