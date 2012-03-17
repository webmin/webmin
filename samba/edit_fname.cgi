#!/usr/local/bin/perl
# edit_fname.cgi
# Edit file naming options

require './samba-lib.pl';
&ReadParse();
# check acls

&error_setup("$text{'eacl_aviol'}ask_epass.cgi");
&error("$text{'eacl_np'} $text{'eacl_pvfname'}")
        unless &can('rn', \%access, $in{'share'});
# display
$s = $in{'share'};
if ($s eq "global") {
	&ui_print_header(undef, $text{'fname_title1'}, "");
	}
else {
	&ui_print_header(undef, $text{'fname_title2'}, "");
	print "<center><font size=+1>",&text('fmisc_for', $s),"</font></center>\n";
	}
&get_share($s);

print "<form action=save_fname.cgi>\n";
print "<input type=hidden name=old_name value=\"$s\">\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'fname_option'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td align=right><b>$text{'fname_manglecase'}</b></td>\n";
print "<td>",&yesno_input("mangle case"),"</td>\n";

print "<td align=right><b>$text{'fname_case'}</b></td>\n";
print "<td>",&yesno_input("case sensitive"),"</td> </tr>\n";

print "<tr> <td align=right><b>$text{'fname_defaultcase'}</b></td>\n";
printf "<td><input type=radio name=default_case value=lower %s> $text{'fname_lower'}\n",
	&getval("default case") =~ /lower/i ? "checked" : "";
printf "<input type=radio name=default_case value=upper %s> $text{'fname_upper'}</td>\n",
	&getval("default case") =~ /upper/i ? "checked" : "";

print "<td align=right><b>$text{'fname_preserve'}</b></td>\n";
print "<td>",&yesno_input("preserve case"),"</td> </tr>\n";

print "<tr> <td align=right><b>$text{'fname_shortpreserve'}</b></td>\n";
print "<td>",&yesno_input("short preserve case"),"</td>\n";

print "<td align=right><b>$text{'fname_hide'}</b></td>\n";
print "<td>",&yesno_input("hide dot files"),"</td> </tr>\n";

print "<tr> <td align=right><b>$text{'fname_archive'}</b></td>\n";
print "<td>",&yesno_input("map archive"),"</td>\n";

print "<td align=right><b>$text{'fname_hidden'}</b></td>\n";
print "<td>",&yesno_input("map hidden"),"</td> </tr>\n";

print "<tr> <td align=right><b>$text{'fname_system'}</b></td>\n";
print "<td>",&yesno_input("map system"),"</td>\n";

print "</table> </td></tr></table><p>\n";
print "<input type=submit value=$text{'save'}>"
	if &can('wN', \%access, $in{'share'});
print "</form>\n";

&ui_print_footer("edit_fshare.cgi?share=".&urlize($s), $text{'index_fileshare'},
	"", $text{'index_sharelist'});

