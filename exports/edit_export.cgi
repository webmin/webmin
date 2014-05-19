#!/usr/local/bin/perl
# edit_export.cgi
# Allow editing of one export to a client

require './exports-lib.pl';
&ReadParse();
local $via_pfs = 0;
local $nfsv = nfs_max_version("localhost");
if ($in{'new'}) {
	&ui_print_header(undef, $text{'create_title'}, "", "create_export");
	$via_pfs = ($nfsv == 4) ? 1 : 0;
	$exp->{"pfs"} = "/export";
    }
else {
	&ui_print_header(undef, $text{'edit_title'}, "", "edit_export");
	@exps = &list_exports();
	$exp = $exps[$in{'idx'}];
	%opts = %{$exp->{'options'}};
	}

# WebNFS doesn't exist on Linux
local $linux = ($gconfig{'os_type'} =~ /linux/i) ? 1 : 0;

print "<script type=\"text/javascript\">\n";
print "function enable_sec(level) {\n";
print " if (level) {\n";
print "   document.forms[0].sec[1].disabled=0;\n";
print "   document.forms[0].sec[2].disabled=0;\n";
print "   } else {\n";
print "   document.forms[0].sec[1].disabled=1;\n";
print "   document.forms[0].sec[2].disabled=1;\n";
print "   document.forms[0].sec[0].checked=1;\n";
print " }\n}\n";
print "function enable_pfs(enable) {\n";
print" set_pfs_dir();\n";
print "if (enable == 1) {\n";
print "   document.forms[0].pfs.disabled=0;\n";
print "   document.forms[0].pfs_button.disabled=0;\n";
print "   document.forms[0].pfs_dir.disabled=0;\n";
print "   } else {\n";
print "   document.forms[0].pfs.disabled=1;\n";
print "   document.forms[0].pfs_button.disabled=1;\n";
print "   document.forms[0].pfs_dir.disabled=1;\n";
print "   }\n";
print "}\n";
print "function set_pfs_dir() {\n";
print "   var pfs = document.forms[0].pfs.value;\n";
print "   var dir = document.forms[0].dir.value;\n";
print "   if (document.forms[0].via_pfs[0].checked == 0) {\n";
print "      document.forms[0].pfs_dir.value = dir; }\n";
print "   else {\n";
print "      var reg = /\\/\$/;\n";
print "      dir = dir.replace(reg, \"\");\n";
print "      dir = dir.substring(dir.lastIndexOf(\"/\"));\n";
print "      document.forms[0].pfs_dir.value = pfs + dir; }\n";
print "}\n";
print "window.onload = function() {\n";
print "   enable_pfs(document.forms[0].via_pfs[0].checked);\n";
print "   if (document.forms[0].auth[0].checked == 1) {\n";
print "      enable_sec(0); }\n";
print "   else {\n";
print "      enable_sec(1); }\n";
print "   set_pfs_dir();\n";
print "}\n";
print "</script>\n";

print "<form action=save_export.cgi>\n";
print "<input type=hidden name=new value='$in{'new'}'>\n";
print "<input type=hidden name=idx value='$in{'idx'}'>\n";

print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'edit_details'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";

# Show NFS pseudofilesystem (NFSv4)
if ($nfsv == 4) {
    print "<tr> <td>",&hlink("<b>$text{'edit_nfs_vers'}</b>","vers"),"</td>\n";
    printf "<td colspan=3><input type=radio name=via_pfs value=1 %s onclick=enable_pfs(1)> 4\n",
    $via_pfs ? "checked" : "";
    printf "<input type=radio name=via_pfs value=0 %s onclick=enable_pfs(0)> 3 (or lower)</td> </tr>\n",
    $via_pfs ? "" : "checked";
    
    print "<tr> <td>",&hlink("<b>$text{'edit_pfs'}</b>","pfs"),"</td>\n";
    printf "<td colspan=3><input name=pfs size=40 value=\"$exp->{'pfs'}\" onkeyup=set_pfs_dir()>";
    print &file_chooser_button2("pfs", 1, "pfs_button", ($via_pfs == 0)),"</td> </tr>\n";
} else {
    printf "<tr><td><input type=hidden name=via_pfs value=0></td></tr>\n";
}

