#!/usr/bin/perl
# makemodulerpm.pl
# Create an RPM for a webmin or usermin module or theme

$target_dir = "/tmp";	# where to copy the RPM to

if (-d "/usr/src/OpenLinux") {
	$basedir = "/usr/src/OpenLinux";
	}
else {
	$basedir = "/usr/src/redhat";
	}
$licence = "Freeware";
$release = 1;
$< = $>;		# If running setuid
$ENV{'PATH'} = "/bin:/usr/bin:/usr/local/bin:/sbin:/usr/sbin";
$allow_overwrite = 0;

# Parse command-line args
while(@ARGV) {
	local $a = &untaint(shift(@ARGV));
	if ($a eq "--force-theme") {
		$force_theme = 1;
		}
	elsif ($a eq "--rpm-dir") {
		$basedir = &untaint(shift(@ARGV));
		}
	elsif ($a eq "--licence" || $a eq "--license") {
		$licence = &untaint(shift(@ARGV));
		}
	elsif ($a eq "--rpm-depends") {
		$rpmdepends = 1;
		}
	elsif ($a eq "--no-prefix") {
		$no_prefix = 1;
		}
	elsif ($a eq "--vendor") {
		$vendor = &untaint(shift(@ARGV));
		}
	elsif ($a eq "--provides") {
		$provides = &untaint(shift(@ARGV));
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
	elsif ($a eq "--requires") {
		push(@extrareqs, shift(@ARGV));
		}
	elsif ($a eq "--allow-overwrite") {
		$allow_overwrite = 1;
		}
	elsif ($a eq "--sign") {
		$sign = 1;
		}
	elsif ($a eq "--epoch") {
		$epoch = shift(@ARGV);
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
	print STDERR "usage: makemodulerpm.pl [--force-theme]\n";
	print STDERR "                        [--rpm-dir directory]\n";
	print STDERR "                        [--rpm-depends]\n";
	print STDERR "                        [--no-prefix]\n";
	print STDERR "                        [--vendor name]\n";
	print STDERR "                        [--licence name]\n";
	print STDERR "                        [--url url]\n";
	print STDERR "                        [--provides provides]\n";
	print STDERR "                        [--usermin]\n";
	print STDERR "                        [--release number]\n";
	print STDERR "                        [--epoch number]\n";
	print STDERR "                        [--target-dir directory]\n";
	print STDERR "                        [--dir directory-in-package]\n";
	print STDERR "                        [--allow-overwrite]\n";
	print STDERR "                        <module> [version]\n";
	exit(1);
	}
chop($par = `/usr/bin/dirname $dir`);
$par = &untaint($par);
chop($source_mod = `/bin/basename $dir`);
$source_mod = &untaint($source_mod);
$source_dir = "$par/$source_mod";
$mod = $final_mod || $source_mod;
if (!-d $basedir) {
	die "RPM directory $basedir does not exist";
	}
if ($mod eq "." || $mod eq "..") {
	die "directory must be an actual directory (module) name, not \"$mod\"";
	}
$spec_dir = "$basedir/SPECS";
$rpm_source_dir = "$basedir/SOURCES";
$rpm_dir = "$basedir/RPMS/noarch";
$source_rpm_dir = "$basedir/SRPMS";
if (!-d $spec_dir || !-d $rpm_source_dir || !-d $rpm_dir) {
	die "RPM directory $basedir is not valid";
	}

# Is this actually a module or theme directory?
-d $source_dir || die "$dir is not a directory";
if (&read_file("$source_dir/module.info", \%minfo) && $minfo{'desc'}) {
	$depends = join(" ", map { s/\/[0-9\.]+//; $_ }
				grep { !/^[0-9\.]+$/ }
				  split(/\s+/, $minfo{'depends'}));
	if ($minfo{'usermin'} && (!$minfo{'webmin'} || $force_usermin)) {
		$prefix = "usm-";
		$desc = "Usermin module for '$minfo{'desc'}'";
		$prog = "usermin";
		}
	else {
		$prefix = "wbm-";
		$desc = "Webmin module for '$minfo{'desc'}'";
		$prog = "webmin";
		}
	$iver = $minfo{'version'};
	$post_config = 1;
	}
elsif (&read_file("$source_dir/theme.info", \%tinfo) && $tinfo{'desc'}) {
	if ($tinfo{'usermin'} && (!$tinfo{'usermin'} || $force_usermin)) {
		$prefix = "ust-";
		$desc = "Usermin theme '$tinfo{'desc'}'";
		$prog = "usermin";
		}
	else {
		$prefix = "wbt-";
		$desc = "Webmin theme '$tinfo{'desc'}'";
		$prog = "webmin";
		}
	$iver = $tinfo{'version'};
	$istheme = 1;
	$post_config = 0;
	}
else {
	die "$source_dir does not appear to be a webmin module or theme";
	}
$prefix = "" if ($no_prefix);
$ucprog = ucfirst($prog);
$ver ||= $iver;		# Use module.info version, or 1
$ver ||= 1;

# Copy the directory to a temp location for tarring
system("/bin/mkdir -p /tmp/makemodulerpm");
system("cd $par && /bin/cp -rpL $source_mod /tmp/makemodulerpm/$mod");
system("/usr/bin/find /tmp/makemodulerpm -name .svn | xargs rm -rf");
system("/usr/bin/find /tmp/makemodulerpm -name .xvpics | xargs rm -rf");
system("/usr/bin/find /tmp/makemodulerpm -name '*.bak' | xargs rm -rf");
system("/usr/bin/find /tmp/makemodulerpm -name '*~' | xargs rm -rf");
system("/usr/bin/find /tmp/makemodulerpm -name '*.rej' | xargs rm -rf");
system("/usr/bin/find /tmp/makemodulerpm -name '.*.swp' | xargs rm -rf");
system("/usr/bin/find /tmp/makemodulerpm -name core | xargs rm -rf");
system("/bin/chown -R root:bin /tmp/makemodulerpm/$mod");

# Tar up the directory
system("cd /tmp/makemodulerpm && tar czhf $rpm_source_dir/$mod.tar.gz $mod");
system("/bin/rm -rf /tmp/makemodulerpm");

# Build list of dependencies on other RPMs, for inclusion as an RPM
# Requires: header
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
		push(@rdeps, $dwebmin ? ("webmin", ">=", $dwebmin) :
			     $dver ? ($prefix.$dmod, ">=", $dver) :
				     ($prefix.$dmod));
		}
	}
$rdeps = join(" ", @rdeps, @extrareqs);

# Create the SPEC file
$providesheader = $provides ? "Provides: $provides" : undef;
$vendorheader = $vendor ? "Vendor: $vendor" : undef;
$urlheader = $url ? "URL: $url" : undef;
$epochheader = $epoch ? "Epoch: $epoch" : undef;
open(SPEC, ">$spec_dir/$prefix$mod.spec");
print SPEC <<EOF;
%define __spec_install_post %{nil}

Summary: $desc
Name: $prefix$mod
Version: $ver
Release: $release
PreReq: /bin/sh /usr/bin/perl /usr/libexec/$prog
Requires: /bin/sh /usr/bin/perl /usr/libexec/$prog $rdeps
AutoReq: 0
License: $licence
Group: System/Tools
Source: $mod.tar.gz
Vendor: Jamie Cameron
BuildRoot: /tmp/%{name}-%{version}
BuildArchitectures: noarch
$epochheader
$providesheader
$vendorheader
$urlheader
%description
$desc in RPM format

%prep
%setup -n $mod

%build
(find . -name '*.cgi' ; find . -name '*.pl') | perl -ne 'chop; open(F,\$_); \@l=<F>; close(F); \$l[0] = "#\!/usr/bin/perl\$1\n" if (\$l[0] =~ /#\!\\S*perl\\S*(.*)/); open(F,">\$_"); print F \@l; close(F)'
(find . -name '*.cgi' ; find . -name '*.pl') | xargs chmod +x

%install
mkdir -p %{buildroot}/usr/libexec/$prog/$mod
cp -rp * %{buildroot}/usr/libexec/$prog/$mod
echo rpm >%{buildroot}/usr/libexec/$prog/$mod/install-type

%clean
[ "%{buildroot}" != "/" ] && rm -rf %{buildroot}

%files
/usr/libexec/$prog/$mod

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
	/usr/bin/perl /usr/libexec/$prog/copyconfig.pl \$os_type \$os_version /usr/libexec/$prog /etc/$prog $mod

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
close(SPEC);

# Build the actual RPM
$cmd = -x "/usr/bin/rpmbuild" ? "/usr/bin/rpmbuild" : "/bin/rpm";
system("$cmd -ba $spec_dir/$prefix$mod.spec") && exit;
unlink("$rpm_source_dir/$mod.tar.gz");

# Sign if requested
if ($sign) {
	system("rpm --resign $rpm_dir/$prefix$mod-$ver-$release.noarch.rpm $source_rpm_dir/$prefix$mod-$ver-$release.src.rpm");
	}

if ($target_dir =~ /:/) {
	# scp to dest
	system("scp $rpm_dir/$prefix$mod-$ver-$release.noarch.rpm $target_dir/$prefix$mod-$ver-$release.noarch.rpm");
	}
else {
	# Just copy
	system("/bin/cp $rpm_dir/$prefix$mod-$ver-$release.noarch.rpm $target_dir/$prefix$mod-$ver-$release.noarch.rpm");
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
 
sub untaint
{
$_[0] =~ /^(.*)$/;
return $1;
}

