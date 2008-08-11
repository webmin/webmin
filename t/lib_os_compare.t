#!/usr/bin/perl -w
use strict;
use OsChooser;

my $DATADIR = "t/data";

# Get a list of the example OS definition files
opendir(DIR, $DATADIR) || die "can't opendir $DATADIR: $!";
my @files = grep { /\.os/ } readdir(DIR);
closedir DIR;
use Test::More qw(no_plan);
use Test::Files;

foreach my $file (sort @files) {
	$file =~ /(.*)\.os$/;
	my $osname = $1;
	my $issue = "$DATADIR/$1.issue";
	my $outfile = "t/outfile";
	OsChooser::write_file($outfile,
	  OsChooser::oschooser("os_list.txt", 1, $issue));
	compare_ok($outfile, "$DATADIR/$file", $osname);

	# Cleanup
	unlink $outfile;
}

