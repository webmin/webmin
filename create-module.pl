#!/usr/local/bin/perl
# create-module.pl
# Creates a single .wbm file containing multiple modules, possibly with
# forced versions

@ARGV >= 2 || die "usage: create-module.pl [--dir name] <file.wbm> <module>[/version] ..";

chop($pwd = `pwd`);

# Parse command-line options
while(@ARGV) {
	if ($ARGV[0] eq "--dir") {
		shift(@ARGV);
		$forcedir = shift(@ARGV);
		}
	elsif ($ARGV[0] eq "--sign") {
		shift(@ARGV);
		$createsig = 1;
		}
	else {
		last;
		}
	}

$file = shift(@ARGV);
if ($file !~ /^\//) {
	$file = "$pwd/$file";
	}
unlink($file);
foreach $m (@ARGV) {
	# Parse module and forced version
	$m =~ s/\/$//;
	if ($m =~ /^(.*)\/(.*)$/) {
		$mod = $1;
		$ver = $2;
		}
	else {
		$mod = $m;
		$ver = undef;
		}

	# Copy module to temp dir
	system("rm -rf /tmp/create-module");
	mkdir("/tmp/create-module", 0755);
	$subdir = $forcedir || $mod;
	$copydir = "/tmp/create-module/$subdir";
	system("rm -rf $copydir");
	system("cp -r -L $mod $copydir 2>/dev/null || cp -R -L $mod $copydir");

	# Find type from .info file
	undef(%minfo);
	if (&read_file($ifile = "$copydir/module.info", \%minfo)) {
		$type = 0;
		}
	elsif (&read_file($ifile = "$copydir/theme.info", \%minfo)) {
		$type = 1;
		}
	else {
		die "Module or theme $mod not found";
		}
	if ($ver) {
		$minfo{'version'} = $ver;
		&write_file($ifile, \%minfo);
		}
	$flags = !-r $file ? "chf" : "rhf";
	system("cd /tmp/create-module && find . -name .svn | xargs rm -rf");
	system("cd /tmp/create-module && find . -name '*~' -o -name '*.rej' -o -name '*.orig' -o -name '.*.swp' | xargs rm -rf");
	unlink("/tmp/create-module/$subdir/IDEAS");
	system("cd /tmp/create-module && find . -name \\*.svn-work | xargs rm -rf");
	system("cd /tmp/create-module && find . -name \\*.svn-base | xargs rm -rf");
	system("cd /tmp/create-module && find . -name \\*.cgi | xargs chmod +x");
	system("cd /tmp/create-module && find . -name \\*.pl | xargs chmod +x");
	system("cd /tmp/create-module && tar $flags $file $subdir") && die "Failed to create tar file";
	}
if ($file =~ /^(.*)\.gz$/i) {
	system("mv $file $1");
	system("gzip -c $1 >$file");
	unlink("$1");
	}
if ($createsig) {
	system("rm -f $file-sig.asc");
	system("gpg --armor --output $file-sig.asc --detach-sig $file");
	}

# read_file(file, &assoc, [&order], [lowercase])
# Fill an associative array with name=value pairs from a file
sub read_file
{
open(ARFILE, $_[0]) || return 0;
while(<ARFILE>) {
	s/\r|\n//g;
        if (!/^#/ && /^([^=]*)=(.*)$/) {
		$_[1]->{$_[3] ? lc($1) : $1} = $2;
		push(@{$_[2]}, $1) if ($_[2]);
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
        print ARFILE $k,"=",$_[1]->{$k},"\n" if (exists($_[1]->{$k}));
	}
foreach $k (keys %{$_[1]}) {
        print ARFILE $k,"=",$_[1]->{$k},"\n" if (!exists($old{$k}));
        }
close(ARFILE);
}
