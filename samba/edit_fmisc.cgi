#!/usr/local/bin/perl
# edit_fmisc.cgi
# Edit misc file options

require './samba-lib.pl';
&ReadParse();
# check acls

&error_setup("$text{'eacl_aviol'}ask_epass.cgi");
&error("$text{'eacl_np'} $text{'eacl_pvfmisc'}")
		unless &can('ro', \%access, $in{'share'});
# display
$s = $in{'share'};
if ($s eq "global") {
	&ui_print_header(undef, $text{'fmisc_title'}, "");
	}
else {
	&ui_print_header(undef, $text{'fmisc_title'}, "");
	print "<center><font size=+1>", &text('fmisc_for', $s),"</font></center>\n";
	}
&get_share($s);

print "<form action=save_fmisc.cgi>\n";
print "<input type=hidden name=old_name value=\"$s\">\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'misc_title'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td align=right><b>$text{'fmisc_lockfile'}</b></td>\n";
print "<td>",&yesno_input("locking"),"</td>\n";

print "<td align=right><b>$text{'fmisc_maxconn'}</b></td>\n";
printf "<td><input type=radio name=max_connections_def value=1 %s> $text{'smb_unlimited'}\n",
	&getval("max connections") == 0 ? "checked" : "";
printf "<input type=radio name=max_connections_def value=0 %s>\n",
	&getval("max connections") > 0 ? "checked" : "";
printf "<input size=6 name=max_connections value=\"%s\"></td> </tr>\n",
	&getval("max connections") > 0 ? &getval("max connections") : "";

print "<tr> <td align=right><b>$text{'fmisc_oplocks'}</b></td>\n";
print "<td>",&yesno_input("oplocks"),"</td>\n";

print "<td align=right><b>$text{'fmisc_level2'}</b></td>\n";
print "<td>",&yesno_input("level2 oplocks"),"</td> </tr>\n";

print "<tr> <td align=right><b>$text{'fmisc_fake'}</b></td>\n";
print "<td>",&yesno_input("fake oplocks"),"</td>\n";

print "<td align=right><b>$text{'fmisc_sharemode'}</b></td>\n";
print "<td>",&yesno_input("share modes"),"</td> </tr>\n";

print "<tr> <td align=right><b>$text{'fmisc_strict'}</b></td>\n";
print "<td>",&yesno_input("strict locking"),"</td>\n";

print "<td align=right><b>$text{'fmisc_sync'}</b></td>\n";
print "<td>",&yesno_input("sync always"),"</td> </tr>\n";

print "<tr> <td align=right><b>$text{'fmisc_volume'}</b></td>\n";
printf "<td colspan=3><input type=radio name=volume_def value=1 %s> $text{'fmisc_sameas'}\n",
	&getval("volume") eq "" ? "checked" : "";
printf "<input type=radio name=volume_def value=0 %s>\n",
	&getval("volume") eq "" ? "" : "checked";
printf "<input size=25 name=volume value=\"%s\"></td> </tr>\n",
	&getval("volume");

print "</table><table>\n";

print "<tr> <td align=right><b>$text{'fmisc_unixdos'}</b></td>\n";
printf"<td><input name=mangled_map size=40 value=\"%s\"></td></tr>\n",
	&getval("mangled map");

print "<tr> <td align=right><b>$text{'fmisc_conncmd'}</b></td>\n";
printf "<td><input name=preexec size=40 value=\"%s\"></td> </tr>\n",
	&getval("preexec");

print "<tr> <td align=right><b>$text{'fmisc_disconncmd'}</b></td>\n";
printf "<td><input name=postexec size=40 value=\"%s\"></td> </tr>\n",
	&getval("postexec");

print "<tr> <td align=right><b>$text{'fmisc_rootconn'}</b></td>\n";
printf "<td><input name=root_preexec size=40 value=\"%s\"></td> </tr>\n",
	&getval("root preexec");

print "<tr> <td align=right><b>$text{'fmisc_rootdisconn'}</b></td>\n";
printf "<td><input name=root_postexec size=40 value=\"%s\"></td> </tr>\n",
	&getval("root postexec");

print "</table> </td></tr></table><p>\n";
print "<input type=submit value=$text{'save'}>"
	if &can('wO', \%access, $in{'share'});
print "</form>\n";

&ui_print_footer("edit_fshare.cgi?share=".&urlize($s), $text{'index_fileshare'},
	"", $text{'index_sharelist'});

