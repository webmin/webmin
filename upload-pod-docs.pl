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
	    [ "web-lib-funcs.pl", "web-lib.pl", "ui-lib.pl" ],
	    "Core Webmin API" ] );
foreach my $mi (glob("*/module.info")) {
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
	my $desc = $midata =~ /desc=(.*)/ ? $1 : $mod;
	$desc .= " module";
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
		push(@mods, [ "Module $mod", $mod, \@podlibs, $desc ]);
		}
	}

# For each, run Pod to Wiki conversion
system("rm -rf $temp_pod_dir ; mkdir $temp_pod_dir");
foreach $m (@mods) {
	print STDERR "Doing module $m->[0]\n";
	my $wikiname = $m->[1] eq "." ? "ApiWebminCore"
				      : "Api".join("", map { ucfirst($_) }
						split(/\-/, $m->[1]));
	push(@$m, $wikiname);
	my $infile = "/tmp/pod2twiki.in";
	open(INFILE, ">$infile");
	foreach $f (@{$m->[2]}) {
		# Replace un-decorated =item with =item *
		# This is kosher according to the POD docs, but Pod2wiki doesn't
		# seem to like it
		print STDERR "Doing file $f\n";
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
		}
	close(INFILE);

	# Do the conversion
	my $outfile = "$temp_pod_dir/$wikiname.txt";
	open(OUTFILE, ">$outfile");
	print OUTFILE "%TOC%\n\n";
	if ($m->[1] eq ".") {
		print OUTFILE "---+ Core Webmin API\n\n";
		}
	else {
		print OUTFILE "---+ Functions from module $m->[1]\n\n";
		}
	open(INFILE, $infile);
	my $parser = Pod::Simple::Wiki->new('twiki');
	$parser->output_fh(*OUTFILE);
	$parser->parse_file(*INFILE);
	close(INFILE);
	close(OUTFILE);

	# Remove errors block
	open(OUT, $outfile);
	my @lines = <OUT>;
	close(OUT);
	open(OUT, ">$outfile");
	my $verbatim = 0;
	foreach my $l (@lines) {
		last if ($l =~ /POD\s+ERRORS/);
		if ($l =~ /<verbatim>/) {
			$verbatim = 1;
			}
		elsif ($l =~ /<\/verbatim>/) {
			$verbatim = 0;
			}
		elsif (!$verbatim) {
			$l = &html_escape($l);
			}
		print OUT $l;
		}
	close(OUT);
	}

# Create summary page
open(SUMM, ">$temp_pod_dir/TheWebminAPI.txt");
print SUMM "---+ The Webmin API\n\n";
print SUMM <<EOF;
The Webmin API has a set of core functions that are available to all modules,
and functions exported by other modules that yours can optionally use. The APIs
for which documentation is available are linked to below :

EOF
foreach my $m (@mods) {
	print SUMM "   * [[$m->[4]][$m->[3]]]\n";
	}
close(SUMM);

# Upload to doxfer
print STDERR "Uploading to $doxfer_host\n";
system("scp $temp_pod_dir/*.txt doxfer\@$doxfer_host:/home/doxfer/public_html/twiki/data/Webmin/");
print STDERR "done\n";

sub html_escape
{
my ($tmp) = @_;
$tmp =~ s/&/&amp;/g;
$tmp =~ s/</&lt;/g;
$tmp =~ s/>/&gt;/g;
$tmp =~ s/\"/&quot;/g;
$tmp =~ s/\'/&#39;/g;
$tmp =~ s/=/&#61;/g;
return $tmp;
}


