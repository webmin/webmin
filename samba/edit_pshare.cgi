#!/usr/local/bin/perl
# edit_pshare.cgi
# Display a form for editing or creating a new printer share

require './samba-lib.pl';
&ReadParse();
$s = $in{'share'};
# check acls
%access = &get_module_acl();
&error_setup("<blink><font color=red>$text{'eacl_aviol'}</font></blink>");
if(!$s) {
	&error("$text{'eacl_np'} $text{'eacl_pcps'}")
        unless $access{'c_ps'};
	}
else {
	&error("$text{'eacl_np'} $text{'eacl_paps'}")
        unless &can('r', \%access, $in{'share'});
	}
# display
if ($s) {
	&ui_print_header(undef, $s eq 'global' ? $text{'pshare_title1'} : $text{'pshare_title2'}, "");
	&get_share($s);
	}
else {
	&ui_print_header(undef, $text{'pshare_title3'}, "");
	}

print "<form action=save_pshare.cgi>\n";
if ($s) { print "<input type=hidden name=old_name value=\"$s\">\n"; }

# Vital share options..
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'pshare_info'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";
if ($s ne "global") {
	if ($copy = &getval("copy")) {
		print "<tr> <td colspan=4><b>", &text('share_copy',$copy),"</b></td> </tr>\n";
		}
	print "<tr> <td><b>$text{'pshare_name'}</b></td>\n";
	printf "<td colspan=3><input type=radio name=printers value=0 %s>\n",
		$s eq "printers" ? "" : "checked";
	printf "<input size=10 name=share value=\"%s\">&nbsp;&nbsp;&nbsp;\n",
		$s eq "printers" ? "" : $s;
	printf "<input type=radio name=printers value=1 %s> $text{'pshare_all'}\n",
		$s eq "printers" ? "checked" : "";
	print "</td> </tr>\n";
	}

print "<tr> <td><b>$text{'pshare_unixprn'}</b></td>\n";
if (&foreign_check("lpadmin")) {
	&foreign_require("lpadmin", "lpadmin-lib.pl");
	@plist = &foreign_call("lpadmin", "list_printers");
	}
elsif ($config{'list_printers_command'}) {
	@plist = split(/\s+/ , `$config{'list_printers_command'}`);
	}
if (@plist) {
	local $printer = &getval("printer");
	push(@plist, $printer)
		if ($printer && &indexof($printer, @plist) == -1);
	print "<td><select name=printer>\n";
	printf "<option value=\"\" %s> %s\n",
		$printer eq "" ? "selected" : "",
		$s eq "global" ? $text{'config_none'} : $text{'default'};
	foreach $p (@plist) {
		printf "<option value=\"$p\" %s> $p\n",
			$p eq $printer ? "selected" : "";
		}
	print "</select></td>\n";
	}
else {
	print "<td><input name=printer size=8></td>\n";
	}

print "<td><b>$text{'pshare_spool'}</b></td>\n";
printf "<td><input name=path size=35 value=\"%s\">\n",
	&getval("path");
print &file_chooser_button("path", 1);
print "</td> </tr>\n";

print "<tr> <td><b>$text{'share_available'}</b></td>\n";
print "<td>",&yesno_input("available"),"</td>\n";

print "<td><b>$text{'share_browseable'}</b></td>\n";
print "<td>",&yesno_input("browseable"),"</td> </tr>\n";

print "<td align=right><b>$text{'share_comment'}</b></td>\n";
printf "<td colspan=3 align=left>\n";
printf "<input size=40 name=comment value=\"%s\"></td> </tr>\n",
	&getval("comment");

print "<tr> <td colspan=4 align=center>$text{'share_samedesc1'}</td> </tr>\n"
	if ($s eq "global");

print "</table> </td></tr></table><p>\n";

if ($s eq "global") {
	print "<input type=submit value=$text{'save'}> </form><p>\n";
	}
elsif ($s) {
	print "<table width=100%> <tr>\n";
	print "<td align=left><input type=submit value=$text{'save'}></td>\n"
		if &can('rw', \%access, $s);
	print "</form><form action=view_users.cgi>\n";
	print "<input type=hidden name=share value=\"$s\">\n";
	print "<input type=hidden name=printer value=1>\n";
	print "<td align=center><input type=submit value=\"$text{'index_view'}\"></td>\n"
		if &can('rv', \%access, $s);
	print "</form><form action=delete_share.cgi>\n";
	print "<input type=hidden name=share value=\"$s\">\n";
	print "<input type=hidden name=type value=pshare>\n";
	print "<td align=right><input type=submit value=$text{'delete'}></td>\n"
		if &can('rw', \%access, $s);
	print "</form> </tr> </table> <p>\n";
	}
else {
	print "<input type=submit value=$text{'create'}> </form><p>\n";
	}

if ($s) {
	# Icons for other share options
    $us = "share=".&urlize($s)."&printer=1";
    local (@url, @text, @icon, $disp);
    if (&can('rs',\%access, $s)) {
        push(@url,  "edit_sec.cgi?$us");
        push(@text, $text{'share_security'});
        push(@icon, "images/icon_2.gif");
        $disp++;
        }
    if (&can('ro',\%access, $s)) {
        push(@url,  "edit_popts.cgi?$us");
        push(@text, $text{'print_option'});
        push(@icon, "images/icon_3.gif");
        $disp++;
        }
    if ($disp) {
        print "<hr>\n";
        print &ui_subheading($text{'share_option'});
        &icons_table(\@url, \@text, \@icon);
        }
	}

&ui_print_footer("", $text{'index_sharelist'});
