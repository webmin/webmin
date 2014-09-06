#!/usr/local/bin/perl
# backup_db.cgi
# Do the actual backup

require './mysql-lib.pl';
&ReadParse();
if ($in{'all'}) {
	@alldbs = grep { &supports_backup_db($_) } &list_databases();
	@dbs = grep { &can_edit_db($_) } @alldbs;
	@alldbs == @dbs || &error($text{'dbase_ecannot'});
	}
else {
	&can_edit_db($in{'db'}) || &error($text{'dbase_ecannot'});
	}
$access{'edonly'} && &error($text{'dbase_ecannot'});
$access{'buser'} || &error($text{'dbase_ecannot'});
&error_setup($text{'backup_err'});

if (!$in{'save'} || $in{'sched'}) {
	if ($in{'all'}) {
		-d $in{'file'} || -d &date_subs($in{'file'}) || $in{'mkdir'} ||
			&error($text{'backup_efile2'});
		}
	else {
		$in{'file'} =~ /^\/\S+$/ || &error($text{'backup_efile'});
		}
	$in{'where_def'} || $in{'where'} || &error($text{'backup_ewhere'});
	$in{'charset_def'} || $in{'charset'} =~ /^\S+$/ ||
		&error($text{'backup_echarset'});
	$ccmd = $in{'compress'} == 1 ? "gzip" :
		$in{'compress'} == 2 ? "bzip2" : undef;
	!$ccmd || &has_command($ccmd) ||
		&error(&text('backup_eccmd', "<tt>$ccmd</tt>"));
	if (!&is_under_directory($access{'bpath'}, $in{'file'})) {
		&error($text{'backup_epath'}."<br>".
		       &text('backup_eunder', "<tt>$access{'bpath'}</tt>"));
		}
	if (!$in{'all'} && !$in{'tables_def'}) {
		@tables = split(/\0/, $in{'tables'});
		@tables || &error($text{'backup_etables'});
		}
	}
@compat = $in{'compatible_def'} ? ( ) : ( $in{'compatible'} );
push(@compat, split(/\0/, $in{'options'}));
$cron = !$module_info{'usermin'} && $access{'buser'} eq 'root' &&
	!$access{'user'} && &foreign_installed("cron");
$cmode = 0;
if ($cron) {
	$config{'backup_before_'.$in{'db'}} = $in{'before'};
	$config{'backup_after_'.$in{'db'}} = $in{'after'};
	if ($in{'all'}) {
		$config{'backup_cmode_'.$in{'db'}} = $in{'cmode'};
		$cmode = $in{'cmode'};
		}
	$config{'backup_email_'.$in{'db'}} = $in{'email'};
	$config{'backup_notify_'.$in{'db'}} = $in{'notify'};

	&foreign_require("cron");
	@jobs = &cron::list_cron_jobs();
	$cmd = $in{'all'} ? "$cron_cmd --all" : "$cron_cmd $in{'db'}";
	($job) = grep { $_->{'command'} eq $cmd } @jobs;
	$oldjob = $job;
	$job ||= { 'command' => $cmd,
		   'user' => 'root',
		   'active' => 1 };
	&cron::parse_times_input($job, \%in);
	}

# Save choices for next time the form is visited (and for the cron job)
if ($module_info{'usermin'}) {
	$userconfig{'backup_'.$in{'db'}} = $in{'file'};
	$userconfig{'backup_where_'.$in{'db'}} =
		$in{'where_def'} ? undef : $in{'where'};
	$userconfig{'backup_charset_'.$in{'db'}} =
		$in{'charset_def'} ? undef : $in{'charset'};
	$userconfig{'backup_compatible_'.$in{'db'}} =
		$in{'compatible_def'} ? undef : $in{'compatible'};
	$userconfig{'backup_options_'.$in{'db'}} =
		join(" ", split(/\0/, $in{'options'}));
	$userconfig{'backup_compress_'.$in{'db'}} = $in{'compress'};
	$userconfig{'backup_drop_'.$in{'db'}} = $in{'drop'};
	$userconfig{'backup_single_'.$in{'db'}} = $in{'single'};
	$userconfig{'backup_quick_'.$in{'db'}} = $in{'quick'};
	$userconfig{'backup_tables_'.$in{'db'}} = join(" ", @tables);
	&write_file("$user_module_config_directory/config", \%userconfig);
	}
