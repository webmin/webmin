#!/usr/local/bin/perl
# backup.pl
# Called by cron to backup a database

$no_acl_check++;
require './postgresql-lib.pl';

if ($ARGV[0] eq "--all") {
	$all = 1;
	@dbs = &list_databases();
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
                print STDERR "Before-backup command failed!\n";
                exit(1);
                }
        }
$ex = 0;
foreach $db (@dbs) {
	$sf = $all ? "" : $db;
	if (!&accepting_connections($db)) {
		#print STDERR "Database $db is not accepting connections.\n";
		next;
		}
	$format = $config{'backup_format_'.$sf};
	$mkdir = $config{'backup_mkdir_'.$sf};
	$suf = $format eq "p" ? "sql" :
	       $format eq "t" ? "tar" : "post";
	if ($all) {
		$dir = &date_subs($config{'backup_'});
		$file = "$dir/$db.$suf";
		&make_backup_dir($dir) if ($mkdir);
		}
	else {
		$file = &date_subs($config{'backup_'.$db});
		}
	@tables = split(/\s+/, $config{'backup_tables_'.$sf});
	if (!$file) {
		print STDERR "No backup file set for database $db\n";
		exit(1);
		}

	if (!$cmode) {
		# Run and check before-backup command (for one DB)
		$bok = &execute_before($db, STDOUT, 0, $file, $all ? undef : $db);
		if (!$bok) {
			print STDERR "Before-backup command failed!\n";
			$ex = 1;
			next;
			}
		}

	unlink($file);
	$err = &backup_database($db, $file, $format, \@tables);
	if ($err) {
		print STDERR "Backup of database $db to file $file failed:\n";
		print STDERR $err;
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

