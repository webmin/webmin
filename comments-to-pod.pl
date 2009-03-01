#!/usr/local/bin/perl
# Convert Webmin function comments to POD format

# Parse command line
@ARGV || die "usage: webmin-to-pod.pl [--svn 'comment'] [--overwrite] <file> ...";
while(@ARGV) {
	$a = shift(@ARGV);
	if ($a eq "--svn") {
		$svn = shift(@ARGV);
		$svn || die "--svn must be followed by a commit comment";
		}
	elsif ($a eq "--overwrite") {
		$overwrite = 1;
		}
	else {
		push(@files, $a);
		}
	}

$tempdir = "/tmp/pod";
mkdir($tempdir, 0755);

foreach $f (@files) {
	# Read in the file
	if (!open(SRC, $f)) {
		print STDERR "Failed to open $f : $!";
		next;
		}
	chomp(@lines = <SRC>);
	close(SRC);

	$basef = $f;
	$basef =~ s/^.*\///;

	# Scan line by line, looking for top-level subs with comments before
	# them.
	print "Processing $f :\n";
	$i = 0;
	@out = ( );
	@cmts = ( );
	$count = 0;
	while($i<@lines) {
		if ($lines[$i] =~ /^sub\s+(\S+)\s*$/) {
			# Start of a function .. backtrack to get comments
			$name = $1;
			$args = undef;
			if ($cmts[0] =~ /^\#+\s*(\Q$name\E)\s*(\((.*))/) {
				# Found args in comments .. maybe multi-line
				$args = $2;
				shift(@cmts);
				while($args !~ /\)\s*$/ && @cmts) {
					$cont = $cmts[0];
					shift(@cmts);
					$cont =~ s/^\s*#+\s*//;
					$args .= " ".$cont;
					}
				$args = undef if ($args =~ /^\(\s*\)$/);
				}
			if (@cmts || $args) {
				push(@out, "=head2 $name$args");
				push(@out, "");
				if (!@cmts) {
					@cmts = ( "MISSING DOCUMENTATION" );
					}
				foreach $c (@cmts) {
					$c =~ s/^\s*#+\s*//;
					push(@out, $c);
					}
				push(@out, "");
				push(@out, "=cut");
				}
			push(@out, $lines[$i]);
			@cmts = ( );
			$count++;
			}
		elsif ($lines[$i] =~ /^\#/) {
			# Comments - add to temporary list
			push(@cmts, $lines[$i]);
			}
		elsif (scalar(@cmts) == $i && @cmts) {
			# End of first comments block - convert to head1
			push(@out, "=head1 $basef");
			push(@out, "");
			if ($cmts[0] =~ /\Q$basef\E/) {
				shift(@cmts);
				}
			foreach my $c (@cmts) {
				$c =~ s/^\s*#\s*//;
				push(@out, $c);
				}
			push(@out, "");
			push(@out, "=cut");
			push(@out, "");
			@cmts = ( );
			}
		else {
			# Some other line - write out, and flush comments
			push(@out, @cmts, $lines[$i]);
			@cmts = ( );
			}
		$i++;
		}
	print "  Fixed $count functions\n";

	# Write out the file to a temp location
	$temp = "$tempdir/$basef";
	print "  Writing to $temp\n";
	open(TEMP, ">$temp");
	foreach $o (@out) {
		print TEMP $o,"\n";
		}
	close(TEMP);

	# Use perl -c to verify syntax
	$err = `perl -c $temp 2>&1`;
	if ($?) {
		print "  Perl verification FAILED\n";
		next;
		}
	print "  Perl verification OK\n";
	
	# Show diff if asked
	# XXX
	
	# Copy over original file (with cat)
	if ($overwrite) {
		$out = `cat $temp 2>&1 >$f`;
		if ($?) {
			print "  Save FAILED : $out\n";
			}
		else {
			print "  Save OK\n";
			}
		}
	if ($overwrite && $svn) {
		($dirf = $f) =~ s/\/[^\/]+$//;
		$out = `cd $dirf && svn commit -m "$svn" $basef 2>&1`;
		if ($?) {
			print "  SVN FAILED : $out\n";
			}
		else {
			print "  SVN OK\n";
			}
		}
	}

