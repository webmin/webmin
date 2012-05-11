#!/usr/bin/perl
# makemoduledeb.pl
# Create a Debian package for a webmin or usermin module or theme

use POSIX;

$licence = "BSD";
$email = "Jamie Cameron <jcameron\@webmin.com>";
$target_dir = "/tmp";

$tmp_dir = "/tmp/debian-module";
$debian_dir = "$tmp_dir/DEBIAN";
$control_file = "$debian_dir/control";
$preinstall_file = "$debian_dir/preinst";
$postinstall_file = "$debian_dir/postinst";
$preuninstall_file = "$debian_dir/prerm";
$postuninstall_file = "$debian_dir/postrm";
$copyright_file = "$debian_dir/copyright";
$changelog_file = "$debian_dir/changelog";
$files_file = "$debian_dir/files";

-r "/etc/debian_version" || die "makemoduledeb.pl must be run on Debian";

# Parse command-line args
while(@ARGV) {
	local $a = shift(@ARGV);
	if ($a eq "--force-theme") {
		$force_theme = 1;
		}
	elsif ($a eq "--licence" || $a eq "--license") {
		$licence = shift(@ARGV);
		}
	elsif ($a eq "--email") {
		$email = shift(@ARGV);
		}
	elsif ($a eq "--url") {
		$url = shift(@ARGV);
		}
	elsif ($a eq "--upstream") {
		$upstream = shift(@ARGV);
		}
	elsif ($a eq "--deb-depends") {
		$rpmdepends = 1;
		}
	elsif ($a eq "--no-prefix") {
		$no_prefix = 1;
		}
	elsif ($a eq "--usermin") {
		$force_usermin = 1;
		}
	elsif ($a eq "--target-dir") {
		$target_dir = shift(@ARGV);
		}
	elsif ($a eq "--dir") {
		$final_mod = shift(@ARGV);
		}
	elsif ($a eq "--allow-overwrite") {
		$allow_overwrite = 1;
		}
	elsif ($a eq "--dsc-file") {
		$dsc_file = shift(@ARGV);
		}
	elsif ($a =~ /^\-\-/) {
		print STDERR "Unknown option $a\n";
		exit(1);
		}
	else {
		if (!defined($dir)) {
			$dir = $a;
			}
		else {
			$ver = $a;
			}
		}
	}

# Validate args
if (!$dir) {
	print STDERR "usage: makemoduledeb.pl [--force-theme]\n";
	print STDERR "                        [--deb-depends]\n";
	print STDERR "                        [--no-prefix]\n";
	print STDERR "                        [--licence name]\n";
	print STDERR "                        [--email 'name <address>']\n";
	print STDERR "                        [--upstream 'name <address>']\n";
	print STDERR "                        [--provides provides]\n";
	print STDERR "                        [--usermin]\n";
	print STDERR "                        [--target-dir directory]\n";
	print STDERR "                        [--dir directory-in-package]\n";
	print STDERR "                        [--allow-overwrite]\n";
	print STDERR "                        [--dsc-file file.dsc]\n";
	print STDERR "                        <module> [version]\n";
	exit(1);
	}
chop($par = `dirname $dir`);
chop($source_mod = `basename $dir`);
$source_dir = "$par/$source_mod";
$mod = $final_mod || $source_mod;
if ($mod eq "." || $mod eq "..") {
	die "directory must be an actual directory (module) name, not \"$mod\"";
	}

