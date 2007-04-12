#!/usr/local/bin/perl
# perlpath.pl
# This script gets run only from setup.sh in order to replace the 
# #!/usr/local/bin/perl line at the start of scripts with the real path to perl

$ppath = $ARGV[0];
if ($ARGV[1] eq "-") {
	@files = <STDIN>;
	chop(@files);
	}
else {
	# Get files from command line
	@files = @ARGV[1..$#ARGV];
	}

foreach $f (@files) {
	open(IN, $f);
	@lines = <IN>;
	close(IN);
	if ($lines[0] =~ /^#!\/\S*perl\S*(.*)/) {
		open(OUT, "> $f");
		print OUT "#!$ppath$1\n";
		for($i=1; $i<@lines; $i++) {
			print OUT $lines[$i];
			}
		close(OUT);
		}
	}

