#!/usr/local/bin/perl
# Convert words in lang/en files from UK to US spelling.
# Create lang/en_GB files containing words that are different.

if ($ARGV[0] eq "--svn" || $ARGV[0] eq "-svn" ||
    $ARGV[0] eq "--git" || $ARGV[0] eq "-git") {
	shift(@ARGV);
	$svn = shift(@ARGV);
	}

chdir("/usr/local/webadmin");
if (@ARGV) {
	@modules = @ARGV;
	}
else {
	@modules = ( "." );
	opendir(DIR, ".");
	foreach $d (readdir(DIR)) {
		push(@modules, $d) if (-r "$d/module.info");
		}
	closedir(DIR);
	}

# Get the words
open(MAPPING, "english-mappings.txt") ||
	die "Failed to open english-mappings.txt";
while(<MAPPING>) {
	s/\r|\n//g;
	s/#.*$//;
	my ($us, $uk) = split(/\t+/, $_);
	if ($us && $uk) {
		push(@us_mappings, [ $us, $uk ]);
		}
	}
close(MAPPING);
@uk_mappings = map { [ $_->[1], $_->[0] ] } @us_mappings;
print STDERR "Found ",scalar(@uk_mappings)," mappings\n";

# Do all the given modules
@rv = ( );
foreach $m (@modules) {
	print STDERR "Doing module $m\n";
	push(@rv, &fix_english_file("$m/lang/en", "$m/lang/en_GB", 1));
	push(@rv, &fix_english_file("$m/config.info",
				    "$m/config.info.en_GB", 1));
	opendir(HELP, "$m/help");
	foreach $h (readdir(HELP)) {
		if ($h =~ /^([^\.]+)\.html$/) {
			push(@rv, &fix_english_file("$m/help/$h",
					  "$m/help/$1.en_GB.html", 0));
			}
		}
	closedir(HELP);
	}

# Print and commit the files
foreach $f (@rv) {
	print $f,"\n";
	if ($svn) {
		($dir, $rest) = split(/\//, $f, 2);
		system("cd $dir ; git add $rest ; git commit -m '$svn' $rest ; git push");
		}
	}

sub fix_english_file
{
local ($us, $uk, $linefmt) = @_;
return ( ) if (!-r $us);
local @rv;
if ($linefmt) {
	# Webmin = separated line file

	# First fix up any UK spellings in the US file
	local %uslines;
	&read_file($us, \%uslines);
	local $changed_us;
	foreach my $k (keys %uslines) {
		$v = $uslines{$k};
		$usv = &convert_to_us($v);
		if ($usv ne $v) {
			$uslines{$k} = $usv;
			$changed_us++;
			}
		}
	if ($changed_us) {
		&write_file($us, \%uslines);
		push(@rv, $us);
		}

	# Then create a UK file with only lines that need changing
	local %uklines;
	&read_file($uk, \%uklines);
	local $changed_uk;
	foreach my $k (keys %uslines) {
		$v = $uslines{$k};
		$ukv = &convert_to_uk($v);
		if ($ukv ne $v && $uklines{$k} ne $ukv) {
			$uklines{$k} = $ukv;
			$changed_uk++;
			}
		}
	if ($changed_uk) {
		&write_file($uk, \%uklines);
		push(@rv, $uk);
		}
	}
else {
	# Big blob of text

	# First fix up any UK spellings in the US file
	local $ustext = &read_file_contents($us);
	$usv = &convert_to_us($ustext);
	if ($usv ne $ustext) {
		&write_file_contents($us, $usv);
		push(@rv, $us);
		}

	# Then create a UK file
	$uktext = &read_file_contents($uk);
	$ukv = &convert_to_uk($usv);
	if ($uktext ne $ukv && $ukv ne $usv) {
		&write_file_contents($uk, $ukv);
		push(@rv, $uk);
		}
	}
return @rv;
}

sub convert_to_us
{
local ($str) = @_;
return &convert_mapping($str, \@uk_mappings);
}

sub convert_to_uk
{
local ($str) = @_;
return &convert_mapping($str, \@us_mappings);
}

sub convert_mapping
{
local ($str, $fromto) = @_;
foreach my $w (@$fromto) {
	my ($from, $to) = @$w;
	$str =~ s/(\s|^)\Q$from\E(\s|$)/$1$to$2/g;
	$from = ucfirst($from);
	$to = ucfirst($to);
	$str =~ s/(\s|^)\Q$from\E(\s|$)/$1$to$2/g;
	}
return $str;
}

# read_file(file, &assoc, [&order], [lowercase])
# Fill an associative array with name=value pairs from a file
sub read_file
{
open(ARFILE, $_[0]) || return 0;
while(<ARFILE>) {
	s/\r|\n//g;
        if (!/^#/ && /^([^=]+)=(.*)$/) {
		$_[1]->{$_[3] ? lc($1) : $1} = $2;
		push(@{$_[2]}, $1) if ($_[2]);
        	}
	elsif (!/\S/) {
		push(@{$_[2]}, undef) if ($_[2]);
		}
        }
close(ARFILE);
return 1;
}
 
# write_file(file, array)
# Write out the contents of an associative array as name=value lines
sub write_file
{
local(%old, @order);
&read_file($_[0], \%old, \@order);
open(ARFILE, ">$_[0]");
foreach $k (@order) {
	if (!defined($k)) {
		print ARFILE "\n";
		}
	elsif (exists($_[1]->{$k})) {
		print ARFILE $k,"=",$_[1]->{$k},"\n";
		}
	}
foreach $k (keys %{$_[1]}) {
        print ARFILE $k,"=",$_[1]->{$k},"\n" if (!exists($old{$k}));
        }
close(ARFILE);
}

sub read_file_contents
{
open(FILE, $_[0]) || return undef;
local $/ = undef;
local $rv = <FILE>;
close(FILE);
return $rv;
}

sub write_file_contents
{
open(FILE, ">$_[0]") || return undef;
print FILE $_[1];
close(FILE);
}

