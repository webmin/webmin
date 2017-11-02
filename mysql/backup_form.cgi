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
&ui_print_header(undef, $in{'all'} ? $text{'backup_title2'}
				   : $text{'backup_title'}, "",
	"backup_form");

($cmd) = split(/\s+/, $config{'mysqldump'});
if (!-x $cmd) {
	print &text('backup_edump', "<tt>$cmd</tt>",
			  "../config.cgi?$module_name"),"<p>\n";
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

$download = $in{'all'} ? 'database' : $in{'db'};
print &ui_form_start("backup_db.cgi/$download.sql", "post");
print &ui_hidden("db", $in{'db'});
print &ui_hidden("all", $in{'all'});
print &ui_hidden_table_start($text{'backup_header1'}, "width=100%", 2, "main",
			     1, [ "width=30%" ]);

# Destination file or directory
print &ui_table_row($in{'all'} ? $text{'backup_file2'}
			       : $text{'backup_file'},
	&ui_radio_table("dest", 0,
		[ [ 1, $text{'backup_download'} ],
		  [ 0, $text{'backup_path'}, 
		       &ui_textbox("file", $c{'backup_'.$in{'db'}}, 60)." ".
		       &file_chooser_button("file") ] ]));

# Create destination dir
if ($in{'all'}) {
	print &ui_table_row($text{'backup_mkdir'},
		&ui_yesno_radio("mkdir", int($c{'backup_mkdir_'.$in{'db'}})));
	}

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
print &ui_hidden_table_start($text{'backup_header2'}, "width=100%", 2, "opts",
			     0, [ "width=30%" ]);

# Show input for where clause
$w = $c{'backup_where_'.$in{'db'}};
print &ui_table_row($text{'backup_where'},
	&ui_opt_textbox("where", $w, 30, $text{'backup_none'}));

# Show option to include drop statements in SQL
$d = $c{'backup_drop_'.$in{'db'}};
print &ui_table_row($text{'backup_drop'},
	&ui_yesno_radio("drop", $d ? 1 : 0));

# Show input for character set
$s = $c{'backup_charset_'.$in{'db'}};
print &ui_table_row($text{'backup_charset'},
	&ui_radio("charset_def", $s ? 0 : 1,
	       [ [ 1, $text{'default'} ],
		 [ 0, &ui_select("charset", $s,
			[ &list_character_sets($in{'db'}) ]) ] ]));

if ($mysql_version >= 5.0) {
	# Show compatibility format option
	$cf = $c{'backup_compatible_'.$in{'db'}};
	print &ui_table_row($text{'backup_compatible'},
		&ui_radio("compatible_def", $cf ? 0 : 1,
		       [ [ 1, $text{'default'} ],
			 [ 0, &text('backup_compwith',
				&ui_select("compatible", $cf,
				   [ &list_compatible_formats() ])) ] ]));

	%co = map { $_, 1 } split(/\s+/, $c{'backup_options_'.$in{'db'}});
	$opts = "";
	foreach $o (&list_compatible_options()) {
		$opts .= &ui_checkbox("options", $o->[0], $o->[1] || $o->[0],
				   $co{$o->[0]})."<br>\n";
		}
	print &ui_table_row($text{'backup_options'}, $opts);
	}
else {
	print &ui_hidden("compatible_def", 1),"\n";
	}

# Show compression option
$cp = int($c{'backup_compress_'.$in{'db'}});
print &ui_table_row($text{'backup_compress'},
	&ui_radio("compress", $cp,
		[ [ 0, $text{'backup_cnone'} ],
		  [ 1, $text{'backup_gzip'} ],
		  [ 2, $text{'backup_bzip2'} ] ]));

# Show single-transaction option
$s = $c{'backup_single_'.$in{'db'}};
print &ui_table_row($text{'backup_single'},
	&ui_yesno_radio("single", $s ? 1 : 0));

# Show quick dump mode
$q = $c{'backup_quick_'.$in{'db'}};
print &ui_table_row($text{'backup_quick'},
	&ui_yesno_radio("quick", $q ? 1 : 0));

if ($cron) {
	# Show before/after commands
	$b = $c{'backup_before_'.$in{'db'}};
	print &ui_table_row($text{'backup_before'},
		&ui_textbox("before", $b, 60));

	$a = $c{'backup_after_'.$in{'db'}};
	print &ui_table_row($text{'backup_after'},
		&ui_textbox("after", $a, 60));

	if ($in{'all'}) {
		# Command mode option
		$cmode = $c{'backup_cmode_'.$in{'db'}};
		print &ui_table_row($text{'backup_cmode'},
			&ui_radio("cmode", int($cmode),
				[ [ 0, $text{'backup_cmode0'} ],
				  [ 1, $text{'backup_cmode1'} ] ]));
		}

	print &ui_hidden_table_end("opts");
	print &ui_hidden_table_start($text{'backup_header3'}, "width=100%", 2,
				     "sched", 1, [ "width=30%" ]);

	# Who to notify?
	$email = $c{'backup_email_'.$in{'db'}};
	print &ui_table_row($text{'backup_email'},
		&ui_textbox("email", $email, 60));

	# Notification conditions
	$notify = $c{'backup_notify_'.$in{'db'}};
	print &ui_table_row($text{'backup_notify'},
		&ui_radio("notify", int($notify),
			  [ [ 0, $text{'backup_notify0'} ],
			    [ 1, $text{'backup_notify1'} ],
			    [ 2, $text{'backup_notify2'} ] ]));

	# Show cron time
	&foreign_require("cron", "cron-lib.pl");
	@jobs = &cron::list_cron_jobs();
	$cmd = $in{'all'} ? "$cron_cmd --all" : "$cron_cmd $in{'db'}";
	($job) = grep { $_->{'command'} eq $cmd } @jobs;

	print &ui_table_row($text{'backup_sched'},
		&ui_radio("sched", $job ? 1 : 0,
		  [ [ 0, $text{'no'} ], [ 1, $text{'backup_sched1'} ] ]));

	$job ||= { 'mins' => 0,
		   'hours' => 0,
		   'days' => '*',
		   'months' => '*',
		   'weekdays' => '*' };
	print &cron::get_times_input($job);

	print &ui_hidden_table_end("sched");
	}
else {
	print &ui_hidden_table_end("opts");
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

