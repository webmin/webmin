#!/usr/local/bin/perl
# backup.pl
# Called by cron to backup a database, or all databases

$no_acl_check++;
require './mysql-lib.pl';

if ($ARGV[0] eq "--all") {
	$all = 1;
	@dbs = grep { &supports_backup_db($_) } &list_databases();
	$cmode = $config{'backup_cmode_'};
	}
else {
	$ARGV[0] || die "Missing database parameter";
	@dbs = ( $ARGV[0] );
	$cmode = 0;
	}

if ($cmode) {
	# Run and check before-backup command (for all DBs)
	$bok = &execute_before(undef, STDOUT, 0, $config{'backup_'}, undef);
	if (!$bok) {
		print "Before-backup command failed!\n";
		exit(1);
		}
	}

# Check if MySQL is running
if (!$config{'host'}) {
	($r, $out) = &is_mysql_running();
	if (!$r) {
		print "MySQL does not appear to be running : $out\n";
		print "Backups cannot be performed.\n";
		exit(1);
		}
	}

$ex = 0;
foreach $db (@dbs) {
	$sf = $all ? "" : $db;
	if ($all) {
		$dir = &date_subs($config{'backup_'});
		&make_dir($dir, 0755) if ($config{'backup_mkdir_'});
		$file = $dir."/".$db.".sql".
			($config{'backup_compress_'.$sf} == 1 ? ".gz" :
			 $config{'backup_compress_'.$sf} == 2 ? ".bz2" : "");
		}
	else {
		$file = &date_subs($config{'backup_'.$db});
		}
	if (!$file) {
		print STDERR "No backup file set for database $db\n";
		exit(1);
		}
	@compat = $config{'backup_compatible_'.$sf} ?
			( $config{'backup_compatible_'.$sf} ) : ( );
	push(@compat, split(/\0/, $in{'backup_options_'.$sf}));
	@tables = split(/\s+/, $config{'backup_tables_'.$sf});

	if (!$cmode) {
		# Run and check before-backup command (for one DB)
		$bok = &execute_before($db, STDOUT, 0, $file, $all ? undef : $db);
		if (!$bok) {
			print "Before-backup command failed!\n";
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
				$config{'backup_single_'.$sf});
	if ($err) {
		print "Backup of database $db to file $file failed:\n";
		print $out;
		$ex = 1;
		}
	if (!$cmode) {
		&execute_after($db, STDOUT, 0, $file, $all ? undef : $db);
		}
	}
if ($cmode) {
	&execute_after(undef, STDOUT, 0, $config{'backup_'}, undef);
	}
exit($ex);

