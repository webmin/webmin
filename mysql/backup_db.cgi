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

# Cannot download all the DBs
if ($in{'dest'} == 1 && $in{'all'}) {
	&error($text{'backup_edownloadall'});
	}
if ($in{'dest'} == 1 && ($in{'sched'} || $in{'save'})) {
	&error($text{'backup_edownloadsave'});
	}

if (!$in{'save'} || $in{'sched'}) {
	if ($in{'all'}) {
		-d $in{'file'} || -d &date_subs($in{'file'}) || $in{'mkdir'} ||
			&error($text{'backup_efile2'});
		}
	else {
		$in{'dest'} || $in{'file'} =~ /^\/\S+$/ ||
			&error($text{'backup_efile'});
		}
	$in{'where_def'} || $in{'where'} || &error($text{'backup_ewhere'});
	$in{'charset_def'} || $in{'charset'} =~ /^\S+$/ ||
		&error($text{'backup_echarset'});
	$ccmd = $in{'compress'} == 1 ? "gzip" :
		$in{'compress'} == 2 ? "bzip2" : undef;
	!$ccmd || &has_command($ccmd) ||
		&error(&text('backup_eccmd', "<tt>$ccmd</tt>"));
	if (!$in{'dest'} && !&is_under_directory($access{'bpath'}, $in{'file'})) {
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
	if (!$in{'dest'}) {
		$userconfig{'backup_'.$in{'db'}} = $in{'file'};
		}
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
	$userconfig{'backup_parameters_'.$in{'db'}} = $in{'parameters'};
	$userconfig{'backup_tables_'.$in{'db'}} = join(" ", @tables);
	if ($in{'save'}) {
		&save_user_module_config();
		}
	}
else {
	if (!$in{'dest'}) {
		$config{'backup_'.$in{'db'}} = $in{'file'};
		$config{'backup_prefix_'.$in{'db'}} = $in{'prefix'};
		$in{'prefix'} =~ /\// && &error($text{'backup_eprefix'});
		}
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
	$config{'backup_parameters_'.$in{'db'}} = $in{'parameters'};
	$config{'backup_tables_'.$in{'db'}} = join(" ", @tables);
	if ($in{'save'}) {
		&save_module_config();
		}
	}

if ($in{'dest'}) {
	my $mt;
	my $fn = "backup.sql";
	if ($in{'compress'} == 1) {
		$mt = "application/x-gzip";
		$fn .= ".gz";
		}
	elsif ($in{'compress'} == 2) {
		$mt = "application/x-bzip2";
		$fn .= ".bz2";
		}
	else {
		$mt = "text/plain";
		}
	print "Content-Type: $mt\n";
	print "Content-Disposition: Attachment; filename=\"$fn\"\n";
	print "\n";
	}
else {
	&ui_print_header(undef, $text{'backup_title'}, "");
	}

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
		my $deletefile = 0;
		if ($in{'all'}) {
			# File in a directory
			$dir = &date_subs($in{'file'});
			$prefix = &date_subs($in{'prefix'});
			&make_dir($dir, 0755) if ($in{'mkdir'});
			$file = $dir."/".$prefix.$db.".sql".
				($in{'compress'} == 1 ? ".gz" :
				 $in{'compress'} == 2 ? ".bz2" : "");
			$deletefile = 1;
			}
		elsif (!$in{'dest'}) {
			# Single file
			$file = &date_subs($in{'file'});
			$deletefile = 1;
			}
		else {
			# Temp file for download
			$file = &transname();
			if ($access{'buser'} && $access{'buser'} ne 'root') {
				# Need to pre-create file owned by user who
				# will be doing the writing
				&open_tempfile(FILE, ">$file", 0, 1);
				&close_tempfile(FILE);
				&set_ownership_permissions($access{'buser'},
					undef, undef, $file);
				}
			}
		if (-d $file) {
			print &text('backup_eisdir',
				    &html_escape($file)),"<p>\n";
			next;
			}
		if ($cron && $cmode == 0) {
			# Run and check before-backup command (for one DB)
			$bok = &execute_before($db, STDOUT, 1, $file,
					       $in{'all'} ? undef : $db);
			if (!$bok) {
				print $text{'backup_ebefore'},"<p>\n";
				next;
				}
			}
		&unlink_file($file) if ($deletefile);
		local $err = &backup_database($db, $file, $in{'compress'},
			$in{'drop'}, $in{'where_def'} ? undef : $in{'where'},
			$in{'charset_def'} ? undef : $in{'charset'},
			\@compat, \@tables, $access{'buser'}, $in{'single'},
			$in{'quick'}, undef, $in{'parameters'});
		if ($err) {
			print &text('backup_ebackup',
				"<pre>".&html_escape($err)."</pre>"),"<p>\n";
			}
		elsif (!$in{'dest'}) {
			@st = stat($file);
			print &text('backup_done', "<tt>$db</tt>",
				    "<tt>$file</tt>", int($st[7])),"<p>\n";
			}
		&execute_after($db, STDOUT, 1, $file, $in{'all'} ? undef : $db)
			if ($cron && $cmode == 0);

		if ($in{'dest'}) {
			# Sent to browser
			open(OUT, "<$file");
			while(<OUT>) {
				print $_;
				}
			close(OUT);
			&unlink_file($file);
			}
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
	print $text{$what},"<p>\n" if ($what && !$in{'dest'});
	}

&webmin_log("backup", undef, $in{'all'} ? "" : $in{'db'}, \%in);

if (!$in{'dest'}) {
	if ($in{'all'}) {
		&ui_print_footer("", $text{'index_return'});
		}
	else {
		&ui_print_footer(
			"edit_dbase.cgi?db=$in{'db'}", $text{'dbase_return'},
			&get_databases_return_link($in{'db'}), $text{'index_return'});
		}
	}

