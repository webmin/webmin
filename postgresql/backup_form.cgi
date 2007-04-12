#!/usr/local/bin/perl
# backup_form.cgi
# Display a form for backup the database

require './postgresql-lib.pl' ;
&ReadParse();
&error_setup ( $text{'backup_err'} ) ;
if ($in{'all'}) {
	@alldbs = &list_databases();
	@dbs = grep { &can_edit_db($_) } @alldbs;
	@alldbs == @dbs || &error($text{'dbase_ecannot'});
	}
else {
	&can_edit_db($in{'db'}) || &error($text{'dbase_ecannot'});
	}
$access{'backup'} || &error($text{'backup_ecannot'});

&has_command($config{'dump_cmd'}) ||
	&error(&text('backup_ecmd', "<tt>$config{'dump_cmd'}</tt>"));

$desc = "<tt>$in{'db'}</tt>";
&ui_print_header($desc, $in{'all'} ? $text{'backup_title2'}
		   : $text{'backup_title'}, "", "backup_form" ) ;

$cron = !$module_info{'usermin'} &&
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

print "<form action=backup.cgi method=post>\n" ;
print "<input type=hidden name=db value=\"$in{'db'}\">\n" ;
print "<input type=hidden name=all value=\"$in{'all'}\">\n" ;
print "<table border>\n" ;
print "<tr $tb> <td><b>$text{'backup_header'}</b></td> </tr>\n" ;
print "<tr $cb> <td><table>\n" ;

$p = $c{'backup_'.$in{'db'}} || "$config{'repository'}/";
if ($in{'all'}) {
	print "<tr> <td><b>$text{'backup_path2'}</b></td>\n" ;
	}
else {
	print "<tr> <td><b>$text{'backup_path'}</b></td>\n" ;
	}
print "<td><input type=text name=path value='$p' size=64></td></tr>\n" ;

# Show backup format input
$f = $c{'backup_format_'.$in{'db'}};
print "<tr> <td><b>$text{'backup_format'}</b></td>\n";
print "<td><select name=format>\n";
foreach $t ('p', 't', 'c') {
	printf "<option value=%s %s>%s\n",
		$t, $f eq $t ? "selected" : "", $text{'backup_format_'.$t};
	}
print "</select></td> </tr>\n";

if (!$in{'all'}) {
	# Show input to select tables
	$t = $c{'backup_tables_'.$in{'db'}};
	print "<tr> <td valign=top><b>$text{'backup_tables'}</b></td> <td>\n";
	printf "<input type=radio name=tables_def value=1 %s> %s\n",
		$t ? "" : "checked", $text{'backup_alltables'};
	printf "<input type=radio name=tables_def value=0 %s> %s\n",
		$t ? "checked" : "", $text{'backup_seltables'};
	@tables = &list_tables($in{'db'});
	%got = map { $_, 1 } split(/\s+/, $t);
	print "<select name=tables>\n";
	foreach $t (sort @tables) {
		printf "<option %s>%s\n",
			$got{$t} ? "selected" : "", $t;
		}
	print "</select></td> </tr>\n";
	}

if ($cron) {
	if ($access{'cmds'}) {
		$b = $c{'backup_before_'.$in{'db'}};
		print "<tr> <td><b>$text{'backup_before'}</b></td>\n";
		print "<td>",&ui_textbox("before", $b, 50),"</td> </tr>\n";

		$a = $c{'backup_after_'.$in{'db'}};
		print "<tr> <td><b>$text{'backup_after'}</b></td>\n";
		print "<td>",&ui_textbox("after", $a, 50),"</td> </tr>\n";

		if ($in{'all'}) {
			# Command mode option
			$a = $c{'backup_cmode_'.$in{'db'}};
			print "<tr> <td><b>$text{'backup_cmode'}</b></td>\n";
			print "<td>",&ui_radio("cmode", int($cmode),
				[ [ 0, $text{'backup_cmode0'} ],
				  [ 1, $text{'backup_cmode1'} ] ]),
			      "</td> </tr>\n";
			}
                }

	&foreign_require("cron", "cron-lib.pl");
	@jobs = &cron::list_cron_jobs();
	$cmd = $in{'all'} ? "$cron_cmd --all" : "$cron_cmd $in{'db'}";
	($job) = grep { $_->{'command'} eq $cmd } @jobs;

	print "<tr> <td><b>$text{'backup_sched'}</b></td>\n";
	printf "<td><input type=radio name=sched value=0 %s> %s\n",
		$job ? "" : "checked", $text{'no'};
	printf "<input type=radio name=sched value=1 %s> %s</td> </tr>\n",
		$job ? "checked" : "", $text{'backup_sched1'};

	if (!$config{'simple_sched'} || ($dump && !$dump->{'special'})) {
		# Complex Cron time input
		print "<tr> <td colspan=2><table border width=100%>\n";
		$job ||= { 'mins' => 0,
			   'hours' => 0,
			   'days' => '*',
			   'months' => '*',
			   'weekdays' => '*' };
		&cron::show_times_input($job);
		print "</table></td> </tr>\n";
		}
	else {
		# Simple Cron time input
		$job ||= { 'special' => 'daily' };
		print &ui_hidden("special_def", 1),"\n";
		print "<tr> <td><b>$text{'backup_special'}</b></td>\n";
		print "<td>",&ui_select("special", $job->{'special'},
			[ map { [ $_, $cron::text{'edit_special_'.$_} ] }
		          ('hourly', 'daily', 'weekly', 'monthly', 'yearly') ]),
		      "</td> </tr>\n";
		}
	}
print "</table></td></tr></table>\n" ;

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


