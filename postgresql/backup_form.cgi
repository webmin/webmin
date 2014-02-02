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

print &ui_form_start("backup.cgi", "post");
print &ui_hidden("db", $in{'db'});
print &ui_hidden("all", $in{'all'});
print &ui_hidden_table_start($text{'backup_header1'}, "width=100%", 2, "main",
			     1, [ "width=30%" ]);

# Destination file or directory
$p = $c{'backup_'.$in{'db'}} || "$config{'repository'}/";
print &ui_table_row($in{'all'} ? $text{'backup_path2'}
			       : $text{'backup_path'},
	&ui_textbox("path", $p, 60)." ".
	&file_chooser_button("path"));

# Create destination dir
if ($in{'all'}) {
	print &ui_table_row($text{'backup_mkdir'},
		&ui_yesno_radio("mkdir", int($c{'backup_mkdir_'.$in{'db'}})));
	}

# Show backup format input
$f = $c{'backup_format_'.$in{'db'}};
print &ui_table_row($text{'backup_format'},
	&ui_select("format", $f,
		[ [ 'p', $text{'backup_format_p'} ],
		  [ 't', $text{'backup_format_t'} ],
		  [ 'c', $text{'backup_format_c'} ] ]));

if (!$in{'all'}) {
	# Show input to select tables
	$t = $c{'backup_tables_'.$in{'db'}};
	@tables = &list_tables($in{'db'});
	if (@tables) {
		print &ui_table_row($text{'backup_tables'},
			&ui_radio("tables_def", $t ? 0 : 1,
				  [ [ 1, $text{'backup_alltables'} ],
				    [ 0, $text{'backup_seltables'} ] ])."<br>".
			&ui_select("tables", [ split(/\s+/, $t) ],
				   [ sort @tables ], 5, 1));
		}
	else {
		print &ui_hidden("tables_def", 1);
		}
	}

print &ui_hidden_table_end("main");

if ($cron) {
	if ($access{'cmds'}) {
		print &ui_hidden_table_start($text{'backup_header2'},
					     "width=100%", 2,
					     "opts", 0, [ "width=30%" ]);

		$b = $c{'backup_before_'.$in{'db'}};
		print &ui_table_row($text{'backup_before'},
			&ui_textbox("before", $b, 50));

		$a = $c{'backup_after_'.$in{'db'}};
		print &ui_table_row($text{'backup_after'},
			&ui_textbox("after", $a, 50));

		if ($in{'all'}) {
			# Command mode option
			$cmode = $c{'backup_cmode_'.$in{'db'}};
			print &ui_table_row($text{'backup_cmode'},
				&ui_radio("cmode", int($cmode),
					[ [ 0, $text{'backup_cmode0'} ],
					  [ 1, $text{'backup_cmode1'} ] ]));
			}

		print &ui_hidden_table_end("opts");
                }

	print &ui_hidden_table_start($text{'backup_header3'}, "width=100%",
				     2, "sched", 1, [ "width=30%" ]);

	&foreign_require("cron", "cron-lib.pl");
	@jobs = &cron::list_cron_jobs();
	$cmd = $in{'all'} ? "$cron_cmd --all" : "$cron_cmd $in{'db'}";
	($job) = grep { $_->{'command'} eq $cmd } @jobs;

	print &ui_table_row($text{'backup_sched'},
		&ui_radio("sched", $job ? 1 : 0,
		  [ [ 0, $text{'no'} ], [ 1, $text{'backup_sched1'} ] ]));

	if (!$config{'simple_sched'} || ($dump && !$dump->{'special'})) {
		# Complex Cron time input
		$job ||= { 'mins' => 0,
			   'hours' => 0,
			   'days' => '*',
			   'months' => '*',
			   'weekdays' => '*' };
		print &cron::get_times_input($job);
		}
	else {
		# Simple Cron time input
		$job ||= { 'special' => 'daily' };
		print &ui_hidden("special_def", 1),"\n";
		print &ui_table_row($text{'backup_special'},
		    &ui_select("special", $job->{'special'},
			[ map { [ $_, $cron::text{'edit_special_'.$_} ] }
		          ('hourly', 'daily', 'weekly', 'monthly', 'yearly')]));
		}
	print &ui_hidden_table_end("sched");
	}

if ($cron) {
	print &ui_form_end([ [ "backup", $text{'backup_ok'} ],
			     [ "save", $text{'backup_ok2'} ] ]);
	}
else {
	print &ui_form_end([ [ "backup", $text{'backup_ok'} ] ]);
	}

if ($in{'all'}) {
	&ui_print_footer("", $text{'index_return'});
	}
else {
	&ui_print_footer("edit_dbase.cgi?db=$in{'db'}", $text{'dbase_return'},
		&get_databases_return_link($in{'db'}), $text{'index_return'});
	}


