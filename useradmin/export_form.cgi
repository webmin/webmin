#!/usr/local/bin/perl
# export_form.cgi
# Display a form for exporting a batch file

require './user-lib.pl';
$access{'export'} || &error($text{'export_ecannot'});
&ui_print_header(undef, $text{'export_title'}, "", "export");

print "$text{'export_desc'}<p>\n";
print "<form action=export_exec.cgi>\n";
print "<table>\n";

print "<tr> <td valign=top><b>$text{'export_to'}</b></td> <td valign=top>\n";
if ($access{'export'} == 2) {
	print "<input type=radio name=to value=0 checked> $text{'export_show'}<br>\n";
	print "<input type=radio name=to value=1> $text{'export_file'}\n";
	print "<input name=file size=30> ",&file_chooser_button("file"),"</td> </tr>\n";
	}
else {
	print "$text{'export_show'}</td> </tr>\n";
	}

$pft = &passfiles_type();
print "<tr> <td valign=top><b>$text{'export_pft'}</b></td> <td valign=top>\n";
print "<select name=pft>\n";
foreach $k (sort { $a cmp $b } keys %text) {
	next if ($k !~ /^pft_(\d+)$/ || $done{$text{$k}}++);
	printf "<option value=%d %s> %s<br>\n",
		$1, $1 == $pft ? "selected" : "", $text{$k};
	}
print "</select></td> </tr>\n";

print "<tr> <td valign=top><b>$text{'export_who'}</b></td> <td valign=top>\n";
print "<input type=radio name=mode value=0 checked> $text{'acl_uedit_all'}<br>\n";
print "<input type=radio name=mode value=2> $text{'acl_uedit_only'}\n";
printf "<input name=can size=40> %s<br>\n",
	&user_chooser_button("can", 1);
print "<input type=radio name=mode value=3> $text{'acl_uedit_except'}\n";
printf "<input name=cannot size=40> %s<br>\n",
	&user_chooser_button("cannot", 1);

print "<input type=radio name=mode value=4> $text{'acl_uedit_uid'}\n";
print "<input name=uid size=6> - \n";
print "<input name=uid2 size=6><br>\n";

print "<input type=radio name=mode value=5> $text{'acl_uedit_group'}\n";
printf "<input name=group size=40> %s<br>\n",
	&group_chooser_button("group", 1);
printf "%s <input type=checkbox name=sec value=1> %s<br>\n",
	"&nbsp;" x 5, $text{'acl_uedit_sec'};

print "<input type=radio name=mode value=8> $text{'acl_uedit_gid'}\n";
print "<input name=gid size=6> - \n";
print "<input name=gid2 size=6><br>\n";
print "</td> </tr>\n",

print "<tr> <td><input type=submit value=\"$text{'export_ok'}\"></td> </tr>\n";
print "</table></form>\n";

&ui_print_footer("", $text{'index_return'});

