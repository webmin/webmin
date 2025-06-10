#!/usr/local/bin/perl
# multi.pl
# Called when a tape change is needed for a multi-file backup, to rename
# to a new filename.

$no_acl_check++;
delete($ENV{'SCRIPT_NAME'});	# force use of $0 to determine module
delete($ENV{'FOREIGN_MODULE_NAME'});
require './fsdump-lib.pl';
$dump = &get_dump($ARGV[0]);
$dump->{'id'} || die "Dump $ARGV[0] does not exist!";

if ($dump->{'host'}) {
	print STDERR "Multi-file backups not supported for remote\n";
	exit(2);
	}
else {
	$i = 1;
	while(-r "$dump->{'file'}.$i") { $i++; }
	rename($dump->{'file'}, "$dump->{'file'}.$i");
	exit(0);
	}
