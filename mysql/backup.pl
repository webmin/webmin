#!/usr/local/bin/perl
# backup.pl
# Called by cron to backup a database, or all databases

$no_acl_check++;
require './mysql-lib.pl';

if ($ARGV[0] eq "--all") {
	$all = 1;
	$cmode = $config{'backup_cmode_'};
	}
else {
	$ARGV[0] || die "Missing database parameter";
	$cmode = 0;
	}
$extra_prefix = "";
if ($ARGV[1] eq "--prefix") {
	$extra_prefix = $ARGV[2];
	}

$email = $config{'backup_email_'.($all ? '' : $ARGV[0])};
$notify = $config{'backup_notify_'.($all ? '' : $ARGV[0])};

# Check if MySQL is running
$ex = 0;
($r, $out) = &is_mysql_running();
if ($r != 1) {
	$failure = "MySQL does not appear to be running : $out\n".
		   "Backups cannot be performed.\n";
	$ex = 1;
	goto EMAIL;
	}

# Get DBs
if ($all) {
	@dbs = grep { &supports_backup_db($_) } &list_databases();
	}
else {
	@dbs = ( $ARGV[0] );
	}

if ($cmode) {
	# Run and check before-backup command (for all DBs)
	$bok = &execute_before(undef, STDOUT, 0, $config{'backup_'}, undef);
	if (!$bok) {
		$failure = "Before-backup command failed!\n";
		$ex = 1;
		goto EMAIL;
		}
	}

foreach $db (@dbs) {
	$sf = $all ? "" : $db;
	if ($all) {
		$dir = &date_subs($config{'backup_'});
		$prefix = &date_subs($config{'backup_prefix_'});
		&make_dir($dir, 0755) if ($config{'backup_mkdir_'});
		$file = $dir."/".$extra_prefix.$prefix.$db.".sql".
			($config{'backup_compress_'.$sf} == 1 ? ".gz" :
			 $config{'backup_compress_'.$sf} == 2 ? ".bz2" : "");
		}
	else {
		$file = &date_subs($config{'backup_'.$db});
		}
	if (!$file) {
		push(@status, [ $db, $file, "No backup file set for $db" ]);
		$ex = 1;
		next;
		}
	@compat = $config{'backup_compatible_'.$sf} ?
			( $config{'backup_compatible_'.$sf} ) : ( );
	push(@compat, split(/\0/, $in{'backup_options_'.$sf}));
	@tables = split(/\s+/, $config{'backup_tables_'.$sf});

	if (!$cmode) {
		# Run and check before-backup command (for one DB)
		$temp = &transname();
		&open_tempfile(TEMP, ">$temp");
		$bok = &execute_before($db, TEMP, 0, $file, $all ? undef : $db);
		&close_tempfile(TEMP);
		$err = &read_file_contents($temp);
		&unlink_file($temp);
		if (!$bok) {
			push(@status, [ $db, $file, "Before-backup command failed : $err" ]);
			$ex = 1;
			next;
			}
		}

	# Do the backup
	$err = &backup_database($db, $file,
				$config{'backup_compress_'.$sf},
				$config{'backup_drop_'.$sf},
				$config{'backup_where_'.$sf},
				$config{'backup_charset_'.$sf},
				\@compat,
				\@tables,
				"root",
				$config{'backup_single_'.$sf},
				$config{'backup_quick_'.$sf},
				undef,
				$config{'backup_parameters_'.$sf}
			       );
	if ($err) {
		$ex = 1;
		}
	@st = stat($file);
	push(@status, [ $db, $file, $err, $st[7] ]);
	if (!$cmode) {
		&execute_after($db, undef, 0, $file, $all ? undef : $db);
		}
	}
if ($cmode) {
	&execute_after(undef, undef, 0, $config{'backup_'}, undef);
	}

# Send status email
EMAIL:
if ($email &&
    ($notify == 0 || $notify == 1 && $ex || $notify == 2 && !$ex) &&
    &foreign_check("mailboxes")) {
	&foreign_require("mailboxes");
	$host = &get_system_hostname();
	$msg = $all ? 'backup_allsubject' : 'backup_subject';
	$msg .= ($ex ? '_failed' : '_ok');
	$subject = &text($msg, $dbs[0],
			 scalar(@dbs) || $text{'backup_bodyall'},
			 &get_display_hostname());
	$data = &text('backup_body', $host,
	              scalar(@dbs) || $text{'backup_bodyall'})."\n\n";
	if ($failure) {
		$data .= $failure."\n";
		}
	$total = 0;
	foreach $s (@status) {
		$data .= &text('backup_bodydoing', $s->[0], $s->[1])."\n";
		if ($s->[2]) {
			$data .= &text('backup_bodyfailed', $s->[2]);
			}
		else {
			$data .= &text('backup_bodyok', &nice_size($s->[3]));
			$total += $s->[3];
			}
		$data .= "\n\n";
		}
	if ($all && $total) {
		$data .= &text('backup_bodytotal', &nice_size($total))."\n\n";
		}
	if (&foreign_check("mount")) {
		&foreign_require("mount");
		$dir = $status[0]->[1];
		while($dir ne "/" && !$total_space) {
			$dir =~ s/\/[^\/]*$//;
			$dir = "/" if (!$dir);
			($total_space, $free_space) =
				&mount::disk_space(undef, $dir);
			}
		if ($total_space) {
			$data .= &text('backup_bodyspace',
					&nice_size($total_space*1024),
					&nice_size($free_space*1024))."\n\n";
			}
		}
	&mailboxes::send_text_mail(&mailboxes::get_from_address(),
                                   $email, undef, $subject, $data);
	}

exit($ex);

