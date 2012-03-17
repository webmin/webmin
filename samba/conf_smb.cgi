#!/usr/local/bin/perl
# conf_smb.cgi
# Display Windows networking options

require './samba-lib.pl';

# check acls

&error_setup("$text{'eacl_aviol'}ask_epass.cgi");
&error("$text{'eacl_np'} $text{'eacl_pcs'}") unless $access{'conf_smb'};

&ui_print_header(undef, $text{'smb_title'}, "");

&get_share("global");

print "<form action=save_smb.cgi>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'smb_title'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";
$gap = "&nbsp;" x 3;

print "<tr> <td><b>$text{'smb_workgroup'}</b></td>\n";
print "<td colspan=3>\n";
printf "<input type=radio name=workgroup_def value=1 %s> $text{'default'}\n",
	&getval("workgroup") eq "" ? "checked" : "";
printf "$gap <input type=radio name=workgroup_def value=0 %s>\n",
	&getval("workgroup") eq "" ? "" : "checked";
printf "<input name=workgroup size=15 value=\"%s\"></td> </tr>\n",
	&getval("workgroup");

print "<tr> <td><b>$text{'smb_wins'}</b></td>\n";
print "<td colspan=3>\n";
printf "<input type=radio name=wins value=0 %s> $text{'smb_winsserver'}\n",
	&isfalse("wins support") ? "" : "checked";
printf "$gap <input type=radio name=wins value=1 %s> $text{'smb_useserver'}\n",
	&getval("wins server") eq "" ? "" : "checked";
printf "<input name=wins_server size=10 value=\"%s\">\n",
	&getval("wins server");
printf "$gap <input type=radio name=wins value=2 %s> $text{'config_neither'}\n",
      &isfalse("wins support") && &getval("wins server") eq "" ? "checked" : "";
print "</td> </tr>\n";

$desc = &getval("server string");
print "<tr> <td><b>$text{'smb_description'}</b></td>\n";
print "<td colspan=3>\n";
print &ui_radio("server_string_def", !defined($desc) ? 1 :
				     $desc eq "" ? 2 : 0,
		[ [ 1, $text{'default'} ],
		  [ 2, $text{'smb_descriptionnone'} ],
		  [ 0, &ui_textbox("server_string", $desc, 40) ] ]);
print "</td> </tr>\n";

print "<tr> <td><b>$text{'smb_name'}</b></td>\n";
printf "<td><input name=netbios_name size=15 value=\"%s\"></td>\n",
	&getval("netbios name");

print "<td><b>$text{'smb_aliase'}</b></td>\n";
printf "<td><input name=netbios_aliases size=30 value=\"%s\"></td> </tr>\n",
	&getval("netbios aliases");

print "<tr> <td><b>$text{'smb_default'}</b></td>\n";
print "<td><select name=default>\n";
printf "<option value=\"\" %s> $text{'config_none'}\n", &getval("default") eq "";
foreach $s (&list_shares()) {
	next unless &can('r', \%access, $s) || !$access{'hide'};
	printf "<option value=\"$s\" %s> $s\n",
		&getval("default") eq $s ? "selected" : "";
	}
print "</select></td>\n";

print "<td><b>$text{'smb_show'}</b></td>\n";
print "<td rowspan=2><select name=auto_services multiple size=3>\n";
foreach $s (split(/s\+/, &getval("auto services"))) { $autos{$s}++; }
foreach $s (&list_shares()) {
	next unless &can('r', \%access, $s) || !$access{'hide'};
	printf "<option value=\"$s\" %s> $s\n",
		$autos{$s} ? "checked" : "";
	}
print "</select></td> </tr>\n";

print "<tr> <td><b>$text{'smb_disksize'}</b></td>\n";
print "<td colspan=2>\n";
printf "<input type=radio name=max_disk_size_def value=1 %s> $text{'smb_unlimited'}\n",
	&getval("max disk size") eq "" ? "checked" : "";
printf "$gap <input type=radio name=max_disk_size_def value=0 %s>\n",
	&getval("max disk size") eq "" ? "" : "checked";
