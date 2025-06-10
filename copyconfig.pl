#!/usr/local/bin/perl
# copyconfig.pl
# Copy the appropriate config file for each module into the webmin config
# directory. If it is already there, merge in new directives. Called with
# <osname> <osversion> <install dir> <config dir> <module>+

@ARGV >= 4 || die "usage: copyconfig.pl <os>[/real-os] <version>[/real-version] <webmin-dir> <config-dir> [module ...]";
$os = $ARGV[0];
$ver = $ARGV[1];
$wadir = $ARGV[2];
$confdir = $ARGV[3];
($os, $real_os) = split(/\//, $os);
($ver, $real_ver) = split(/\//, $ver);
$real_os =~ s/ /-/g;
$real_ver =~ s/ /-/g;

# Find all clones
opendir(DIR, $wadir);
foreach $f (readdir(DIR)) {
	if (readlink("$wadir/$f")) {
		@st = stat("$wadir/$f");
		push(@{$clone{$st[1]}}, $f);
		}
	}
closedir(DIR);

# For each module, copy its config to itself and all clones
@mods = @ARGV[4..$#ARGV];
foreach $m (@mods) {
	# Find any range-number config files. Search first by real OS type
	# (ie Ubuntu 6.1), then by internal OS code (ie. debian-linux 3.1)
	$srcdir = "$wadir/$m";
	$rangefile = $real_rangefile = undef;
	foreach $ov ([ $real_os, $real_ver, \$real_rangefile ],
		     [ $os, $ver, \$rangefile ]) {
		my ($o, $v, $rf) = @$ov;
		opendir(DIR, $srcdir);
		while($f = readdir(DIR)) {
			if ($f =~ /^config\-\Q$o\E\-([0-9\.]+)\-([0-9\.]+)$/ &&
			    $v >= $1 && $v <= $2) {
				$$rf = "$srcdir/$f";
				}
			elsif ($f =~ /^config\-\Q$o\E\-([0-9\.]+)\-(\*|ALL)$/ &&
			       $v >= $1) {
				$$rf = "$srcdir/$f";
				}
			elsif ($f =~ /^config\-\Q$o\E\-(\*|ALL)\-([0-9\.]+)$/ &&
			       $v <= $2) {
				$$rf = "$srcdir/$f";
				}
			}
		closedir(DIR);
		}

	# Find the best-matching config file. Search first by real OS type,
	# then by internal OS code

	# Check for real OS match by name and version, version range, or
	# name only
	if (-r "$srcdir/config-$real_os-$real_ver") {
		$conf = "$srcdir/config-$real_os-$real_ver";
		}
	elsif ($real_rangefile) {
		$conf = $real_rangefile;
		}
	elsif (-r "$srcdir/config-$real_os") {
		$conf = "$srcdir/config-$real_os";
		}

	# Check for OS code match by name and version, version range, or name
	elsif (-r "$srcdir/config-$os-$ver") {
		$conf = "$srcdir/config-$os-$ver";
		}
	elsif ($rangefile) {
		$conf = $rangefile;
		}
	elsif (-r "$srcdir/config-$os") {
		$conf = "$srcdir/config-$os";
		}

	# Check for config for an entire OS class, like *-linux
	elsif ($os =~ /^(\S+)-(\S+)$/ && -r "$srcdir/config-ALL-$2") {
		$conf = "$srcdir/config-ALL-$2";
		}
	elsif ($os =~ /^(\S+)-(\S+)$/ && -r "$srcdir/config-*-$2") {
		$conf = "$srcdir/config-*-$2";
		}

	# Use default config file, if it exists
	elsif (-r "$srcdir/config") {
		$conf = "$srcdir/config";
		}
	else {
		$conf = "/dev/null";
		}

	@st = stat($srcdir);
	@copyto = ( @{$clone{$st[1]}}, $m );
	foreach $c (@copyto) {
		if (!-d "$confdir/$c") {
			# New module .. need to create config dir
			mkdir("$confdir/$c", 0755);
			push(@newmods, $c);
			}
		undef(%oldconf); undef(%newconf);
		&read_file("$confdir/$c/config", \%oldconf);
		&read_file($conf, \%newconf);
		foreach $k (keys %oldconf) {
			$newconf{$k} = $oldconf{$k};
			}
		&write_file("$confdir/$c/config", \%newconf);
		}
	}
print join(" ", @newmods),"\n";

# read_file(file, &hash, [&order], [lowercase], [split-char])
# Fill the given hash reference with name=value pairs from a file.
sub read_file
{
my ($file, $hash, $order, $lowercase, $split) = @_;
$split = "=" if (!defined($split));
open(ARFILE, $file) || return 0;
local $_;
while(<ARFILE>) {
	s/\r|\n//g;
	my $cmt = index($_, "#");
	my $eq = index($_, $split);
	if ($cmt != 0 && $eq >= 0) {
		my $n = substr($_, 0, $eq);
		my $v = substr($_, $eq+1);
		chomp($v);
		$hash->{$lowercase ? lc($n) : $n} = $v;
		push(@$order, $n) if ($order);
        	}
        }
close(ARFILE);
return 1;
}

# write_file(file, &data-hash, [join-char])
# Write out the contents of a hash as name=value lines.
sub write_file
{
my ($file, $data_hash, $join_char) = @_;
my (%old, @order);
my $join = defined($join_char) ? $join_char : "=";
&read_file($file, \%old, \@order);
open(ARFILE, ">$file") || die "open of $file failed : $!";
my %done;
foreach $k (@order) {
	if (exists($data_hash->{$k}) && !$done{$k}++) {
		(print ARFILE $k,$join,$data_hash->{$k},"\n") ||
			die "write to $file failed : $!";
		}
	}
foreach $k (keys %{$data_hash}) {
	if (!exists($old{$k}) && !$done{$k}++) {
		(print ARFILE $k,$join,$data_hash->{$k},"\n") ||
			die "write to $file failed : $!";
		}
	}
close(ARFILE);
}
