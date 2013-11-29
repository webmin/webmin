#!/usr/local/bin/perl
# edit_hostsentry.cgi
# Display hostsentry options

require './sentry-lib.pl';
&ui_print_header(undef, $text{'hostsentry_title'}, "", "hostsentry", 0, 0, undef,
	&help_search_link("hostsentry", "man", "doc"));

if (!-r $config{'hostsentry'}) {
	print "<p>",&text('hostsentry_ecommand',
			  "<tt>$config{'hostsentry'}</tt>", 
			  "$gconfig{'webprefix'}/config.cgi?$module_name"),"<p>\n";
	&ui_print_footer("", $text{'index_return'});
	exit;
	}

# Show configuration form
$conf = &get_hostsentry_config();

print "<form action=save_hostsentry.cgi method=post>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'hostsentry_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

# Show wtmp file
print "<tr> <td><b>$text{'hostsentry_wtmp'}</b></td>\n";
printf "<td colspan=3><input name=wtmp size=50 value='%s'> %s</td> </tr>\n",
	&find_value("WTMP_FILE", $conf),
	&file_chooser_button("wtmp");

# Show users to ignore
$ign = &find_value("IGNORE_FILE", $conf);
print "<tr> <td valign=top><b>$text{'hostsentry_ignore'}</b></td>\n";
print "<td colspan=3><textarea name=ignore rows=5 cols=40>";
open(IGN, $ign);
while(<IGN>) {
	s/#.*$//;
	s/\r|\n//g;
	print &html_escape($_),"\n" if (/\S/);
	}
close(IGN);
print "</textarea></td> </tr>\n";

# Show configured modules
$mods = &find_value("MODULE_FILE", $conf);
open(MODS, $mods);
while(<MODS>) {
	s/\r|\n//g;
	s/#.*$//;
	push(@mods, $_) if (/\S/);
	}
close(MODS);
@allmods = &list_hostsentry_modules($conf);
print "<tr> <td valign=top><b>$text{'hostsentry_mods'}</b></td>\n";
print "<td colspan=3 nowrap>\n";
for($i=0; $i<@allmods || $i<@mods; $i++) {
	print $i+1,". ";
	print "<select name=mod_$i>\n";
	printf "<option value='' %s>%s</option>\n",
		$mods[$i] ? "" : "selected", "&nbsp;";
	foreach $a (@allmods) {
		local $t = $text{'mod_'.$a};
		printf "<option value=%s %s>%s</option>\n",
			$a, $mods[$i] eq $a ? "selected" : "",
			$t ? $t : $a;
		}
	print "<option selected>$mods[$i]</option>\n"
		if ($mods[$i] && &indexof($mods[$i], @allmods) < 0);
	print "</select>\n";
	print "<br>\n" if ($i%2);
	print "&nbsp;&nbsp;" if (!($i%2));
	}
print "</td> </tr>\n";

# Show module-specific options
print "</table><table width=100%>\n";
print "<tr>\n";
$basedir = &get_hostsentry_dir();
if (&indexof("moduleForeignDomain", @mods) >= 0) {
	print "<td valign=top colspan=2 width=50%><b>$text{'hostsentry_foreign'}</b><br>\n";
	print "<textarea name=foreign rows=5 cols=30>";
	open(FOREIGN, "$basedir/moduleForeignDomain.allow");
	while(<FOREIGN>) {
		s/\r|\n//g;
		s/#.*$//;
		print &html_escape($_),"\n" if (/\S/);
		}
	close(FOREIGN);
	print "</textarea></td>\n";
	}
if (&indexof("moduleMultipleLogins", @mods) >= 0) {
	print "<td valign=top colspan=2 width=50%><b>$text{'hostsentry_multiple'}</b><br>\n";
	print "<textarea name=multiple rows=5 cols=30>";
	open(MULTIPLE, "$basedir/moduleMultipleLogins.allow");
	while(<MULTIPLE>) {
		s/\r|\n//g;
		s/#.*$//;
		print &html_escape($_),"\n" if (/\S/);
		}
	close(MULTIPLE);
	print "</textarea></td>\n";
	}
print "</tr>\n";

print "</table></td></tr></table>\n";

$pid = &get_hostsentry_pid();
if ($pid) {
	print "<input type=submit name=apply value='$text{'hostsentry_save'}'></form>\n";
	}
else {
	print "<input type=submit value='$text{'save'}'></form>\n";
	}

# Show start/stop buttons
print &ui_hr();
print "<table width=100%>\n";
$cmd = &hostsentry_start_cmd();
if ($pid) {
	# Running .. offer to stop
	print "<form action=stop_hostsentry.cgi>\n";
	print "<tr> <td><input type=submit ",
	      "value='$text{'hostsentry_stop'}'></td>\n";
	print "<td>$text{'hostsentry_stopdesc'}</td> </tr>\n";
	print "</form>\n";
	}
else {
	# Not running .. offer to start
	print "<form action=start_hostsentry.cgi>\n";
	print "<tr> <td><input type=submit ",
	      "value='$text{'hostsentry_start'}'></td>\n";
	print "<td>",&text('hostsentry_startdesc', "<tt>$cmd</tt>"),
	      "</td> </tr> </form>\n";
	}
print "</table>\n";

&ui_print_footer("", $text{'index_return'});

