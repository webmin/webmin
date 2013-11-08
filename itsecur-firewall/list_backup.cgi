#!/usr/bin/perl
# Show a form for backing up some or all firewall objects

require './itsecur-lib.pl';
&can_edit_error("backup");
&check_zip();
&header($text{'backup_title'}, "",
	undef, undef, undef, undef, &apply_button());
print "<hr>\n";

print "<form action=backup.cgi/firewall.zip method=post>\n";
print "<table border>\n";
print "<tr $tb> <td><b>$text{'backup_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";

# Show destination
($mode, @dest) = &parse_backup_dest($config{'backup_dest'});
print "<tr> <td valign=top><b>$text{'backup_dest'}</b></td>\n";
print "<td><table cellpadding=0 cellspacing=0>\n";
printf "<tr> <td><input type=radio name=dest_mode value=0 %s></td> <td>%s</td> </tr>\n",
	$mode == 0 ? "checked" : "", $text{'backup_dest0'};

printf "<tr> <td><input type=radio name=dest_mode value=1 %s></td> <td>%s</td>\n",
	$mode == 1 ? "checked" : "", $text{'backup_dest1'};
printf "<td colspan=3><input name=dest size=40 value='%s'> %s</td> </tr>\n",
	$mode == 1 ? $dest[0] : "", &file_chooser_button("dest");

printf "<tr> <td><input type=radio name=dest_mode value=3 %s></td> <td>%s</td>\n",
	$mode == 3 ? "checked" : "", $text{'backup_dest3'};
printf "<td colspan=3><input name=email size=40 value='%s'></td> </tr>\n",
	$mode == 3 ? $dest[0] : "";

printf "<tr> <td><input type=radio name=dest_mode value=2 %s></td>\n",
	$mode == 2 ? "checked" : "";
printf "<td>%s</td> <td><input name=ftphost size=20 value='%s'></td>\n",
	$text{'backup_dest2'}, $mode == 2 ? $dest[2] : "";
printf "<td>%s</td> <td><input name=ftpfile size=20 value='%s'></td> </tr>\n",
	$text{'backup_ftpfile'}, $mode == 2 ? $dest[3] : "";
printf "<tr> <td></td> <td>%s</td> <td><input name=ftpuser size=15 value='%s'></td>\n",
	$text{'backup_ftpuser'}, $mode == 2 ? $dest[0] : "";
printf "<td>%s</td> <td><input name=ftppass type=password size=15 value='%s'></td> </tr>\n",
	$text{'backup_ftppass'}, $mode == 2 ? $dest[1] : "";
print "</table></td> </tr>\n";

# Show password
print "<tr> <td valign=top><b>$text{'backup_pass'}</b></td> <td>\n";
printf "<input type=radio name=pass_def value=1 %s> %s\n",
	$config{'backup_pass'} ? "" : "checked", $text{'backup_nopass'};
printf "<input type=radio name=pass_def value=0 %s>\n",
	$config{'backup_pass'} ? "checked" : "";
printf "<input type=password name=pass value='%s'></td> </tr>\n",
	$config{'backup_pass'};

# Show what to backup
%what = map { $_, 1 } split(/\s+/, $config{'backup_what'});
print "<tr> <td valign=top><b>$text{'backup_what'}</b></td> <td>\n";
foreach $w (@backup_opts) {
	printf "<input type=checkbox name=what value=%s %s> %s<br>\n",
		$w, $what{$w} ? "checked" : "", $text{$w."_title"};
	}
if (defined(&select_all_link)) {
	print &select_all_link("what", 0),"\n";
	print &select_invert_link("what", 0),"\n";
	}
print "</td> </tr>\n";

# Show schedule
$job = &find_backup_job();
print "<tr> <td valign=top><b>$text{'backup_sched'}</b></td> <td>\n";
printf "<input type=radio name=sched_def value=1 %s> %s\n",
	$job ? "" : "checked", $text{'backup_nosched'};
printf "<input type=radio name=sched_def value=0 %s> %s\n",
	$job ? "checked" : "", $text{'backup_interval'};
print "<select name=sched>\n";
foreach $s ("hourly", "daily", "weekly", "monthly", "yearly") {
	printf "<option value=%s %s>%s</option>\n",
		$s, $job && $job->{'special'} eq $s ? "selected" : "",
		ucfirst($s);
	}
print "</select></td> </tr>\n";

print "</table></td></tr></table>\n";
print "<input type=submit value='$text{'backup_ok'}'>\n";
print "<input type=submit name=save value='$text{'backup_save'}'></form>\n";

print "<hr>\n";
&footer("", $text{'index_return'});

