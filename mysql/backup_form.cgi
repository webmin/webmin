#!/usr/local/bin/perl
# backup_form.cgi
# Display a form for backing up this database, or all databases

require './mysql-lib.pl';
&ReadParse();
if ($in{'all'}) {
	@alldbs = &list_databases();
	@dbs = grep { &can_edit_db($_) } @alldbs;
	@alldbs == @dbs || &error($text{'dbase_ecannot'});
	}
else {
	&can_edit_db($in{'db'}) || &error($text{'dbase_ecannot'});
	}
$access{'edonly'} && &error($text{'dbase_ecannot'});
$access{'buser'} || &error($text{'dbase_ecannot'});
&ui_print_header(undef, $in{'all'} ? $text{'backup_title2'} : $text{'backup_title'}, "",
	"backup_form");

if (!-x $config{'mysqldump'}) {
	print &text('backup_edump', "<tt>$config{'mysqldump'}</tt>",
			  "$gconfig{'webprefix'}/config.cgi?$module_name"),"<p>\n";
	&ui_print_footer("edit_dbase.cgi?db=$in{'db'}", $text{'dbase_return'});
	exit;
	}

$cron = !$module_info{'usermin'} && $access{'buser'} eq 'root' &&
	!$access{'user'} && &foreign_installed("cron");
if ($in{'all'}) {
	print "$text{'backup_desc3'}\n";
	}
else {
	print &text('backup_desc', "<tt>$in{'db'}</tt>"),"\n";
	}
if ($cron) {
	print "$text{'backup_desc2'}\n";
	}
print "<p>\n";
%c = $module_info{'usermin'} ? %userconfig : %config;

print "<form action=backup_db.cgi>\n";
print "<input type=hidden name=db value='$in{'db'}'>\n";
print "<input type=hidden name=all value='$in{'all'}'>\n";
print "<table border>\n";
print "<tr $tb> <td><b>$text{'backup_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";

if ($in{'all'}) {
	print "<tr> <td><b>$text{'backup_file2'}</td>\n";
	}
else {
	print "<tr> <td><b>$text{'backup_file'}</td>\n";
	}
printf "<td><input name=file size=40 value='%s'> %s</td> </tr>\n",
	$c{'backup_'.$in{'db'}}, &file_chooser_button("file");

if (!$in{'all'}) {
	# Show input to select tables
	$t = $c{'backup_tables_'.$in{'db'}};
	print "<tr> <td valign=top><b>$text{'backup_tables'}</b></td> <td>\n";
	printf "<input type=radio name=tables_def value=1 %s> %s\n",
		$t ? "" : "checked", $text{'backup_alltables'};
	printf "<input type=radio name=tables_def value=0 %s> %s<br>\n",
		$t ? "checked" : "", $text{'backup_seltables'};
	@tables = &list_tables($in{'db'});
	%got = map { $_, 1 } split(/\s+/, $t);
	print "<select name=tables multiple size=5>\n";
	foreach $t (sort @tables) {
		printf "<option %s>%s\n",
			$got{$t} ? "selected" : "", $t;
		}
	print "</select></td> </tr>\n";
	}

# Show input for where clause
$w = $c{'backup_where_'.$in{'db'}};
print "<tr> <td><b>$text{'backup_where'}</b></td>\n";
print "<td>",&ui_opt_textbox("where", $w, 30, $text{'backup_none'}),
      "</td> </tr>\n";

# Show option to include drop statements in SQL
$d = $c{'backup_drop_'.$in{'db'}};
print "<tr> <td><b>$text{'backup_drop'}</b></td>\n";
print "<td>",&ui_yesno_radio("drop", $d ? 1 : 0),"</td> </tr>\n";

# Show input for character set
$s = $c{'backup_charset_'.$in{'db'}};
print "<tr> <td><b>$text{'backup_charset'}</b></td>\n";
print "<td>",&ui_radio("charset_def", $s ? 0 : 1,
	       [ [ 1, $text{'default'} ],
		 [ 0, &ui_select("charset", $s,
			[ &list_character_sets($in{'db'}) ]) ] ]),
      "</td> </tr>\n";

