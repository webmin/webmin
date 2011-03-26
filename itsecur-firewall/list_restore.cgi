#!/usr/bin/perl
# Show a form for restoring some or all firewall objects

require './itsecur-lib.pl';
&can_edit_error("restore");
&check_zip();
&header($text{'restore_title'}, "",
	undef, undef, undef, undef, &apply_button());
print "<hr>\n";

($mode, @dest) = &parse_backup_dest($config{'backup_dest'});
print "<form action=restore.cgi enctype=multipart/form-data method=post>\n";
print "<table border>\n";
print "<tr $tb> <td><b>$text{'restore_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";

# Show source
print "<tr> <td valign=top><b>$text{'restore_src'}</b></td> <td>\n";
printf "<input type=radio name=src_def value=1 %s> %s\n",
	$mode != 1 ? "checked" : "", $text{'restore_src1'};
print "<input name=file type=file size=20><br>\n";
printf "<input type=radio name=src_def value=0 %s> %s\n",
	$mode == 1 ? "checked" : "", $text{'restore_src0'};
printf "<input name=src size=40 value='%s'> %s</td> </tr>\n",
	$mode == 1 ? $dest[0] : undef, &file_chooser_button("src");

# Show password
print "<tr> <td valign=top><b>$text{'restore_pass'}</b></td> <td>\n";
printf "<input type=radio name=pass_def value=1 %s> %s\n",
	$config{'backup_pass'} ? "" : "checked", $text{'backup_nopass'};
printf "<input type=radio name=pass_def value=0 %s>\n",
	$config{'backup_pass'} ? "checked" : "";
printf "<input type=password name=pass value='%s'></td> </tr>\n",
	$config{'backup_pass'};

# Show what to restore
%what = map { $_, 1 } split(/\s+/, $config{'backup_what'});
print "<tr> <td valign=top><b>$text{'restore_what'}</b></td> <td>\n";
foreach $w (@backup_opts) {
	printf "<input type=checkbox name=what value=%s %s> %s<br>\n",
		$w, $what{$w} ? "checked" : "", $text{$w."_title"};
	}
if (defined(&select_all_link)) {
	print &select_all_link("what", 0),"\n";
	print &select_invert_link("what", 0),"\n";
	}
print "</td> </tr>\n";

print "</table></td></tr></table>\n";
print "<input type=submit value='$text{'restore_ok'}'></form>\n";

print "<hr>\n";
&footer("", $text{'index_return'});

