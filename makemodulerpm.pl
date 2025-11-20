#!/usr/bin/perl
# makemodulerpm.pl
# Create an RPM for a webmin or usermin module or theme
use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
use 5.010;

# Colors!
use Term::ANSIColor qw(:constants);

my $basedir;

# Does any system still have a redhat dir?
if (-d "$ENV{'HOME'}/redhat") {
	$basedir = "$ENV{'HOME'}/redhat";
	}
elsif (-d "$ENV{'HOME'}/rpmbuild") {
	$basedir = "$ENV{'HOME'}/rpmbuild";
	}
elsif ( -d "/usr/src/redhat") {
	$basedir = "/usr/src/redhat";
	}
else {
	$basedir = "/usr/src/rpmbuild";
	}
my $target_dir = "$basedir" . "/RPMS/noarch";	# where to copy the RPM to

my $licence = "BSD";
my $release = 1;
$ENV{'PATH'} = "/bin:/usr/bin:/usr/local/bin:/sbin:/usr/sbin";
my $allow_overwrite = 0;

my ($force_theme, $no_prefix, $set_prefix,
    $obsolete_wbm, $vendor, $url, $force_usermin, $final_mod, $sign, $keyname,
    $epoch, $dir, $ver, @exclude, $copy_tar,

    $rpmdepends, $norpmdepends, $rpmrecommends, $norpmrecommends,
    $no_requires, $no_recommends, $no_suggests, $no_conflicts, $no_provides,
    $no_obsoletes);

my $mod_list  = 'full';

