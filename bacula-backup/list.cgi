#!/usr/local/bin/perl
# Returns a list of files and directories under some directory

$trust_unknown_referers = 1;
require './bacula-backup-lib.pl';
&ReadParse();
print "Content-type: text/plain\n\n";

# Get the parent directory ID
$dbh = &connect_to_database();
$cmd = $dbh->prepare("select PathId from Path where Path = ?");
$d = $in{'dir'} eq "/" ? "/" : $in{'dir'}."/";
$wind = &unix_to_dos($d);
$cmd->execute($wind);
($pid) = $cmd->fetchrow();
$cmd->finish();

if ($in{'job'} ne "") {
	$jobsql = "and Job.JobId = $in{'job'}";
	}

if ($in{'volume'}) {
	# Search just within one volume
	# Subdirectories of directory, that are on this volume
	$cmd1 = $dbh->prepare("
		select Path.Path
		from Path, File, Job, JobMedia, Media
		where File.PathId = Path.PathId
		and File.JobId = Job.JobId
		and Job.JobId = JobMedia.JobId
		and JobMedia.MediaId = Media.MediaId
		and Media.VolumeName = ?
		$jobsql
		");
	$cmd1->execute($in{'volume'}) || die "db error : ".$dbh->errstr;
	while(($f) = $cmd1->fetchrow()) {
		$f = &dos_to_unix($f);
		if ($f =~ /^(\Q$d\E[^\/]+\/)/) {
			push(@rv, $1);
			}
		}
	$cmd1->finish();

	# Files in directory, that are on this volume
	$cmd2 = $dbh->prepare("
		select Filename.Name
		from File, Filename, Job, JobMedia, Media
		where File.FilenameId = Filename.FilenameId
		and File.PathId = ?
		and File.JobId = Job.JobId
		and Job.JobId = JobMedia.JobId
		and JobMedia.MediaId = Media.MediaId
		and Media.VolumeName = ?
		$jobsql
		");
	$cmd2->execute($pid, $in{'volume'}) || die "db error : ".$dbh->errstr;
	while(($f) = $cmd2->fetchrow()) {
		push(@rv, "$d$f") if ($f =~ /\S/);
		}
	$cmd2->finish();
	}
else {
	# Search all files
	# Subdirectories of directory
	$cmd1 = $dbh->prepare("
		select Path
		from Path, File, Job
		where File.PathId = Path.PathId
		and File.JobId = Job.JobId
		$jobsql
		");
	$cmd1->execute() || die "db error : ".$dbh->errstr;
	while(($f) = $cmd1->fetchrow()) {
		$f = &dos_to_unix($f);
		if ($f =~ /^(\Q$d\E[^\/]+\/)/) {
			push(@rv, $1);
			}
		}
	$cmd1->finish();

	# Files in directory
	$cmd2 = $dbh->prepare("
		select Filename.Name
		from File, Filename, Job
		where File.FilenameId = Filename.FilenameId
		and File.PathId = ?
		and File.JobId = Job.JobId
		$jobsql
		");
	$cmd2->execute($pid) || die "db error : ".$dbh->errstr;
	while(($f) = $cmd2->fetchrow()) {
		push(@rv, "$d$f") if ($f =~ /\S/);
		}
	$cmd2->finish();
	}

# Return output
@rv = &unique(@rv);
print "\n";
foreach $f (@rv) {
	print $f,"\n";
	}

