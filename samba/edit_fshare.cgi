#!/usr/local/bin/perl
# edit_fshare.cgi
# Display a form for editing or creating a new directory share

require './samba-lib.pl';
&ReadParse();
$s = $in{'share'};
# check acls
%access = &get_module_acl();
&error_setup("<blink><font color=red>$text{'eacl_aviol'}</font></blink>");
if(!$s) {
    &error("$text{'eacl_np'} $text{'eacl_pcfs'}")
	    unless $access{'c_fs'};
	}
else {
	&error("$text{'eacl_np'} $text{'eacl_pafs'}")
        unless &can('r', \%access, $in{'share'});
    }
# display
if ($s) {
	&ui_print_header(undef, $s eq 'global' ? $text{'share_title1'} : $text{'share_title2'}, "");
	&get_share($s);
	}
else {
	&ui_print_header(undef, $text{'share_title3'}, "");
	}

print "<form action=save_fshare.cgi>\n";
if ($s) { print "<input type=hidden name=old_name value=\"$s\">\n"; }

# Vital share options..
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'share_info'}</b></td> </tr>\n";
print "<tr $cb> <td><table cellpadding=2>\n";
if ($s ne "global") {
	if ($copy = &getval("copy")) {
		print "<tr> <td colspan=4><b>",&text('share_copy', $copy),
		      "</b></td> </tr>\n";
		}
	print "<tr> <td align=right><b>$text{'share_name'}</b></td>\n";
	printf "<td colspan=3><input type=radio name=homes value=0 %s>\n",
		$s eq "homes" ? "" : "checked";
	printf "<input size=10 name=share value=\"%s\">&nbsp;&nbsp;&nbsp;\n",
		$s eq "homes" ? "" : $s;
	printf "<input type=radio name=homes value=1 %s> $text{'share_home'}\n",
		$s eq "homes" ? "checked" : "";
	print "</td> </tr>\n";
	}

print "<tr> <td align=right><b>$text{'share_dir'}</b></td>\n";
printf "<td colspan=3><input name=path size=40 value=\"%s\">\n",
	&getval("path");
print &file_chooser_button("path", 1);
print "</td> </tr>\n";

if (!$s) {
	print "<tr> <td align=right><b>$text{'share_create'}</b></td>\n";
	print "<td>",&yesno_input("create"),"</td>\n";

	print "<td align=right><b>$text{'share_owner'}</b></td>\n";
	print "<td>",&ui_user_textbox("createowner", "root"),"</td> </tr>\n";

	print "<tr> <td align=right><b>$text{'share_createperms'}</b></td>\n";
	print "<td>",&ui_textbox("createperms", "755", 5),"</td>\n";

	print "<td align=right><b>$text{'share_group'}</b></td>\n";
	print "<td>",&ui_group_textbox("creategroup", "root"),"</td> </tr>\n";
}

print "<tr> <td align=right><b>$text{'share_available'}</b></td>\n";
print "<td>",&yesno_input("available"),"</td>\n";

print "<td align=right><b>$text{'share_browseable'}</b></td>\n";
print "<td>",&yesno_input("browseable"),"</td> </tr>\n";

print "<td align=right><b>$text{'share_comment'}</b></td>\n";
printf "<td colspan=3><input size=40 name=comment value=\"%s\"></td> </tr>\n",
	&getval("comment");

print "<tr> <td colspan=4 align=center>$text{'share_samedesc2'}</td> </tr>\n"
	if ($s eq "global");

print "</table> </td></tr></table><p>\n";
if ($s eq "global") {
	print "<input type=submit value=$text{'save'}> </form>\n";
	}
elsif ($s) {
	print "<table width=100%> <tr>\n";
	print "<td align=left><input type=submit value=$text{'save'}></td>\n"
		if &can('rw', \%access, $s);
	print "</form><form action=view_users.cgi>\n";
	print "<input type=hidden name=share value=\"$s\">\n";
	print "<td align=center><input type=submit value=\"$text{'share_view'}\"></td>\n"
		if &can('rv', \%access, $s);
	print "</form><form action=delete_share.cgi>\n";
	print "<input type=hidden name=share value=\"$s\">\n";
	print "<input type=hidden name=type value=fshare>\n";
	print "<td align=right><input type=submit value=$text{'delete'}></td>\n"
		if &can('rw', \%access, $s);
	print "</form> </tr> </table>\n";
	}
else {
	print "<input type=submit value=$text{'create'}> </form>\n";
	}

if ($s) {
	# Icons for other share options
	$us = "share=".&urlize($s);
	local (@url, @text, @icon, $disp);
	if (&can('rs',\%access, $s)) {
		push(@url,  "edit_sec.cgi?$us");
		push(@text, $text{'share_security'});
		push(@icon, "images/icon_2.gif");
		$disp++;
		}
	if (&can('rp',\%access, $s)) {
		push(@url,  "edit_fperm.cgi?$us");
		push(@text, $text{'share_permission'});
		push(@icon, "images/icon_7.gif");
		$disp++;
		}
	if (&can('rn',\%access, $s)) {
		push(@url,  "edit_fname.cgi?$us");
		push(@text, $text{'share_naming'});
		push(@icon, "images/icon_8.gif");
		$disp++;
		}
	if (&can('ro',\%access, $s)) {
		push(@url,  "edit_fmisc.cgi?$us");
		push(@text, $text{'share_misc'});
		push(@icon, "images/icon_4.gif");
		$disp++;
		}
	if ($disp) {
		print &ui_hr();
		print &ui_subheading($text{'share_option'});
		&icons_table(\@url, \@text, \@icon);
		}
	}

&ui_print_footer("", $text{'index_sharelist'});

