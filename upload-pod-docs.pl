#!/usr/local/bin/perl
# Upload all Webmin API docs in TWiki format to doxfer.com

use Pod::Simple::Wiki;

$doxfer_host = "doxfer.com";
$doxfer_dir = "/home/doxfer/public_html/twiki/data/Webmin";
$temp_pod_dir = "/tmp/doxfer-wiki";

if ($0 =~ /^(.*\/)[^\/]+$/) {
        chdir($1);
        }
chop($pwd = `pwd`);

# Build list of modules
@mods = ( [ "WebminCore", ".",
	    [ "web-lib-funcs.pl", "web-lib.pl", "ui-lib.pl" ] ] );
foreach my $mi (glob("*/module.info")) {
	# XXX add non-core modules
	my $mod;
	($mod = $mi) =~ s/\/module.info//;
	next if (-l $mod);
	my $midata = `cat $mi`;
	my @modlibs;
	if ($midata =~ /library=(.*)/) {
		@modlibs = split(/\s+/, $1);
		}
	else {
		@modlibs = ( $mod."-lib.pl" );
		}
	my @podlibs;
	foreach my $f (@modlibs) {
		if (-r "$mod/$f") {
			my $data = `cat $mod/$f`;
			if ($data =~ /=head1/) {
				push(@podlibs, $f);
				}
			}
		}
	if (@podlibs) {
		push(@mods, [ "Module $mod", $mod, \@podlibs ]);
		}
	}

# For each, run Pod to Wiki conversion
system("rm -rf $temp_pod_dir ; mkdir $temp_pod_dir");
foreach $m (@mods) {
	print STDERR "Doing module $m->[0]\n";
	my $parser = Pod::Simple::Wiki->new('twiki');
	my $wikiname = $m->[1] eq "." ? "ApiWebminCore"
				      : "Api".join("", map { ucfirst($_) }
						split(/\-/, $m->[1]));
	my $outfile = "$temp_pod_dir/$wikiname.txt";
	open(OUTFILE, ">$outfile");
	if ($m->[1] eq ".") {
		print OUTFILE "---+ Core Webmin API\n\n";
		}
	else {
		print OUTFILE "---+ Functions from module $m->[1]\n\n";
		}
	foreach $f (@{$m->[2]}) {
		# Replace un-decorated =item with =item *
		# This is kosher according to the POD docs, but Pod2wiki doesn't
		# seem to like it
		print STDERR "Doing file $f\n";
		my $infile = "/tmp/pod2twiki.in";
		open(INFILE, ">$infile");
		open(ORIGFILE, "$m->[1]/$f");
		while(<ORIGFILE>) {
			if (/^=item\s+([^\*].*)/) {
				print INFILE "=item * $1\n";
				}
			else {
				print INFILE $_;
				}
			}
		close(ORIGFILE);
		close(INFILE);

		# Do the conversion
		open(INFILE, $infile);
		$parser->output_fh(*OUTFILE);
		$parser->parse_file(*INFILE);
		close(INFILE);
		}
	close(OUTFILE);

	# Remove errors block
	open(OUT, $outfile);
	my @lines = <OUT>;
	close(OUT);
	open(OUT, ">$outfile");
	foreach my $l (@lines) {
		last if ($l =~ /POD\s+ERRORS/);
		print OUT $l;
		}
	close(OUT);
	}

# Upload to doxfer
print STDERR "Uploading to $doxfer_host\n";
system("scp $temp_pod_dir/*.txt doxfer\@$doxfer_host:/home/doxfer/public_html/twiki/data/Webmin/");
print STDERR "done\n";