# Show directory input
print "<tr> <td>",&hlink("<b>$text{'edit_dir'}</b>","dir"),"</td>\n";
print "<td colspan=3><input name=dir size=40 value=\"$exp->{'dir'}\" onkeyup=set_pfs_dir()>",
    &file_chooser_button("dir", 1);
if ($nfsv == 4) {
    print "$text{'edit_in'} <input style=\"background: rgb(238, 238, 238)\" name=pfs_dir size=40 readonly></td> </tr>\n";
}

# Show active input
print "<tr> <td>",&hlink("<b>$text{'edit_active'}</b>","active"),"</td>\n";
printf "<td colspan=3><input type=radio name=active value=1 %s> $text{'yes'}\n",
    $in{'new'} || $exp->{'active'} ? 'checked' : '';
printf "<input type=radio name=active value=0 %s> $text{'no'}</td> </tr>\n",
    $in{'new'} || $exp->{'active'} ? '' : 'checked';

# Show input for export to
local $h = $exp->{'host'};
if ($h eq "=public") { $mode = 0; }
elsif ($h =~ /^gss\//) {$mode = 5; }
elsif ($h =~ /^\@(.*)/) { $mode = 1; $netgroup = $1; }
elsif ($h =~ /^(\S+)\/(\S+)$/) { $mode = 2; $network = $1; $netmask = $2; }
elsif ($h eq "") { $mode = 3; }
else { $mode = 4; $host = $h; }
# and authentication input
local $auth = "", $sec = "";
if ($h =~ /^gss\/krb5/) {
    $auth = "krb5";
    if ($h =~ /i$/) { $sec = "i"; }
    if ($h =~ /p$/) { $sec = "p"; }
}

print "<tr><td rowspan=8 valign=top>",&hlink("<b>$text{'edit_to'}</b>","client");
if ($nfsv == 4) {
    print "<br>",&hlink("$text{'edit_auth'}","auth"),"</td>\n";
    
    printf "<td rowspan=5 valign=top><input type=radio name=auth value=0 %s onclick=enable_sec(0)> sys</td>\n",
    ($auth eq "") ? "checked" : "";
} else {
    printf "<td><input type=hidden name=auth value=0></td>\n";
}
printf "<tr><td><input type=radio name=mode value=3 %s> $text{'edit_all'} </td>\n",
	$mode == 3 ? "checked" : "";

printf "<td colspan=2><input type=radio name=mode value=4 %s> $text{'edit_host'}\n",
	$mode == 4 ? "checked" : "";
print "<input name=host size=35 value='$host'></td> </tr>\n";

printf "<tr><td><input type=radio name=mode value=0 %s %s> $text{'edit_webnfs'}</td>\n",
	$mode == 0 ? "checked" : "", $linux ? "disabled" : "";

printf "<td colspan=2><input type=radio name=mode value=1 %s> $text{'edit_netgroup'}\n",
	$mode == 1 ? "checked" : "";
print "<input name=netgroup size=25 value='$netgroup'></td> </tr>\n";

printf "<tr><td colspan=3><input type=radio name=mode value=2 %s> IPv4 $text{'edit_network'}\n",
	$mode == 2 ? "checked" : "";
print "<input name=network size=15 value='$network'>\n";
print "$text{'edit_netmask'} <input name=netmask size=15 value='$netmask'></td> </tr>\n";

printf "<tr><td colspan=3><input type=radio name=mode value=6 %s disabled> IPv6 $text{'edit_address'}\n",
    $mode == 6 ? "checked" : "";
print "<input name=address size=39 value='$address' disabled>\n";
print "$text{'edit_prefix'}<input name=prefix size=2 value='$prefix' disabled></td> </tr>\n";

if ($nfsv == 4) {
    printf "<tr><td colspan=3><input type=radio name=auth value=1 %s onclick=enable_sec(1)> krb5</td></tr>",
    ($auth eq "krb5") ? "checked" : "";
    printf "<tr><td colspan=3><input type=radio name=auth value=2 %s disabled> lipkey</td></tr>\n",
    ($auth eq "lipkey") ? "checked" : "";
    printf "<tr><td colspan=3><input type=radio name=auth value=3 %s disabled> spkm-3</td></tr>\n",
    ($auth eq "spkm") ? "checked" : "";

# Show security level input
print "<tr> <td>", &hlink("<b>$text{'edit_sec'}</b>", "sec"), "</td>\n";
printf "<td nowrap colspan=3><input type=radio name=sec value=0 %s> $text{'config_none'}\n",
    ($sec eq "") ? "checked" : "";
printf "<input type=radio name=sec value=1 %s> $text{'edit_integrity'}\n",
    ($sec eq "i") ? "checked" : "";
printf "<input type=radio name=sec value=2 %s> $text{'edit_privacy'}</td></tr>\n",
    ($sec eq "p") ? "checked" : "";
}

print "</table></td></tr></table><p>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'edit_security'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

# Show read-only input
print "<tr> <td>",&hlink("<b>$text{'edit_ro'}</b>","ro"),"</td>\n";
printf "<td><input type=radio name=ro value=1 %s> $text{'yes'}\n",
	defined($opts{'rw'}) ? "" : "checked";
printf "<input type=radio name=ro value=0 %s> $text{'no'}</td>\n",
	defined($opts{'rw'}) ? "checked" : "";

# Show input for secure port
print "<td>",&hlink("<b>$text{'edit_insecure'}</b>","insecure"),"</td>\n";
printf "<td><input type=radio name=insecure value=0 %s> $text{'yes'}\n",
	defined($opts{'insecure'}) ? "" : "checked";
printf "<input type=radio name=insecure value=1 %s> $text{'no'}</td> </tr>\n",
	defined($opts{'insecure'}) ? "checked" : "";

# Show subtree check input
print "<tr> <td>",&hlink("<b>$text{'edit_subtree_check'}</b>","subtree_check"),"</td>\n";
printf "<td><input type=radio name=no_subtree_check value=1 %s> $text{'yes'}\n",
    defined($opts{'no_subtree_check'}) ? "checked" : "";
printf "<input type=radio name=no_subtree_check value=0 %s> $text{'no'}\n",
    defined($opts{'no_subtree_check'}) ? "" : "checked";
print "</td>\n";

# Show nohide check input
print "<td>",&hlink("<b>$text{'edit_hide'}</b>","hide"),"</td>\n";
printf "<td><input type=radio name=nohide value=0 %s> $text{'yes'}\n",
	defined($opts{'nohide'}) ? "" : "checked";
printf "<input type=radio name=nohide value=1 %s> $text{'no'}</td> </tr>\n",
	defined($opts{'nohide'}) ? "checked" : "";

# Show sync input
my $sync = defined($opts{'sync'}) ? 1 : defined($opts{'async'}) ? 2 : 0;
print "<tr> <td>",&hlink("<b>$text{'edit_sync'}</b>","sync"),"</td>\n<td colspan=3>";
foreach $s (1, 2, 0) {
	printf "<input type=radio name=sync value=%d %s> %s\n",
		$s, $sync == $s ? "checked" : "", $text{'edit_sync'.$s};
	}
print "</td> </tr>\n";

# Show root trust input
print "<tr> <td>",&hlink("<b>$text{'edit_squash'}</b>","squash"),"</td> <td colspan=3>\n";
printf "<input type=radio name=squash value=0 %s> $text{'edit_everyone'}\n",
	defined($opts{'no_root_squash'}) ? "checked" : "";
printf "<input type=radio name=squash value=1 %s> $text{'edit_except'}\n",
	!defined($opts{'no_root_squash'}) &&
	!defined($opts{'all_squash'}) ? "checked" : "";
printf "<input type=radio name=squash value=2 %s> $text{'edit_nobody'}\n";
	defined($opts{'all_squash'}) ? "checked" : "";
print "</td> </tr>\n";

# Show untrusted user input
print "<tr> <td>",&hlink("<b>$text{'edit_anonuid'}</b>","anonuid"),"</td> <td>\n";
printf "<input type=radio name=anonuid_def value=1 %s> $text{'edit_default'}\n",
    defined($opts{'anonuid'}) ? "" : "checked";
printf "<input type=radio name=anonuid_def value=0 %s>\n",
    defined($opts{'anonuid'}) ? "checked" : "";
printf "<input name=anonuid size=8 value=\"%s\">\n",
    $opts{'anonuid'} ? getpwuid($opts{'anonuid'}) : "";
print &user_chooser_button("anonuid", 0),"</td>\n";

# Show untrusted group input
print "<td>",&hlink("<b>$text{'edit_anongid'}</b>","anongid"),"</td> <td>\n";
printf "<input type=radio name=anongid_def value=1 %s> $text{'edit_default'}\n",
    defined($opts{'anongid'}) ? "" : "checked";
printf "<input type=radio name=anongid_def value=0 %s>\n",
    defined($opts{'anongid'}) ? "checked" : "";
printf "<input name=anongid size=8 value=\"%s\">\n",
    $opts{'anongid'} ? getgrgid($opts{'anongid'}) : "";
print &group_chooser_button("anongid", 0),"</td> </tr>\n";

print "<tr $tb> <td colspan=4><b>$text{'edit_v2opts'}</b></td> </tr>\n";

# Show input for relative symlinks
print "<tr> <td>",&hlink("<b>$text{'edit_relative'}</b>","link_relative"),"</td>\n";
printf "<td><input type=radio name=link_relative value=1 %s> $text{'yes'}\n",
    defined($opts{'link_relative'}) ? "checked" : "";
printf "<input type=radio name=link_relative value=0 %s> $text{'no'}</td>\n",
    defined($opts{'link_relative'}) ? "" : "checked";

# Show deny access input
print "<td>",&hlink("<b>$text{'edit_noaccess'}</b>","noaccess"),"</td>\n";
printf "<td><input type=radio name=noaccess value=1 %s> $text{'yes'}\n",
    defined($opts{'noaccess'}) ? "checked" : "";
printf "<input type=radio name=noaccess value=0 %s> $text{'no'}</td> </tr>\n",
    defined($opts{'noaccess'}) ? "" : "checked";

# Show untrusted UIDs input
print "<tr> <td>",&hlink("<b>$text{'edit_uids'}</b>","squash_uids"),"</td> <td>\n";
printf "<input type=radio name=squash_uids_def value=1 %s> $text{'edit_none'}\n",
    $opts{'squash_uids'} ? "" : "checked";
printf "<input type=radio name=squash_uids_def value=0 %s>\n",
    $opts{'squash_uids'} ? "checked" : "";
printf "<input name=squash_uids size=15 value=\"%s\"></td>\n",
    $opts{'squash_uids'};

# Show untrusted GIDs input
print "<td>",&hlink("<b>$text{'edit_gids'}</b>","squash_gids"),"</td> <td>\n";
printf "<input type=radio name=squash_gids_def value=1 %s> $text{'edit_none'}\n",
    $opts{'squash_gids'} ? "" : "checked";
printf "<input type=radio name=squash_gids_def value=0 %s>\n",
    $opts{'squash_gids'} ? "checked" : "";
printf "<input name=squash_gids size=15 value=\"%s\"></td> </tr>\n",
    $opts{'squash_gids'};

print "</table></td></tr></table>\n";
if (!$in{'new'}) {
	print "<table width=100%><tr>\n";
	print "<td><input type=submit value=\"$text{'save'}\"></td>\n";
	print "<td align=right><input type=submit name=delete ",
	      "value=\"$text{'delete'}\"></td>\n";
	print "</tr></table>\n";
	}
else {
	print "<input type=hidden name=new value=1>\n";
	print "<input type=submit value=\"$text{'create'}\">\n";
	}

&ui_print_footer("", $text{'index_return'});
