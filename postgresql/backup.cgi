#!/usr/local/bin/perl
# backup.cgi
# Backup a database to a local file

require './postgresql-lib.pl' ;

&ReadParse ( ) ;

&error_setup ( $text{'backup_err'} ) ;

# Validate inputs
if ($in{'all'}) {
	@alldbs = &list_databases();
	@dbs = grep { &can_edit_db($_) } @alldbs;
	@alldbs == @dbs || &error($text{'dbase_ecannot'});
	}
else {
	&can_edit_db($in{'db'}) || &error($text{'dbase_ecannot'});
	}
$access{'backup'} || &error($text{'backup_ecannot'});
if (!$in{'save'} || $in{'sched'}) {
	if ($in{'all'}) {
		-d $in{'path'} || -d &date_subs($in{'path'}) || $in{'mkdir'} ||
			&error(&text('backup_pe4', $in{'path'})) ;
		}
	else {
		$in{'path'} =~ /^\/\S+$/ ||
		  $in{'path'} =~ /^[a-z]:[\\\/]/i ||
		    &error(&text('backup_pe3', $in{'path'})) ;
		}
	if (!$in{'all'} && !$in{'tables_def'}) {
		@tables = split(/\0/, $in{'tables'});
		@tables || &error($text{'backup_etables'});
		}
	}
$cron = !$module_info{'usermin'} &&
        !$access{'user'} && &foreign_installed("cron");
$cmode = 0;
if ($cron) {
	if ($access{'cmds'}) {
		$config{'backup_before_'.$in{'db'}} = $in{'before'};
		$config{'backup_after_'.$in{'db'}} = $in{'after'};
		if ($in{'all'}) {
			$config{'backup_cmode_'.$in{'db'}} = $in{'cmode'};
			$cmode = $in{'cmode'};
			}
		}

	&foreign_require("cron", "cron-lib.pl");
	@jobs = &cron::list_cron_jobs();
	$cmd = $in{'all'} ? "$cron_cmd --all" : "$cron_cmd $in{'db'}";
	($job) = grep { $_->{'command'} eq $cmd } @jobs;
	$oldjob = $job;
	$job ||= { 'command' => $cmd,
		   'user' => 'root',
		   'active' => 1 };
	&cron::parse_times_input($job, \%in);
	}

if (!$in{'all'}) {
	# Make sure the database exists
	$db_find_f = 0 ;
	if ( $in{'db'} ) {
	    foreach ( &list_databases() ) {
		if ( $_ eq $in{'db'} ) { $db_find_f = 1 ; }
	    }
	}
	if ( $db_find_f == 0 ) { &error ( &text ( 'backup_edb' ) ) ; }
	}

# Save choices for next time the form is visited (and for the cron job)
if ($module_info{'usermin'}) {
	$userconfig{'backup_'.$in{'db'}} = $in{'path'};
	$userconfig{'backup_format_'.$in{'db'}} = $in{'format'};
	$userconfig{'backup_tables_'.$in{'db'}} = join(" ", @tables);
	if ($in{'save'}) {
		&save_user_module_config();
		}
	}
else {
	$config{'backup_'.$in{'db'}} = $in{'path'};
	$config{'backup_mkdir_'.$in{'db'}} = $in{'mkdir'};
	$config{'backup_format_'.$in{'db'}} = $in{'format'};
	$config{'backup_tables_'.$in{'db'}} = join(" ", @tables);
	if ($in{'save'}) {
		&save_module_config();
		}
	}

$desc = "<tt>$in{'db'}</tt>";
&ui_print_header($desc, $text{'backup_title'}, "");
if (!$in{'save'}) {
	# Construct and run the backup command
	@dbs = $in{'all'} ? @alldbs : ( $in{'db'} );
	$suf = $in{'format'} eq "p" ? "sql" :
	       $in{'format'} eq "t" ? "tar" : "post";
        if ($cmode == 1) {
                # Run and check before-backup command (for all DBs)
                $bok = &execute_before(undef, STDOUT, 1, $in{'file'}, undef);
                if (!$bok) {
                        print "$main::whatfailed : ",$text{'backup_ebefore'},"<p>\n";
                        goto donebackup;
                        }
                }
	foreach $db (@dbs) {
		if (!&accepting_connections($db)) {
			print &text('backup_notaccept', "<tt>$db</tt>"),"<p>\n";
			next;
			}
		if ($in{'all'}) {
			$dir = &date_subs($in{'path'});
			&make_backup_dir($dir) if ($in{'mkdir'});
			$path = $dir."/".$db.".".$suf;
			}
		else {
			$path = &date_subs($in{'path'});
			}
		if ($cron && $cmode == 0) {
			# Run and check before-backup command
			$bok = &execute_before($db, STDOUT, 1, $path, $in{'all'} ? undef : $db);
			if (!$bok) {
                                print "$main::whatfailed : ",$text{'backup_ebefore'},"<p>\n";
                                next;
                                }
			}
		$err = &backup_database($db, $path, $in{'format'}, \@tables);
		if ($err) {
			print "$main::whatfailed : ",
			      &text('backup_ebackup',"<pre>$err</pre>"),"<p>\n";
			}
		else {
			@st = stat($path);
			print &text('backup_done', "<tt>$db</tt>",
					  "<tt>$path</tt>", $st[7]),"<p>\n";
			}
		&execute_after($db, STDOUT, 1, $path, $in{'all'} ? undef : $db)
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

