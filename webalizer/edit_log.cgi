#!/usr/local/bin/perl
# edit_log.cgi
# Display a form for adding a new logfile or editing an existing one.
# Allows you to set the schedule on which the log is analysed

require './webalizer-lib.pl';
&foreign_require("cron", "cron-lib.pl");
&ReadParse();
$access{'view'} && &error($text{'edit_ecannot'});
if ($in{'new'}) {
	$access{'add'} || &error($text{'edit_ecannot'});
	&ui_print_header(undef, $text{'edit_title1'}, "");
	}
else {
	&can_edit_log($in{'file'}) || &error($text{'edit_ecannot'});
	&ui_print_header(undef, $text{'edit_title2'}, "");
	$lconf = &get_log_config($in{'file'});
	}

print "<form action=save_log.cgi>\n";
print "<input type=hidden name=new value='$in{'new'}'>\n";
print "<input type=hidden name=oldfile value='$in{'file'}'>\n";

print "<table border width=100% class='ui_table'>\n";
print "<tr $tb> <td><b>$text{'edit_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td><b>$text{'edit_file'}</b></td> <td colspan=3>\n";
if ($in{'new'}) {
	print "<input name=file size=50> ",&file_chooser_button("file");
	}
else {
	print "<input type=hidden name=file value='$in{'file'}'>\n";
	print "<tt>$in{'file'}</tt>";
	}
print "</td> </tr>\n";

if (!$in{'new'}) {
	@all = &all_log_files($in{'file'});
	if (@all > 1) {
		print "<tr> <td valign=top><b>$text{'edit_files'}</b></td> ",
		      "<td colspan=3><font size=-1>\n";
		foreach $a (@all) {
			print "$a<br>\n";
			}
		print "</font></td> </tr>\n";
		}
	}

print "<tr> <td><b>$text{'edit_type'}</b></td> <td>\n";
if ($in{'new'}) {
	print "<select name=type>\n";
	for($i=1; defined($t = $text{'index_type'.$i}); $i++) {
		print "<option value=$i>$t</option>\n";
		}
	print "</select>\n";
	}
else {
	print "<input type=hidden name=type value='$in{'type'}'>\n";
	print $text{'index_type'.$in{'type'}};
	}
print "</td>\n";

print "<tr> <td><b>$text{'edit_dir'}</b></td> <td colspan=3>\n";
printf "<input name=dir size=50 value='%s'> %s</td> </tr>\n",
	$lconf->{'dir'}, &file_chooser_button("dir", 1);

print "<tr> <td><b>$text{'edit_user'}</b></td>\n";
if ($access{'user'} eq '*') {
	# User that webalizer runs as can be chosen
	printf "<td><input name=user size=13 value='%s'> %s</td> </tr>\n",
		$lconf->{'user'} || "root";
	}
else {
	# User is fixed
	printf "<td><tt>%s</tt></td> </tr>\n",
		!$in{'new'} && $lconf->{'dir'} ? $lconf->{'user'} || "root" :
		$access{'user'} eq "" ? $remote_user : $access{'user'};
	}

print "<tr> <td><b>$text{'edit_over'}</b></td>\n";
printf "<td><input type=radio name=over value=1 %s> %s\n",
	$lconf->{'over'} ? "checked" : "", $text{'yes'};
printf "<input type=radio name=over value=0 %s> %s</td> </tr>\n",
	$lconf->{'over'} ? "" : "checked", $text{'no'};

$cfile = &config_file_name($in{'file'});
$cmode = -l $cfile ? 2 : -r $cfile ? 1 : 0;
print "<tr> <td><b>$text{'edit_conf'}</b></td> <td nowrap>\n";
printf "<input type=radio name=cmode value=0 %s> %s\n",
	$cmode == 0 ? "checked" : "", $text{'edit_cmode0'};
printf "<input type=radio name=cmode value=1 %s> %s\n",
	$cmode == 1 ? "checked" : "", $text{'edit_cmode1'};
printf "<input type=radio name=cmode value=2 %s> %s\n",
	$cmode == 2 ? "checked" : "", $text{'edit_cmode2'};
printf "<input name=cfile size=20 value='%s'> %s</td> </tr>\n",
	$cmode == 2 ? readlink($cfile) : "", &file_chooser_button("cfile");

print "<tr> <td><b>$text{'edit_sched'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=sched value=0 %s> %s\n",
	$lconf->{'sched'} ? "" : "checked", $text{'edit_sched0'};
printf "<input type=radio name=sched value=1 %s> %s</td> </tr>\n",
	$lconf->{'sched'} ? "checked" : "", $text{'edit_sched1'};

print "<tr> <td><b>$text{'edit_clear'}</b></td>\n";
printf "<td><input type=radio name=clear value=1 %s> %s\n",
	$lconf->{'clear'} ? "checked" : "", $text{'yes'};
printf "<input type=radio name=clear value=0 %s> %s</td> </tr>\n",
	$lconf->{'clear'} ? "" : "checked", $text{'no'};

print "</table>\n";

print "<table border width=100%>\n";
if ($lconf->{'mins'} eq '') {
	$lconf->{'mins'} = $lconf->{'hours'} = 0;
	$lconf->{'days'} = $lconf->{'months'} = $lconf->{'weekdays'} = '*';
	}
&foreign_call("cron", "show_times_input", $lconf);

print "</table>\n";
print "</td></tr></table>\n";

if ($in{'new'}) {
	push(@b, "<input type=submit value='$text{'create'}'>");
	}
else {
	push(@b, "<input type=submit value='$text{'save'}'>");
	push(@b, "<input type=submit name=global value='$text{'edit_global'}'>")
		if ($cmode);
	if ($lconf->{'dir'}) {
		push(@b, "<input type=submit name=run value='$text{'edit_run'}'>");
		}
	if ($lconf->{'dir'} && -r "$lconf->{'dir'}/index.html") {
		push(@b, "<input type=submit name=view value='$text{'edit_view'}'>");
		}
	if ($in{'custom'}) {
		push(@b, "<input type=submit name=delete value='$text{'delete'}'>");
		}
	}
&spaced_buttons(@b);
print "</form>\n";

&ui_print_footer("", $text{'index_return'});

