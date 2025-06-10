#!/usr/local/bin/perl
# Returns a list of files and directories under some directory

$trust_unknown_referers = 1;
use JSON::PP;
require './bacula-backup-lib.pl';
&ReadParse();

# Input sanitization
die "Illegal input" if ($in{'job'} and $in{'job'} !~ /^\d+\z/);

# Output the appropriate content-type
if ($in{'fmt'} eq "json") {
	print "Content-type: application/json\n\n";
}
else {
	print "Content-type: text/plain\n\n";
}

# Format the parent with ending slash if missing
$d = ($in{'dir'} =~ /\/\z/) ? $in{'dir'} : $in{'dir'}."/";
$wind = &unix_to_dos($d);

# Get the parent directory ID
$dbh = &connect_to_database();
$cmd = $dbh->prepare("SELECT PathId FROM Path WHERE Path = ?");
$cmd->execute($wind);
($pid) = $cmd->fetchrow();
$cmd->finish();

if ($in{'job'}) {
	$jobsql = "AND Job.JobId = $in{'job'}";
}

@nodes = ();

if ($in{'volume'}) {
	# Search just within one volume
	# Subdirectories of directory, that are on this volume
	$cmd = $dbh->prepare("
		SELECT DISTINCT Path.Path
		FROM Job, File, Path, JobMedia, Media
		WHERE Job.JobId        = File.JobId
		  AND Job.JobId        = JobMedia.JobId
		  AND File.PathId      = Path.PathId
		  AND JobMedia.MediaId = Media.MediaId
		  AND Media.VolumeName = ?
		  $jobsql
		ORDER BY Path.Path
	");

	$cmd->execute($in{'volume'}) || die "db error: ".$dbh->errstr;
}
else {
	# Search all files
	# Subdirectories of directory
	$cmd = $dbh->prepare("
		SELECT DISTINCT Path.Path
		FROM Job, File, Path
		WHERE Job.JobId   = File.JobId
		  AND File.PathId = Path.PathId
		  $jobsql
		ORDER BY Path.Path
	");

	$cmd->execute() || die "db error: ".$dbh->errstr;
}

# Push all folders direcly under the starting path
while(($f) = $cmd->fetchrow()) {
	$f = &dos_to_unix($f);
	if ($f =~ /^(\Q$d\E([^\/]+)\/)/) {
		push(@rv, $1);
	}
}

$cmd->finish();

@rv = &unique(@rv);

# Build the nodes structure for folders
foreach $f (@rv) {
	$f =~ /([^\/]+)\/\Z/;
	push @nodes, {
		text     => $1,
		fullpath => $f,
		children => JSON::PP::true,
		icon     => "jstree-folder"
	};
}

if ($in{'volume'}) {
	# Files in directory, that are on this volume
	$cmd = $dbh->prepare("
		SELECT Filename.Name
		FROM File, Filename, Job, JobMedia, Media
		WHERE File.FilenameId  = Filename.FilenameId
		  AND File.JobId       = Job.JobId
		  AND Job.JobId        = JobMedia.JobId
		  AND JobMedia.MediaId = Media.MediaId
		  AND File.PathId      = ?
		  AND Media.VolumeName = ?
		  $jobsql
		ORDER BY Filename.Name
	");

	$cmd->execute($pid, $in{'volume'}) || die "db error: ".$dbh->errstr;
}
else {
	# Files in directory
	$cmd = $dbh->prepare("
		SELECT Filename.Name
		FROM Job, File, Filename
		WHERE Job.JobId       = File.JobId
		  AND File.FilenameId = Filename.FilenameId
		  AND File.PathId     = ?
		  $jobsql
		ORDER BY Filename.Name
	");

	$cmd->execute($pid) || die "db error: ".$dbh->errstr;
}

# Push all the files in the starting path
while(($f) = $cmd->fetchrow()) {
	if ($f =~ /\S/) {
		push(@rv, "$d$f");

		# Build the nodes structure for files
		push @nodes, {
			text     => $f,
			fullpath => "$d$f",
			children => JSON::PP::false,
			icon     => "jstree-file"
		};
	}
}

$cmd->finish();

# Return output

if($in{'fmt'} eq "json") {
	print JSON::PP->new->utf8->encode(\@nodes);
}
else {
	print "\n";
	foreach $f (@rv) {
		print $f,"\n";
	}
}
