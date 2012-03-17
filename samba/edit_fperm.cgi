#!/usr/local/bin/perl
# edit_fperm.cgi
# Edit file permissions options

require './samba-lib.pl';
&ReadParse();
# check acls

&error_setup("$text{'eacl_aviol'}ask_epass.cgi");
&error("$text{'eacl_np'} $text{'eacl_pvperm'}")
        unless &can('rp', \%access, $in{'share'});
# display
$s = $in{'share'};
if ($s eq "global") {
	&ui_print_header(undef, $text{'fperm_title1'}, "");
	}
else {
	&ui_print_header(undef, $text{'fperm_title2'}, "");
	print "<center><font size=+1>", &text('fmisc_for', $s), "</font></center>\n";
	}
&get_share($s);

print "<form action=save_fperm.cgi>\n";
print "<input type=hidden name=old_name value=\"$s\">\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'fperm_option'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td align=right><b>$text{'fperm_filemode'}</b></td>\n";
printf "<td><input name=create_mode size=5 value=\"%s\"></td>\n",
	&getval("create mode");

print "<td align=right><b>$text{'fperm_dirmode'}</b></td>\n";
printf "<td><input name=directory_mode size=5 value=\"%s\"></td> </tr>\n",
	&getval("directory mode");

print "<tr> <td align=right><b>$text{'fperm_notlist'}</b></td>\n";
printf "<td colspan=3><input name=dont_descend size=40 value=\"%s\"></td>\n",
	&getval("dont descend");
print "</tr>\n";

print "<tr> <td align=right><b>$text{'fperm_forceuser'}</b></td>\n";
&username_input("force user", "None");

print "<td align=right><b>$text{'fperm_forcegrp'}</b></td>\n";
&groupname_input("force group", "None");

print "<tr> <td align=right><b>$text{'fperm_link'}</b></td>\n";
print "<td>",&yesno_input("wide links"),"</td>\n";

print "<td align=right><b>$text{'fperm_delro'}</b></td>\n";
print "<td>",&yesno_input("delete readonly"),"</td> </tr>\n";

print "<tr> <td align=right><b>$text{'fperm_forcefile'}</b></td>\n";
printf "<td><input name=force_create_mode size=5 value=\"%s\"></td>\n",
	&getval("force create mode");

print "<td align=right><b>$text{'fperm_forcedir'}</b></td>\n";
printf "<td><input name=force_directory_mode size=5 value=\"%s\"></td> </tr>\n",
	&getval("force directory mode");

print "</table> </td></tr></table><p>\n";
print "<input type=submit value=$text{'save'}>" 
	if &can('wP', \%access, $in{'share'});
print "</form>\n";

&ui_print_footer("edit_fshare.cgi?share=".&urlize($s), $text{'index_fileshare'},
	"", $text{'index_sharelist'});

