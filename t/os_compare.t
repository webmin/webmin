#!/usr/bin/perl -w
# Test in command mode...
use strict;

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
	my $issue = $1 . ".issue";
	my $outfile = "t/outfile";
	my $result = `./OsChooser.pm os_list.txt $outfile 1 $DATADIR/$issue`;
	# Do something with $result
	compare_ok($outfile, "$DATADIR/$file", $osname);

	# Cleanup
	unlink $outfile;
}