if ($mysql_version >= 5.0) {
	# Show compatability format option
	$cf = $c{'backup_compatible_'.$in{'db'}};
	print "<tr> <td><b>$text{'backup_compatible'}</b></td>\n";
	print "<td>",&ui_radio("compatible_def", $cf ? 0 : 1,
		       [ [ 1, $text{'default'} ],
			 [ 0, &text('backup_compwith',
				&ui_select("compatible", $cf,
				   [ &list_compatible_formats() ])) ] ]),
	      "</td> </tr>\n";

	%co = map { $_, 1 } split(/\s+/, $c{'backup_options_'.$in{'db'}});
	print "<tr> <td valign=top><b>$text{'backup_options'}</b></td> <td>\n";
	foreach $o (&list_compatible_options()) {
		print &ui_checkbox("options", $o->[0], $o->[1] || $o->[0],
				   $co{$o->[0]}),"<br>\n";
		}
	print "</td> </tr>\n";
	}
else {
	print &ui_hidden("compatible_def", 1),"\n";
	}

# Show compression option
$cp = int($c{'backup_compress_'.$in{'db'}});
print "<tr> <td><b>$text{'backup_compress'}</b></td>\n";
print "<td>",&ui_radio("compress", $cp,
		[ [ 0, $text{'backup_cnone'} ],
		  [ 1, $text{'backup_gzip'} ],
		  [ 2, $text{'backup_bzip2'} ] ]),"</td> </tr>\n";

if ($cron) {
	# Show before/after commands
	$b = $c{'backup_before_'.$in{'db'}};
	print "<tr> <td><b>$text{'backup_before'}</b></td>\n";
	printf "<td><input name=before size=50 value='%s'></td> </tr>\n", $b;

	$a = $c{'backup_after_'.$in{'db'}};
	print "<tr> <td><b>$text{'backup_after'}</b></td>\n";
	printf "<td><input name=after size=50 value='%s'></td> </tr>\n", $a;

	if ($in{'all'}) {
		# Command mode option
		$cmode = $c{'backup_cmode_'.$in{'db'}};
		print "<tr> <td><b>$text{'backup_cmode'}</b></td>\n";
		print "<td>",&ui_radio("cmode", int($cmode),
			[ [ 0, $text{'backup_cmode0'} ],
			  [ 1, $text{'backup_cmode1'} ] ]),"</td> </tr>\n";
		}

	# Show cron time
	&foreign_require("cron", "cron-lib.pl");
	@jobs = &cron::list_cron_jobs();
	$cmd = $in{'all'} ? "$cron_cmd --all" : "$cron_cmd $in{'db'}";
	($job) = grep { $_->{'command'} eq $cmd } @jobs;

	print "<tr> <td><b>$text{'backup_sched'}</b></td>\n";
	printf "<td><input type=radio name=sched value=0 %s> %s\n",
		$job ? "" : "checked", $text{'no'};
	printf "<input type=radio name=sched value=1 %s> %s</td> </tr>\n",
		$job ? "checked" : "", $text{'backup_sched1'};

	print "<tr> <td colspan=2><table border width=100%>\n";
	$job ||= { 'mins' => 0,
		   'hours' => 0,
		   'days' => '*',
		   'months' => '*',
		   'weekdays' => '*' };
	&cron::show_times_input($job);
	print "</table></td> </tr>\n";
	}
print "</table></td></tr></table>\n";

if ($cron) {
	print "<input type=submit name=backup value='$text{'backup_ok1'}'>\n";
	print "<input type=submit name=save value='$text{'backup_ok2'}'>\n";
	}
else {
	print "<input type=submit name=backup value='$text{'backup_ok'}'>\n";
	}
print "<br>\n";
print "</form>\n";

if ($in{'all'}) {
	&ui_print_footer("", $text{'index_return'});
	}
else {
	&ui_print_footer("edit_dbase.cgi?db=$in{'db'}", $text{'dbase_return'},
		"", $text{'index_return'});
	}

