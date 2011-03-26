#!/usr/bin/perl
# Show a form for exporting a log in WELF format

require './itsecur-lib.pl';
&can_edit_error("report");
&ReadParse();
&header($text{'welf_title'}, "",
	undef, undef, undef, undef, &apply_button());
print "<hr>\n";

print "<form action=welf.cgi/logs.welf method=post>\n";
foreach $i (keys %in) {
	print "<input type=hidden name=$i value='",
	      &html_escape($in{$i}),"'>\n";
	}

print "<table border>\n";
print "<tr $tb> <td><b>$text{'welf_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";

# Show destination
($mode, @dest) = &parse_backup_dest($config{'welf_dest'});
print "<tr> <td valign=top><b>$text{'welf_dest'}</b></td>\n";
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

print "</table></td></tr></table>\n";
print "<input type=submit value='$text{'welf_ok'}'></form>\n";

print "<hr>\n";
&footer("", $text{'index_return'});

