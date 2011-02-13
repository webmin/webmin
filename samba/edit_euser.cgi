#!/usr/local/bin/perl
# edit_euser.cgi
# Edit an existing samba user

require './samba-lib.pl';
&ReadParse();
# check acls

&error_setup("<blink><font color=red>$text{'eacl_aviol'}</font></blink>");
&error("$text{'eacl_np'} $text{'eacl_pvusers'}")
        unless $access{'view_users'};
# display		
&ui_print_header(undef, $text{'euser_title'}, "");
@ulist = &list_users();
$u = $ulist[$in{'idx'}];

print "<form action=save_euser.cgi>\n";
print "<input type=hidden name=idx value=\"$in{'idx'}\">\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'euser_title'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td align=right><b>$text{'euser_name'}</b></td>\n";
print "<td><tt>$u->{'name'}</tt></td>\n";

print "<td align=right><b>$text{'euser_uid'}</b></td>\n";
print "<td><input name=uid size=5 value=\"$u->{'uid'}\"></td> </tr>\n";

print "<tr> <td align=right><b>$text{'euser_passwd'}</b></td>\n";
if ($samba_version >= 3) {
	# In the new Samba, the password field is not really used for locking
	# accounts any more, so don't both with the no access/no password
	# options.
	print "<td colspan=3><input type=radio name=ptype value=2 checked> ",
	      "$text{'euser_currpw'}\n";
	}
else {
	# In the old Samba, you can set the password to deny a login to the
	# account or allow logins without a password
	$locked = ($u->{'pass1'} eq ("X" x 32));
	$nopass = ($u->{'pass1'} =~ /^NO PASSWORD/);
	printf "<td colspan=3><input type=radio name=ptype value=0 %s> $text{'euser_noaccess'}\n",
		$locked ? "checked" : "";
	printf "<input type=radio name=ptype value=1 %s> $text{'euser_nopw'}\n",
		$nopass ? "checked" : "";
	printf "<input type=radio name=ptype value=2 %s> $text{'euser_currpw'}\n",
		$locked||$nopass ? "" : "checked";
	}
print "<input type=radio name=ptype value=3> $text{'euser_newpw'}\n";
print "<input type=password name=pass size=20></td> </tr>\n";

if (!$u->{'opts'}) {
	# Old-style samba user
	print "<tr> <td align=right><b>$text{'euser_realname'}</b></td> <td colspan=3>\n";
	print "<input name=realname size=40 value='$u->{'real'}'></td> </tr>\n";

	print "<tr> <td align=right><b>$text{'euser_homedir'}</b></td>\n";
	print "<td><input name=homedir size=30 value='$u->{'home'}'></td>\n";

	print "<td align=right><b>$text{'euser_shell'}</b></td>\n";
	printf "<td><input name=shell size=15 value='%s'></td> </tr>\n",
		$u->{'shell'};
	}
else {
	# New-style samba user
	print "<input type=hidden name=new value=1>\n";
	map { $opt{uc($_)}++ } @{$u->{'opts'}};
	print "<tr> <td valign=top align=right><b>$text{'euser_option'}</b></td> <td colspan=3>\n";
	@ol = ($text{'euser_normal'}, "U", $text{'euser_nopwrequired'}, "N",
	       $text{'euser_disable'}, "D", $text{'euser_locked'}, "L" ,$text{'euser_noexpire'}, "X", $text{'euser_trust'}, "W");
	for($i=0; $i<@ol; $i+=2) {
		printf "<input type=checkbox name=opts value=%s %s> %s<br>\n",
			$ol[$i+1], $opt{$ol[$i+1]} ? "checked" : "", $ol[$i];
		delete($opt{$ol[$i+1]});
		}
	foreach $oo (keys %opt) {
		print "<input type=hidden name=opts value=$oo>\n";
		}
	print "</td> </tr>\n";
	}

print "</table></td></tr></table>\n";
print "<table width=100%>\n";
print "<tr> <td><input type=submit value=$text{'save'}></td>\n";
print "</form><form action=\"delete_euser.cgi\">\n";
print "<input type=hidden name=idx value=\"$in{'idx'}\">\n";
print "<td align=right><input type=submit value=$text{'delete'}></td> </tr>\n";
print "</form></table><p>\n";

&ui_print_footer("edit_epass.cgi", $text{'index_userlist'},
	"", $text{'index_sharelist'});