# Is this actually a module or theme directory?
-d $source_dir || die "$source_dir is not a directory";
if (&read_file("$source_dir/module.info", \%minfo) && $minfo{'desc'}) {
	$depends = join(" ", map { s/\/[0-9\.]+//; $_ }
				grep { !/^[0-9\.]+$/ }
				  split(/\s+/, $minfo{'depends'}));
	if ($minfo{'usermin'} && (!$minfo{'webmin'} || $force_usermin)) {
		$prefix = "usermin-";
		$desc = "Usermin module for '$minfo{'desc'}'";
		$product = "usermin";
		}
	else {
		$prefix = "webmin-";
		$desc = "Webmin module for '$minfo{'desc'}'";
		$product = "webmin";
		}
	$iver = $minfo{'version'};
	$post_config = 1;
	}
elsif (&read_file("$source_dir/theme.info", \%tinfo) && $tinfo{'desc'}) {
	if ($tinfo{'usermin'} && (!$tinfo{'usermin'} || $force_usermin)) {
		$prefix = "usermin-";
		$desc = "Usermin theme '$tinfo{'desc'}'";
		$product = "usermin";
		}
	else {
		$prefix = "webmin-";
		$desc = "Webmin theme '$tinfo{'desc'}'";
		$product = "webmin";
		}
	$iver = $tinfo{'version'};
	$istheme = 1;
	$post_config = 0;
	}
else {
	die "$source_dir does not appear to be a webmin module or theme";
	}
$prefix = "" if ($no_prefix);
$usr_dir = "$tmp_dir/usr/share/$product";
$ucproduct = ucfirst($product);
$ver ||= $iver;		# Use module.info version, or 1
$ver ||= 1;
$upstream ||= $email;

# Create the base directories
system("rm -rf $tmp_dir");
mkdir($tmp_dir, 0755);
chmod(0755, $tmp_dir);
mkdir($debian_dir, 0755);
chmod(0755, $debian_dir);
system("mkdir -p $usr_dir");

# Copy the directory to a temp directory
system("cp -r -p -L $source_dir $usr_dir/$mod");
system("echo deb >$usr_dir/$mod/install-type");
system("cd $usr_dir && chmod -R og-w .");
if ($< == 0) {
        system("cd $usr_dir && chown -R root:bin .");
        }
$size = int(`du -sk $tmp_dir`);
system("find $usr_dir -name .svn | xargs rm -rf");
system("find $usr_dir -name .xvpics | xargs rm -rf");
system("find $usr_dir -name '*.bak' | xargs rm -rf");
system("find $usr_dir -name '*~' | xargs rm -rf");
system("find $usr_dir -name '*.rej' | xargs rm -rf");
system("find $usr_dir -name core | xargs rm -rf");

# Fix up Perl paths
system("(find $usr_dir -name '*.cgi' ; find $usr_dir -name '*.pl') | perl -ne 'chop; open(F,\$_); \@l=<F>; close(F); \$l[0] = \"#\!/usr/bin/perl\$1\n\" if (\$l[0] =~ /#\!\\S*perl\\S*(.*)/); open(F,\">\$_\"); print F \@l; close(F)'");
system("(find $usr_dir -name '*.cgi' ; find $usr_dir -name '*.pl') | xargs chmod +x");

# Build list of dependencies on other Debian packages, for inclusion as a
# Requires: header
@rdeps = ( "base", "perl", $product );
if ($rpmdepends) {
	foreach $d (split(/\s+/, $minfo{'depends'})) {
		local ($dwebmin, $dmod, $dver);
		if ($d =~ /^[0-9\.]+$/) {
			# Depends on a version of Webmin
			$dwebmin = $d;
			}
		elsif ($d =~ /^(\S+)\/([0-9\.]+)$/) {
			# Depends on some version of a module
			$dmod = $1;
			$dver = $2;
			}
		else {
			# Depends on any version of a module
			$dmod = $d;
			}

		# If the module is part of Webmin, we don't need to depend on it
		if ($dmod) {
			local %dinfo;
			&read_file("$dmod/module.info", \%dinfo);
			next if ($dinfo{'longdesc'});
			}
		push(@rdeps, $dwebmin ? ("$product (>= $dwebmin)") :
			     $dver ? ("$prefix$dmod (>= $dver)") :
				     ($prefix.$dmod));
		}
	}
$rdeps = join(", ", @rdeps);

# Create the control file
$kbsize = int(($size-1) / 1024)+1;
open(CONTROL, ">$control_file");
print CONTROL <<EOF;
Package: $prefix$mod
Version: $ver
Section: admin
Priority: optional
Architecture: all
Essential: no
Depends: $rdeps
Pre-Depends: bash, perl
Installed-Size: $kbsize
Maintainer: $email
Provides: $prefix$mod
Description: $desc
EOF
close(CONTROL);

# Create the copyright file
$nowstr = strftime("%a, %d %b %Y %H:%M:%S %z", localtime(time()));
open(COPY, ">$copyright_file");
print COPY "This package was debianized by $email on\n";
print COPY "$nowstr.\n";
print COPY "\n";
if ($url) {
	print COPY "It was downloaded from: $url\n";
	print COPY "\n";
	}
print COPY "Upstream author: $upstream\n";
print COPY "\n";
print COPY "Copyright: $licence\n";
close(COPY);

# Read the module's CHANGELOG file
$changes = { };
$f = "$usr_dir/$mod/CHANGELOG";
if (-r $f) {
	# Read its change log file
	local $inversion;
	open(LOG, $f);
	while(<LOG>) {
		s/\r|\n//g;
		if (/^----\s+Changes\s+since\s+(\S+)\s+----/) {
			$inversion = $1;
			}
		elsif ($inversion && /\S/) {
			push(@{$changes->{$inversion}}, $_);
			}
		}
	close(LOG);
	}

# Create the changelog file from actual changes
if (%$changes) {
	open(CHANGELOG, ">$changelog_file");
	foreach $v (sort { $a <=> $b } (keys %$changes)) {
		if ($ver > $v && sprintf("%.2f0", $ver) == $v) {
			$forv = $ver;
			}
		else {
			$forv = sprintf("%.2f0", $v+0.01);
			}
		print CHANGELOG "$prefix$mod ($forv) stable; urgency=low\n";
		print CHANGELOG "\n";
		foreach $c (@{$changes->{$v}}) {
			@lines = &wrap_lines($c, 65);
			print CHANGELOG " * $lines[0]\n";
			foreach $l (@lines[1 .. $#lines]) {
				print CHANGELOG "   $l\n";
				}
			}
		print CHANGELOG "\n";
		print CHANGELOG "-- $email\n";
		print CHANGELOG "\n";
		}
	}
close(CHANGELOG);

# Create the pre-install script, which checks if Webmin is installed
open(SCRIPT, ">$preinstall_file");
print SCRIPT <<EOF;
#!/bin/sh
if [ ! -r /etc/$product/config -o ! -d /usr/share/$product ]; then
	echo "$ucproduct does not appear to be installed on your system."
	echo "This package cannot be installed unless the Debian version of $ucproduct"
	echo "is installed first."
	exit 1
fi
if [ "$depends" != "" -a "$debdepends" != 1 ]; then
	# Check if depended webmin/usermin modules are installed
	for d in $depends; do
		if [ ! -r /usr/share/$product/\$d/module.info ]; then
			echo "This $ucproduct module depends on the module \$d, which is"
			echo "not installed on your system."
			exit 1
		fi
	done
fi
# Check if this module is already installed
if [ -d /usr/share/$product/$mod -a "\$1" != "upgrade" -a "$allow_overwrite" != "1" ]; then
	echo "This $ucproduct module is already installed on your system."
	exit 1
fi
EOF
close(SCRIPT);
system("chmod 755 $preinstall_file");

# Create the post-install script
open(SCRIPT, ">$postinstall_file");
print SCRIPT <<EOF;
#!/bin/sh
if [ "$post_config" = "1" ]; then
	# Copy config file to /etc/webmin or /etc/usermin
	os_type=`grep "^os_type=" /etc/$product/config | sed -e 's/os_type=//g'`
	os_version=`grep "^os_version=" /etc/$product/config | sed -e 's/os_version=//g'`
	/usr/bin/perl /usr/share/$product/copyconfig.pl \$os_type \$os_version /usr/share/$product /etc/$product $mod

	# Update the ACL for the root user, or the first user in the ACL
	grep "^root:" /etc/$product/webmin.acl >/dev/null
	if [ "\$?" = "0" ]; then
		user=root
	else
		user=`head -1 /etc/$product/webmin.acl | cut -f 1 -d :`
	fi
	mods=`grep \$user: /etc/$product/webmin.acl | cut -f 2 -d :`
	echo \$mods | grep " $mod" >/dev/null
	if [ "\$?" != "0" ]; then
		grep -v ^\$user: /etc/$product/webmin.acl > /tmp/webmin.acl.tmp
		echo \$user: \$mods $mod > /etc/$product/webmin.acl
		cat /tmp/webmin.acl.tmp >> /etc/$product/webmin.acl
		rm -f /tmp/webmin.acl.tmp
	fi
fi
if [ "$force_theme" != "" -a "$istheme" = "1" ]; then
	# Activate this theme
	grep -v "^preroot=" /etc/$product/miniserv.conf >/etc/$product/miniserv.conf.tmp
	(cat /etc/$product/miniserv.conf.tmp ; echo preroot=$mod) > /etc/$product/miniserv.conf
	rm -f /etc/$product/miniserv.conf.tmp
	grep -v "^theme=" /etc/$product/config >/etc/$product/config.tmp
	(cat /etc/$product/config.tmp ; echo theme=$mod) > /etc/$product/config
	rm -f /etc/$product/config.tmp
	(/etc/$product/stop && /etc/$product/start) >/dev/null 2>&1
fi
rm -f /etc/$product/module.infos.cache

# Run post-install function
if [ "$product" = "webmin" ]; then
	cd /usr/share/$product
	WEBMIN_CONFIG=/etc/$product WEBMIN_VAR=/var/$product /usr/share/$product/run-postinstalls.pl $mod
fi

# Run post-install shell script
if [ -r "/usr/share/$product/$mod/postinstall.sh" ]; then
	cd /usr/share/$product
	WEBMIN_CONFIG=/etc/$product WEBMIN_VAR=/var/$product /usr/share/$product/$mod/postinstall.sh
fi
EOF
close(SCRIPT);
system("chmod 755 $postinstall_file");

# Create the pre-uninstall script
open(SCRIPT, ">$preuninstall_file");
print SCRIPT <<EOF;
#!/bin/sh
# De-activate this theme, if in use and if we are not upgrading
if [ "$istheme" = "1" -a "\$1" != "upgrade" ]; then
	grep "^preroot=$mod" /etc/$product/miniserv.conf >/dev/null
	if [ "\$?" = "0" ]; then
		grep -v "^preroot=$mod" /etc/$product/miniserv.conf >/etc/$product/miniserv.conf.tmp
		(cat /etc/$product/miniserv.conf.tmp) > /etc/$product/miniserv.conf
		rm -f /etc/$product/miniserv.conf.tmp
		grep -v "^theme=$mod" /etc/$product/config >/etc/$product/config.tmp
		(cat /etc/$product/config.tmp) > /etc/$product/config
		rm -f /etc/$product/config.tmp
		(/etc/$product/stop && /etc/$product/start) >/dev/null 2>&1
	fi
fi
# Run the pre-uninstall script, if we are not upgrading
if [ "$product" = "webmin" -a "\$1" = "0" -a -r "/usr/share/$product/$mod/uninstall.pl" ]; then
	cd /usr/share/$product
	WEBMIN_CONFIG=/etc/$product WEBMIN_VAR=/var/$product /usr/share/$product/run-uninstalls.pl $mod
fi
/bin/true
EOF
close(SCRIPT);
system("chmod 755 $preuninstall_file");

# Run the actual build command
system("fakeroot dpkg --build $tmp_dir $target_dir/${prefix}${mod}_${ver}_all.deb") &&
        die "dpkg failed";
print "Wrote $target_dir/${prefix}${mod}_${ver}_all.deb\n";

# Create the .dsc file, if requested
if ($dsc_file) {
	# Create the .diff file, which just contains the debian directory
	$diff_file = $dsc_file;
	$diff_file =~ s/[^\/]+$//; $diff_file .= "$prefix$mod-$ver.diff";
	$diff_orig_dir = "$tmp_dir/$prefix$mod-$ver-orig";
	$diff_new_dir = "$tmp_dir/$prefix$mod-$ver";
	mkdir($diff_orig_dir, 0755);
	mkdir($diff_new_dir, 0755);
	system("cp -r $debian_dir $diff_new_dir");
	system("cd $tmp_dir && diff -r -N -u $prefix$mod-$ver-orig $prefix$mod-$ver >$diff_file");
	$diffmd5 = `md5sum $diff_file`;
	$diffmd5 =~ s/\s+.*\n//g;
	@diffst = stat($diff_file);

	# Create a tar file of the module directory
	$tar_file = $dsc_file;
	$tar_file =~ s/[^\/]+$//; $tar_file .= "$prefix$mod-$ver.tar.gz";
	system("cd $par ; tar czf $tar_file $source_mod");
	$md5 = `md5sum $tar_file`;
	$md5 =~ s/\s+.*\n//g;
	@st = stat($tar_file);

	# Finally create the .dsc
	open(DSC, ">$dsc_file");
	print DSC <<EOF;
Format: 1.0
Source: $prefix$mod
Version: $ver
Binary: $prefix$mod
Maintainer: $email
Architecture: all
Standards-Version: 3.6.1
Build-Depends-Indep: debhelper (>= 4.1.16), debconf (>= 0.5.00), perl
Uploaders: Jamie Cameron <jcameron\@webmin.com>
Files:
  $md5 $st[7] ${prefix}${mod}-$ver.tar.gz
  $diffmd5 $diffst[7] ${prefix}${mod}-${ver}.diff
EOF
	close(DSC);
	}

# Clean up
system("rm -rf $tmp_dir");

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
        }
close(ARFILE);
return 1;
}

# wrap_lines(text, width)
# Given a multi-line string, return an array of lines wrapped to
# the given width
sub wrap_lines
{
local @rv;
local $w = $_[1];
local $rest;
foreach $rest (split(/\n/, $_[0])) {
	if ($rest =~ /\S/) {
		while($rest =~ /^(.{1,$w}\S*)\s*([\0-\377]*)$/) {
			push(@rv, $1);
			$rest = $2;
			}
		}
	else {
		# Empty line .. keep as it is
		push(@rv, $rest);
		}
	}
return @rv;
}