# Parse command-line args
while(@ARGV) {
	# XXX Untainting isn't needed when running as non-root?
	my $a = &untaint(shift(@ARGV));
	if ($a eq "--rpm-depends" || $a eq "--mod-depends") {
		$rpmdepends = 1;
		}
	elsif ($a eq "--no-mod-depends") {
		$norpmdepends = 1;
		}
	elsif ($a eq "--rpm-recommends" || $a eq "--mod-recommends") {
		$rpmrecommends = 1;
		}
	elsif ($a eq "--no-mod-recommends") {
		$norpmrecommends = 1;
		}
	# --requires, --recommends, --suggests, --conflicts, --provides and
	# --obsoletes are not for Webmin modules, and not meant to have prefix,
	# and populated from module.info automatically
	# --no-requires, --no-recommends, --no-suggests,
	# --no-conflicts, --no-provides, --no-obsoletes can be used
	# to disable the automatic population of these fields from module.info
	elsif ($a eq "--no-requires") {
		$no_requires = 1;
		}
	elsif ($a eq "--no-recommends") {
		$no_recommends = 1;
		}
	elsif ($a eq "--no-suggests") {
		$no_suggests = 1;
		}
	elsif ($a eq "--no-conflicts") {
		$no_conflicts = 1;
		}
	elsif ($a eq "--no-provides") {
		$no_provides = 1;
		}
	elsif ($a eq "--no-obsoletes") {
		$no_obsoletes = 1;
		}
	elsif ($a eq "--no-prefix") {
		$no_prefix = 1;
		}
	elsif ($a eq "--prefix") {
		$set_prefix = &untaint(shift(@ARGV));
		}
	elsif ($a eq "--obsolete-wbm") {
		$obsolete_wbm = 1;
		}
	elsif ($a eq "--licence" || $a eq "--license") {
		$licence = &untaint(shift(@ARGV));
		}
	elsif ($a eq "--url") {
		$url = shift(@ARGV);
		}
	elsif ($a eq "--release") {
		$release = &untaint(shift(@ARGV));
		}
	elsif ($a eq "--usermin") {
		$force_usermin = 1;
		}
	elsif ($a eq "--target-dir") {
		$target_dir = &untaint(shift(@ARGV));
		}
	elsif ($a eq "--dir") {
		$final_mod = &untaint(shift(@ARGV));
		}
	elsif ($a eq "--allow-overwrite") {
		$allow_overwrite = 1;
		}
	elsif ($a eq "--force-theme") {
		$force_theme = 1;
		}
	elsif ($a eq "--rpm-dir") {
		$basedir = &untaint(shift(@ARGV));
		}
	elsif ($a eq "--vendor") {
		$vendor = &untaint(shift(@ARGV));
		}
	elsif ($a eq "--sign") {
		$sign = 1;
		}
	elsif ($a eq "--key") {
		$keyname = shift(@ARGV);
		}
	elsif ($a eq "--epoch") {
		$epoch = shift(@ARGV);
		}
	elsif ($a eq "--exclude") {
		push(@exclude, shift(@ARGV));
		}
	elsif ($a eq "--mod-list") {
		$mod_list = shift(@ARGV);
		}
	elsif ($a eq "--copy-tar") {
		$copy_tar = 1;
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

# Disable module's depends and recommends if set in extra flags
$rpmdepends = 0 if ($norpmdepends);
$rpmrecommends = 0 if ($norpmrecommends);

# Validate args
if (!$dir) {
	print "usage: ";
	print CYAN, "makemodulerpm.pl <module> [version]", RESET;
	print YELLOW, "\n";
	print "                        [--mod-depends] [--no-mod-depends]\n";
	print "                        [--mod-recommends] [--no-mod-recommends]\n";
	print "			       [--no-requires]\n";
	print "			       [--no-suggests]\n";
	print "			       [--no-conflicts]\n";
	print "			       [--no-provides]\n";
	print "			       [--no-obsoletes]\n";
	print "                        [--rpm-dir directory]\n";
	print "                        [--no-prefix]\n";
	print "                        [--prefix prefix]\n";
	print "                        [--no-wbm-prefix]\n";
	print "                        [--vendor name]\n";
	print "                        [--licence name]\n";
	print "                        [--url url]\n";
	print "                        [--usermin]\n";
	print "                        [--release number]\n";
	print "                        [--epoch number]\n";
	print "                        [--target-dir directory]\n";
	print "                        [--dir directory-in-package]\n";
	print "                        [--allow-overwrite]\n";
	print "                        [--force-theme]\n";
	print "                        [--sign]\n";
	print "                        [--key keyname]\n";
	print "                        [--exclude file]\n";
	print "                        [--mod-list full|core|minimal]\n";
	print RESET, "\n";
	exit(1);
	}
my $par;
chop($par = `/usr/bin/dirname $dir`);
$par = &untaint($par);
my $source_mod;
chop($source_mod = `/bin/basename $dir`);
$source_mod = &untaint($source_mod);
my $source_dir = "$par/$source_mod";
my (%minfo, %tinfo);
&read_file("$source_dir/module.info", \%minfo);
&read_file("$source_dir/theme.info", \%tinfo);
my $mod = $final_mod || $minfo{'default_dir'} || $tinfo{'default_dir'} || $source_mod;
if (!-d $basedir) {
	die "RPM directory $basedir does not exist";
	}
if ($mod eq "." || $mod eq "..") {
	die "directory must be an actual directory (module) name, not \"$mod\"";
	}
my $spec_dir = "$basedir/SPECS";
my $rpm_source_dir = "$basedir/SOURCES";
my $rpm_dir = "$basedir/RPMS/noarch";
my $source_rpm_dir = "$basedir/SRPMS";
if (!-d $spec_dir || !-d $rpm_source_dir || !-d $rpm_dir) {
	die "RPM directory $basedir is not valid";
	}

# Is this actually a module or theme directory?
-d $source_dir || die "$dir is not a directory";
my ($depends, $prefix, $prefix_auto, $desc, $prog, $iver,
    $istheme, $post_config);
if ($minfo{'desc'}) {
	$depends = join(" ", map { s/\/[0-9\.]+//; $_ }
				grep { !/^[0-9\.]+$/ }
				  split(/\s+/, $minfo{'depends'}));
	if ($minfo{'usermin'} && (!$minfo{'webmin'} || $force_usermin)) {
		$prefix = "usm-";
		$desc = "Usermin module $minfo{'desc'}";
		$prog = "usermin";
		}
	else {
		$prefix = "wbm-";
		$desc = "Webmin module $minfo{'desc'}";
		$prog = "webmin";
		}
	$iver = $minfo{'version'};
	$post_config = 1;
	}
elsif ($tinfo{'desc'}) {
	if ($tinfo{'usermin'} && (!$tinfo{'usermin'} || $force_usermin)) {
		$prefix = "ust-";
		$desc = "Usermin theme $tinfo{'desc'}";
		$prog = "usermin";
		}
	else {
		$prefix = "wbt-";
		$desc = "Webmin theme $tinfo{'desc'}";
		$prog = "webmin";
		}
	$iver = $tinfo{'version'};
	$istheme = 1;
	$post_config = 0;
	}
else {
	die "$source_dir does not appear to be a webmin module or theme";
	}
$prefix_auto = $prefix;
$prefix = "" if ($no_prefix);
$prefix = $set_prefix if ($set_prefix);
my $ucprog = ucfirst($prog);

# Copy the directory to a temp location for tarring
system("/bin/mkdir -p /tmp/makemodulerpm");
system("cd $par && /bin/cp -rpL $source_mod /tmp/makemodulerpm/$mod");
system("/usr/bin/find /tmp/makemodulerpm -name .git | xargs rm -rf");
system("/usr/bin/find /tmp/makemodulerpm -name .github | xargs rm -rf");
system("/usr/bin/find /tmp/makemodulerpm -name RELEASE | xargs rm -rf");
system("/usr/bin/find /tmp/makemodulerpm -name RELEASE.sh | xargs rm -rf");
system("/usr/bin/find /tmp/makemodulerpm -name t | xargs rm -rf");
if (-r "/tmp/makemodulerpm/$mod/EXCLUDE") {
	system("cd /tmp/makemodulerpm/$mod && cat EXCLUDE | xargs rm -rf");
	system("rm -f /tmp/makemodulerpm/$mod/EXCLUDE");
	}
foreach my $e (@exclude) {
	system("/usr/bin/find /tmp/makemodulerpm -name ".quotemeta($e)." | xargs rm -rf");
	}

# Set version in .info file to match command line, if given
if ($ver) {
	if ($minfo{'desc'}) {
		$minfo{'version'} = $ver;
		&write_file("/tmp/makemodulerpm/$mod/module.info", \%minfo);
		}
	elsif ($tinfo{'desc'}) {
		$tinfo{'version'} = $ver;
		&write_file("/tmp/makemodulerpm/$mod/theme.info", \%tinfo);
		}
	}
else {
	$ver ||= $iver;		# Use module.info version, or 1
	$ver ||= 1;
	}

# Tar up the directory
system("cd /tmp/makemodulerpm && tar czhf $rpm_source_dir/$mod.tar.gz $mod");
system("/bin/rm -rf /tmp/makemodulerpm");

# Build list of dependencies on other RPMs, for inclusion as an RPM
# Requires: header
my $rdeps = "";
if ($rpmdepends && defined($minfo{'depends'})) {
	my @rdeps;
	foreach my $d (split(/\s+/, $minfo{'depends'})) {
		my ($dwebmin, $dmod, $dver);
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
			my $mod_def_list;
			my @mod_def_list;
			my $curr_dir = $0;
			($curr_dir) = $curr_dir =~ /^(.+)\/[^\/]+$/;
			$curr_dir = "." if ($curr_dir !~ /^\//);
			my $mod_def_file = "$curr_dir/mod_${mod_list}_list.txt";
			next if (! -r $mod_def_file);
			open(my $fh, '<', $mod_def_file) ||
				die "Error opening \"$mod_def_file\" : $!\n";
			$mod_def_list = do { local $/; <$fh> };
			close($fh);
			@mod_def_list = split(/\s+/, $mod_def_list);
			next if (grep( /^$dmod$/, @mod_def_list ));
			}
		push(@rdeps, $dwebmin ? ("webmin", ">=", $dwebmin) :
			     $dver ? ($prefix.$dmod, ">=", $dver) :
				     ($prefix.$dmod));
		}
	$rdeps = join(" ", @rdeps);
	}

# Build list of recommended packages on other RPMs, for inclusion as an RPM
# Recommends: header (Webmin module with prefixes)
my $rrecom = "";
if ($rpmrecommends && defined($minfo{'recommends'})) {
	my @rrecom;
	foreach my $d (split(/\s+/, $minfo{'recommends'})) {
		push(@rrecom, $prefix.$d);
		}
	$rrecom = join(" ", @rrecom);
	}

# Build (append) list of required packages (not Webmin modules)
my @rrequires = ( );
if (!$no_requires && exists($minfo{'rpm_requires'})) {
	foreach my $rpmrequire (split(/\s+/, $minfo{'rpm_requires'})) {
		push(@rrequires, $rpmrequire);
		}
	$rdeps .= ($rdeps ? ' ' : '') . join(" ", @rrequires) if (@rrequires);
	}

# Build (append) list of recommended packages (not Webmin modules)
my @rrecommends = ( );
if (!$no_recommends && exists($minfo{'rpm_recommends'})) {
	foreach my $rpmrecommend (split(/\s+/, $minfo{'rpm_recommends'})) {
		push(@rrecommends, $rpmrecommend);
		}
	$rrecom .= ($rrecom ? ' ' : '') . join(" ", @rrecommends)
		if (@rrecommends);
	}

# Build (standalone) list of suggested packages (not Webmin modules)
my @rsuggests = ( );
if (!$no_suggests && exists($minfo{'rpm_suggests'})) {
	foreach my $rpmsuggest (split(/\s+/, $minfo{'rpm_suggests'})) {
		push(@rsuggests, $rpmsuggest);
		}
	}

# Build (standalone) list of conflicts (not Webmin modules)
my @rconflicts = ( );
if (!$no_conflicts && exists($minfo{'rpm_conflicts'})) {
	foreach my $rpmconflict (split(/\s+/, $minfo{'rpm_conflicts'})) {
		push(@rconflicts, $rpmconflict);
		}
	}

# Build (standalone) list of provides (not Webmin modules)
my @rprovides = ( );
if (!$no_provides && exists($minfo{'rpm_provides'})) {
	foreach my $rpmprovide (split(/\s+/, $minfo{'rpm_provides'})) {
		push(@rprovides, $rpmprovide);
		}
	}

# Build (standalone) list of obsoletes (not Webmin modules)
my @robsoletes = ( );
if (!$no_obsoletes && exists($minfo{'rpm_obsoletes'})) {
	foreach my $rpmobsolete (split(/\s+/, $minfo{'rpm_obsoletes'})) {
		push(@robsoletes, $rpmobsolete);
		}
	}

# Fix support for old module name prefixes
if ($obsolete_wbm) {
	push(@rprovides, "$prefix_auto$mod");
	push(@robsoletes, "$prefix_auto$mod");
	}

# Create the SPEC file
my $vendorheader = $vendor ? "Vendor: $vendor" : "";
my $urlheader = $url ? "URL: $url" : "";
my $epochheader = $epoch ? "Epoch: $epoch" : "";
$force_theme //= "";
$istheme //= "";
$rdeps //= "";
$depends //= "";
open(my $SPEC, ">", "$spec_dir/$prefix$mod.spec");
print $SPEC <<EOF;
%define __spec_install_post %{nil}

Summary: $desc
Name: $prefix$mod
Version: $ver
Release: $release
Requires: /bin/sh /usr/bin/perl $prog $rdeps
EOF
print $SPEC "Recommends: $rrecom\n" if ($rrecom);
print $SPEC "Suggests: " . join(" ", @rsuggests) . "\n" if (@rsuggests);
print $SPEC "Conflicts: " . join(" ", @rconflicts) . "\n" if (@rconflicts);
print $SPEC "Provides: " . join(" ", @rprovides) . "\n" if (@rprovides);
print $SPEC "Obsoletes: " . join(" ", @robsoletes) . "\n" if (@robsoletes);
print $SPEC <<EOF;
Autoreq: 0
Autoprov: 0
License: $licence
Group: System/Tools
Source: $mod.tar.gz
BuildRoot: /tmp/%{name}-%{version}
BuildArchitectures: noarch
$epochheader
$vendorheader
$urlheader
%description
$desc

%prep
%setup -n $mod

%build
(find . -name '*.cgi' ; find . -name '*.pl') | perl -ne 'chop; open(F,\$_); \@l=<F>; close(F); \$l[0] = "#\!/usr/bin/perl\$1\n" if (\$l[0] =~ /#\!\\S*perl\\S*(.*)/); open(F,">\$_"); print F \@l; close(F)'

%install
mkdir -p %{buildroot}/usr/libexec/$prog/$mod
cp -rp * %{buildroot}/usr/libexec/$prog/$mod
echo rpm >%{buildroot}/usr/libexec/$prog/$mod/install-type

%clean
[ "%{buildroot}" != "/" ] && rm -rf %{buildroot}

%files
/usr/libexec/$prog/$mod/

%pre
# Check if webmin/usermin is installed
if [ ! -r /etc/$prog/config -o ! -d /usr/libexec/$prog ]; then
	echo "$ucprog does not appear to be installed on your system."
	echo "This RPM cannot be installed unless the RPM version of $ucprog"
	echo "is installed first."
	exit 1
fi
if [ "$depends" != "" -a "$rpmdepends" != 1 ]; then
	# Check if depended webmin/usermin modules are installed
	for d in $depends; do
		if [ ! -r /usr/libexec/$prog/\$d/module.info ]; then
			echo "This $ucprog module depends on the module \$d, which is"
			echo "not installed on your system."
			exit 1
		fi
	done
fi
# Check if this module is already installed
if [ -d /usr/libexec/$prog/$mod -a "\$1" = "1" -a "$allow_overwrite" != "1" ]; then
	echo "This $ucprog module is already installed on your system."
	exit 1
fi

%post
if [ "$post_config" = "1" ]; then
	# Copy config file to /etc/webmin or /etc/usermin
	os_type=`grep "^os_type=" /etc/$prog/config | sed -e 's/os_type=//g'`
	os_version=`grep "^os_version=" /etc/$prog/config | sed -e 's/os_version=//g'`
	real_os_type=`grep "^real_os_type=" /etc/$prog/config | sed -e 's/real_os_type=//g'`
	real_os_version=`grep "^real_os_version=" /etc/$prog/config | sed -e 's/real_os_version=//g'`
	/usr/bin/perl /usr/libexec/$prog/copyconfig.pl "\$os_type/\$real_os_type" "\$os_version/\$real_os_version" /usr/libexec/$prog /etc/$prog $mod

	# Update the ACL for the root user, or the first user in the ACL
	grep "^root:" /etc/$prog/webmin.acl >/dev/null
	if [ "\$?" = "0" ]; then
		user=root
	else
		user=`head -1 /etc/$prog/webmin.acl | cut -f 1 -d :`
	fi
	mods=`grep \$user: /etc/$prog/webmin.acl | cut -f 2 -d :`
	echo \$mods | grep " $mod" >/dev/null
	if [ "\$?" != "0" ]; then
		grep -v ^\$user: /etc/$prog/webmin.acl > /tmp/webmin.acl.tmp
		echo \$user: \$mods $mod > /etc/$prog/webmin.acl
		cat /tmp/webmin.acl.tmp >> /etc/$prog/webmin.acl
		rm -f /tmp/webmin.acl.tmp
	fi
fi
if [ "$force_theme" != "" -a "$istheme" = "1" ]; then
	# Activate this theme
	grep -v "^preroot=" /etc/$prog/miniserv.conf >/etc/$prog/miniserv.conf.tmp
	(cat /etc/$prog/miniserv.conf.tmp ; echo preroot=$mod) > /etc/$prog/miniserv.conf
	rm -f /etc/$prog/miniserv.conf.tmp
	grep -v "^theme=" /etc/$prog/config >/etc/$prog/config.tmp
	(cat /etc/$prog/config.tmp ; echo theme=$mod) > /etc/$prog/config
	rm -f /etc/$prog/config.tmp
	(/etc/$prog/stop && /etc/$prog/start) >/dev/null 2>&1
fi
rm -f /etc/$prog/module.infos.cache
rm -f /var/$prog/module.infos.cache

# Run post-install function
if [ "$prog" = "webmin" ]; then
	cd /usr/libexec/$prog
	WEBMIN_CONFIG=/etc/$prog WEBMIN_VAR=/var/$prog /usr/libexec/$prog/run-postinstalls.pl $mod
fi

# Run post-install shell script
if [ -r "/usr/libexec/$prog/$mod/postinstall.sh" ]; then
	cd /usr/libexec/$prog
	WEBMIN_CONFIG=/etc/$prog WEBMIN_VAR=/var/$prog /usr/libexec/$prog/$mod/postinstall.sh
fi

%preun
# De-activate this theme, if in use and if we are not upgrading
if [ "$istheme" = "1" -a "\$1" = "0" ]; then
	grep "^preroot=$mod" /etc/$prog/miniserv.conf >/dev/null
	if [ "\$?" = "0" ]; then
		grep -v "^preroot=$mod" /etc/$prog/miniserv.conf >/etc/$prog/miniserv.conf.tmp
		(cat /etc/$prog/miniserv.conf.tmp) > /etc/$prog/miniserv.conf
		rm -f /etc/$prog/miniserv.conf.tmp
		grep -v "^theme=$mod" /etc/$prog/config >/etc/$prog/config.tmp
		(cat /etc/$prog/config.tmp) > /etc/$prog/config
		rm -f /etc/$prog/config.tmp
		(/etc/$prog/stop && /etc/$prog/start) >/dev/null 2>&1
	fi
fi
# Run the pre-uninstall script, if we are not upgrading
if [ "$prog" = "webmin" -a "\$1" = "0" -a -r "/usr/libexec/$prog/$mod/uninstall.pl" ]; then
	cd /usr/libexec/$prog
	WEBMIN_CONFIG=/etc/$prog WEBMIN_VAR=/var/$prog /usr/libexec/$prog/run-uninstalls.pl $mod
fi
/bin/true

%postun
EOF
close($SPEC);

# Put the tar in /tmp too if tar package is requested
my $tar_release_file;
if ($copy_tar) {
	my $tar_release = $release;
	$tar_release =~ s/^[0-9]+//;
	$tar_release_file = "$prefix$mod-$ver$tar_release.tar.gz";
	system("cp $rpm_source_dir/$mod.tar.gz /tmp/$tar_release_file");
	}

# Build the actual RPM
my $cmd = -x "/usr/bin/rpmbuild" ? "/usr/bin/rpmbuild" : "/bin/rpm";
system("$cmd -ba $spec_dir/$prefix$mod.spec") && exit;
unlink("$rpm_source_dir/$mod.tar.gz");

# Sign if requested
if ($sign) {
	my $keyflag = $keyname ? "-D '_gpg_name $keyname'" : "";
	system("echo | rpm --resign $keyflag $rpm_dir/$prefix$mod-$ver-$release.noarch.rpm $source_rpm_dir/$prefix$mod-$ver-$release.src.rpm");
	}

if ($target_dir =~ /:/) {
	# scp to dest
	system("scp $rpm_dir/$prefix$mod-$ver-$release.noarch.rpm $target_dir/$prefix$mod-$ver-$release.noarch.rpm");
	# scp the tar too if requested
	if ($copy_tar) {
		system("scp /tmp/$tar_release_file $target_dir/$tar_release_file");
		unlink("/tmp/$tar_release_file");
		}
	}
elsif ($rpm_dir ne $target_dir) {
	# Just copy
	system("/bin/cp $rpm_dir/$prefix$mod-$ver-$release.noarch.rpm $target_dir/$prefix$mod-$ver-$release.noarch.rpm");
	# Copy the tar too if requested
	if ($copy_tar) {
		system("/bin/cp /tmp/$tar_release_file $target_dir/$tar_release_file");
		unlink("/tmp/$tar_release_file");
		}
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
        }
close(ARFILE);
return 1;
}

# write_file(file, array)
# Write out the contents of an associative array as name=value lines
sub write_file
{
my (%old, @order);
&read_file($_[0], \%old, \@order);
open(ARFILE, ">$_[0]");
foreach my $k (@order) {
        print ARFILE $k,"=",$_[1]->{$k},"\n" if (exists($_[1]->{$k}));
	}
foreach my $k (keys %{$_[1]}) {
        print ARFILE $k,"=",$_[1]->{$k},"\n" if (!exists($old{$k}));
        }
close(ARFILE);
}

sub untaint
{
$_[0] =~ /^(.*)$/;
return $1;
}