printf "<input name=max_disk_size size=5 value=\"%s\"> kB</td>\n",
	&getval("max disk size");

print "<tr> <td><b>$text{'smb_winpopup'}</b></td>\n";
printf "<td><input name=message_command size=15 value=\"%s\"></td>\n",
	&getval("message command");

print "<td><b>$text{'smb_priority'}</b></td>\n";
printf "<td><input name=os_level size=5 value=\"%d\"></td> </tr>\n",
	&getval("os level");

print "<tr> <td><b>$text{'smb_protocol'}</b></td>\n";
print "<td><select name=protocol>\n";
printf "<option value=\"\" %s> $text{'default'}\n",
	&getval("protocol") eq "" ? "selected" : "";
foreach $p (@protocols) {
	printf "<option value=\"$p\" %s> $p\n",
		&getval("protocol") eq $p ? "selected" : "";
	}
print "</select></td>\n";

print "<td><b>$text{'smb_master'}</b></td>\n";
print "<td>";
printf "<input type=radio name=preferred_master value=yes %s> $text{'yes'}\n",
	&istrue("preferred master") ? "checked" : "";
printf "$gap <input type=radio name=preferred_master value=no %s> $text{'no'}\n",
	&isfalse("preferred master") ? "checked" : "";
printf "<input type=radio name=preferred_master value=auto %s> $text{'smb_master_auto'}\n",
	&getval("preferred master") =~ /auto/ ||
	!&getval("preferred master") ? "checked" : "";
print "</td> </tr>\n";

print "<tr> <td><b>$text{'smb_security'}</b></td>\n";
print "<td><select name=security>\n";
printf "<option value='' %s> $text{'default'}\n",
	&getval("security") ? "" : "selected";
printf "<option value=share %s> $text{'smb_sharelevel'}\n",
	&getval("security") =~ /^share$/i ? "selected" : "";
printf "<option value=user %s> $text{'smb_userlevel'}\n",
	&getval("security") =~ /^user$/i ? "selected" : "";
printf "<option value=server %s> $text{'smb_passwdserver'}\n",
	&getval("security") =~ /^server$/i ? "selected" : "";
printf "<option value=domain %s> $text{'smb_domain'}\n",
	&getval("security") =~ /^domain$/i ? "selected" : "";
printf "<option value=ads %s> $text{'smb_ads'}\n",
	&getval("security") =~ /^ads$/i ? "selected" : "";
print "</select></td>\n";

print "<td><b>$text{'smb_passwdserver'}</b></td>\n";
printf "<td><input name=password_server size=10 value=\"%s\"></td> </tr>\n",
	&getval("password server");

print "<tr> <td valign=top><b>$text{'smb_announce'}</b></td>\n";
print "<td colspan=3>\n";
printf "<input type=radio name=remote_def value=1 %s> $text{'smb_nowhere'}\n",
	&getval("remote announce") ? "" : "checked";
printf "$gap <input type=radio name=remote_def value=0 %s> $text{'smb_fromlist'}<br>\n",
	&getval("remote announce") ? "checked" : "";
print "<table border> <tr> <td><b>$text{'smb_ip'}</b></td> ",
      "<td>$text{'smb_asworkgroup'}</td> </tr>\n";
@rem = split(/\s+/, &getval("remote announce")); $len = @rem ? @rem+1 : 2;
for($i=0; $i<$len; $i++) {
	print "<tr>\n";
	if ($rem[$i] =~ /^([\d\.]+)\/(.+)$/) { $ip = $1; $wg = $2; }
	elsif ($rem[$i] =~ /^([\d\.]+)$/) { $ip = $1; $wg = ""; }
	else { $ip = $wg = ""; }
	print "<td><input name=remote_ip$i size=15 value=\"$ip\"></td>\n";
	print "<td><input name=remote_wg$i size=15 value=\"$wg\"></td>\n";
	print "</tr>\n";
	}
print "</table></td> </tr>\n";

print "</table></td></tr></table><p>\n";
print "<input type=submit value=$text{'save'}></form>\n";

&ui_print_footer("", $text{'index_sharelist'});