else {
	$config{'backup_'.$in{'db'}} = $in{'file'};
	$config{'backup_mkdir_'.$in{'db'}} = $in{'mkdir'};
	$config{'backup_where_'.$in{'db'}} =
		$in{'where_def'} ? undef : $in{'where'};
	$config{'backup_charset_'.$in{'db'}} =
		$in{'charset_def'} ? undef : $in{'charset'};
	$config{'backup_compatible_'.$in{'db'}} =
		$in{'compatible_def'} ? undef : $in{'compatible'};
	$config{'backup_options_'.$in{'db'}} =
		join(" ", split(/\0/, $in{'options'}));
	$config{'backup_compress_'.$in{'db'}} = $in{'compress'};
	$config{'backup_drop_'.$in{'db'}} = $in{'drop'};
	$config{'backup_single_'.$in{'db'}} = $in{'single'};
	$config{'backup_quick_'.$in{'db'}} = $in{'quick'};
	$config{'backup_tables_'.$in{'db'}} = join(" ", @tables);
	&write_file("$module_config_directory/config", \%config);
	}

&ui_print_header(undef, $text{'backup_title'}, "");
if (!$in{'save'}) {
	# Actually execute the backup now
	@dbs = $in{'all'} ? @alldbs : ( $in{'db'} );
	if ($cmode == 1) {
		# Run and check before-backup command (for all DBs)
		$bok = &execute_before(undef, STDOUT, 1, $in{'file'}, undef);
		if (!$bok) {
			print "$main::whatfailed : ",
			      $text{'backup_ebefore'},"<p>\n";
			goto donebackup;
			}
		}
	foreach $db (@dbs) {
		if ($in{'all'}) {
			$dir = &date_subs($in{'file'});
			&make_dir($dir, 0755) if ($in{'mkdir'});
			$file = $dir."/".$db.".sql".
				($in{'compress'} == 1 ? ".gz" :
				 $in{'compress'} == 2 ? ".bz2" : "");
			}
		else {
			$file = &date_subs($in{'file'});
			}
		if ($cron && $cmode == 0) {
			# Run and check before-backup command (for one DB)
			$bok = &execute_before($db, STDOUT, 1, $file,
					       $in{'all'} ? undef : $db);
			if (!$bok) {
				print "$main::whatfailed : ",
				      $text{'backup_ebefore'},"<p>\n";
				next;
				}
			}
		unlink($file);
		local $err = &backup_database($db, $file, $in{'compress'},
			$in{'drop'}, $in{'where_def'} ? undef : $in{'where'},
			$in{'charset_def'} ? undef : $in{'charset'},
			\@compat, \@tables, $access{'buser'}, $in{'single'},
			$in{'quick'});
		if ($err) {
			print "$main::whatfailed : ",
			      &text('backup_ebackup',"<pre>$err</pre>"),"<p>\n";
			}
		else {
			@st = stat($file);
			print &text('backup_done', "<tt>$db</tt>",
				    "<tt>$file</tt>", int($st[7])),"<p>\n";
			}
		&execute_after($db, STDOUT, 1, $file, $in{'all'} ? undef : $db)
			if ($cron && $cmode == 0);
		}
	&execute_after(undef, STDOUT, 1, $in{'file'}, undef) if ($cmode == 1);
	donebackup:
	}

if ($cron) {
	&lock_file($cron_cmd);
	&cron::create_wrapper($cron_cmd, $module_name, "backup.pl");
	&unlock_file($cron_cmd);

	&lock_file(&cron::cron_file($job));
	if ($in{'sched'} && !$oldjob) {
		&cron::create_cron_job($job);
		$what = "backup_ccron";
		}
	elsif (!$in{'sched'} && $oldjob) {
		# Need to delete cron job
		&cron::delete_cron_job($job);
		$what = "backup_dcron";
		}
	elsif ($in{'sched'} && $oldjob) {
		# Need to update cron job
		&cron::change_cron_job($job);
		$what = "backup_ucron";
		}
        else {
                $what = "backup_ncron";
                }
	&unlock_file(&cron::cron_file($job));

	# Tell the user what was done
	print $text{$what},"<p>\n" if ($what);
	}

&webmin_log("backup", undef, $in{'all'} ? "" : $in{'db'}, \%in);
if ($in{'all'}) {
	&ui_print_footer("", $text{'index_return'});
	}
else {
	&ui_print_footer("edit_dbase.cgi?db=$in{'db'}", $text{'dbase_return'},
		&get_databases_return_link($in{'db'}), $text{'index_return'});
	}

