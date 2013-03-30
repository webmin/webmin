#!/usr/local/bin/perl
# Build an RPM package of Webmin

if (-r "/usr/src/OpenLinux") {
	$base_dir = "/usr/src/OpenLinux";
	}
else {
	$base_dir = "/usr/src/redhat";
	}
$spec_dir = "$base_dir/SPECS";
$source_dir = "$base_dir/SOURCES";
$rpms_dir = "$base_dir/RPMS/noarch";
$srpms_dir = "$base_dir/SRPMS";

$< && die "makerpm.pl must be run as root";

if ($ARGV[0] eq "--nosign" || $ARGV[0] eq "-nosign") {
	$nosign = 1;
	shift(@ARGV);
	}
$ver = $ARGV[0] || die "usage: makerpm.pl <version> [release]";
$rel = $ARGV[1] || "1";

$oscheck = <<EOF;
if (-r "/etc/.issue") {
	\$etc_issue = `cat /etc/.issue`;
	}
elsif (-r "/etc/issue") {
	\$etc_issue = `cat /etc/issue`;
	}
\$uname = `uname -a`;
EOF
open(OS, "os_list.txt");
while(<OS>) {
	chop;
	if (/^([^\t]+)\t+([^\t]+)\t+([^\t]+)\t+([^\t]+)\t*(.*)$/ && $5) {
		$if = $count++ == 0 ? "if" : "elsif";
		$oscheck .= "$if ($5) {\n".
			    "	print \"oscheck='$1'\\n\";\n".
			    "	}\n";
		}
	}
close(OS);
$oscheck =~ s/\\/\\\\/g;
$oscheck =~ s/`/\\`/g;
$oscheck =~ s/\$/\\\$/g;

open(TEMP, "maketemp.pl");
while(<TEMP>) {
	$maketemp .= $_;
	}
close(TEMP);
$maketemp =~ s/\\/\\\\/g;
$maketemp =~ s/`/\\`/g;
$maketemp =~ s/\$/\\\$/g;

system("cp tarballs/webmin-$ver.tar.gz $source_dir");
open(SPEC, ">$spec_dir/webmin-$ver.spec");
print SPEC <<EOF;
#%define BuildRoot /tmp/%{name}-%{version}
%define __spec_install_post %{nil}

Summary: A web-based administration interface for Unix systems.
Name: webmin
Version: $ver
Release: $rel
Provides: %{name}-%{version}
PreReq: /bin/sh /usr/bin/perl /bin/rm
Requires: /bin/sh /usr/bin/perl /bin/rm
AutoReq: 0
License: Freeware
Group: System/Tools
Source: http://www.webmin.com/download/%{name}-%{version}.tar.gz
Vendor: Jamie Cameron
BuildRoot: /tmp/%{name}-%{version}
BuildArchitectures: noarch
%description
A web-based administration interface for Unix systems. Using Webmin you can
configure DNS, Samba, NFS, local/remote filesystems and more using your
web browser.

After installation, enter the URL http://localhost:10000/ into your
browser and login as root with your root password.

%prep
%setup -q

%build
(find . -name '*.cgi' ; find . -name '*.pl') | perl perlpath.pl /usr/bin/perl -
rm -f mount/freebsd-mounts*
rm -f mount/openbsd-mounts*
rm -f mount/macos-mounts*
rm -f webmin-gentoo-init
rm -rf format bsdexports hpuxexports sgiexports zones rbac bsdfdisk
rm -rf acl/Authen-SolarisRBAC-0.1*
chmod -R og-w .

%install
mkdir -p %{buildroot}/usr/libexec/webmin
mkdir -p %{buildroot}/etc/sysconfig/daemons
mkdir -p %{buildroot}/etc/rc.d/{rc0.d,rc1.d,rc2.d,rc3.d,rc5.d,rc6.d}
mkdir -p %{buildroot}/etc/init.d
mkdir -p %{buildroot}/etc/pam.d
cp -rp * %{buildroot}/usr/libexec/webmin
cp webmin-daemon %{buildroot}/etc/sysconfig/daemons/webmin
cp webmin-init %{buildroot}/etc/init.d/webmin
cp webmin-pam %{buildroot}/etc/pam.d/webmin
ln -s /etc/init.d/webmin %{buildroot}/etc/rc.d/rc2.d/S99webmin
ln -s /etc/init.d/webmin %{buildroot}/etc/rc.d/rc3.d/S99webmin
ln -s /etc/init.d/webmin %{buildroot}/etc/rc.d/rc5.d/S99webmin
ln -s /etc/init.d/webmin %{buildroot}/etc/rc.d/rc0.d/K10webmin
ln -s /etc/init.d/webmin %{buildroot}/etc/rc.d/rc1.d/K10webmin
ln -s /etc/init.d/webmin %{buildroot}/etc/rc.d/rc6.d/K10webmin
echo rpm >%{buildroot}/usr/libexec/webmin/install-type

%clean
#%{rmDESTDIR}
[ "%{buildroot}" != "/" ] && rm -rf %{buildroot}

%files
%defattr(-,root,root)
/usr/libexec/webmin
%config /etc/sysconfig/daemons/webmin
/etc/init.d/webmin
/etc/rc.d/rc2.d/S99webmin
/etc/rc.d/rc3.d/S99webmin
/etc/rc.d/rc5.d/S99webmin
/etc/rc.d/rc0.d/K10webmin
/etc/rc.d/rc1.d/K10webmin
/etc/rc.d/rc6.d/K10webmin
%config /etc/pam.d/webmin

%pre
perl <<EOD;
$maketemp
EOD
if [ "\$?" != "0" ]; then
	echo "Failed to create or check temp files directory /tmp/.webmin"
	exit 1
fi
if [ "\$tempdir" = "" ]; then
	tempdir=/tmp/.webmin
fi
perl >$tempdir/\$\$.check <<EOD;
$oscheck
EOD
. $tempdir/\$\$.check
rm -f $tempdir/\$\$.check
if [ ! -r /etc/webmin/config ]; then
	if [ "\$oscheck" = "" ]; then
		echo Unable to identify operating system
		exit 2
	fi
	echo Operating system is \$oscheck
	if [ "\$WEBMIN_PORT\" != \"\" ]; then
		port=\$WEBMIN_PORT
	else
		port=10000
	fi
	perl -e 'use Socket; socket(FOO, PF_INET, SOCK_STREAM, getprotobyname("tcp")); setsockopt(FOO, SOL_SOCKET, SO_REUSEADDR, pack("l", 1)); bind(FOO, pack_sockaddr_in(\$ARGV[0], INADDR_ANY)) || exit(1); exit(0);' \$port
	if [ "\$?" != "0" ]; then
		echo Port \$port is already in use
		exit 2
	fi
fi
# Save /etc/webmin in case the upgrade trashes it
if [ "\$1" != 1 ]; then
	rm -rf /etc/.webmin-backup
	cp -r /etc/webmin /etc/.webmin-backup
fi
# Put back old /etc/webmin saved when an RPM was removed
if [ "\$1" = 1 -a ! -d /etc/webmin -a -d /etc/webmin.rpmsave ]; then
	mv /etc/webmin.rpmsave /etc/webmin
fi
/bin/true

%post
inetd=`grep "^inetd=" /etc/webmin/miniserv.conf 2>/dev/null | sed -e 's/inetd=//g'`
startafter=0
if [ "\$1" != 1 ]; then
	# Upgrading the RPM, so stop the old webmin properly
	if [ "\$inetd" != "1" ]; then
		kill -0 `cat /var/webmin/miniserv.pid 2>/dev/null` 2>/dev/null
		if [ "\$?" = 0 ]; then
		  startafter=1
		fi
		/etc/init.d/webmin stop >/dev/null 2>&1 </dev/null
	fi
else
  startafter=1
fi
cd /usr/libexec/webmin
config_dir=/etc/webmin
var_dir=/var/webmin
perl=/usr/bin/perl
autoos=3
if [ "\$WEBMIN_PORT\" != \"\" ]; then
	port=\$WEBMIN_PORT
else
	port=10000
fi
login=root
if [ -r /etc/shadow ]; then
	#crypt=`grep "^root:" /etc/shadow | cut -f 2 -d :`
	crypt=x
else
	crypt=`grep "^root:" /etc/passwd | cut -f 2 -d :`
fi
host=`hostname`
ssl=1
atboot=1
nochown=1
autothird=1
noperlpath=1
nouninstall=1
nostart=1
if [ "\$tempdir" = "" ]; then
	tempdir=/tmp/.webmin
fi
export config_dir var_dir perl autoos port login crypt host ssl nochown autothird noperlpath nouninstall nostart allow atboot
./setup.sh >\$tempdir/webmin-setup.out 2>&1
chmod 600 \$tempdir/webmin-setup.out
rm -f /var/lock/subsys/webmin
if [ "\$inetd" != "1" -a "\$startafter" = "1" ]; then
	/etc/init.d/webmin start >/dev/null 2>&1 </dev/null
fi
cat >/etc/webmin/uninstall.sh <<EOFF
#!/bin/sh
printf "Are you sure you want to uninstall Webmin? (y/n) : "
read answer
printf "\\n"
if [ "\\\$answer" = "y" ]; then
	echo "Removing webmin RPM .."
	rpm -e --nodeps webmin
	echo "Done!"
fi
EOFF
chmod +x /etc/webmin/uninstall.sh
port=`grep "^port=" /etc/webmin/miniserv.conf | sed -e 's/port=//g'`
perl -e 'use Net::SSLeay' >/dev/null 2>/dev/null
sslmode=0
if [ "\$?" = "0" ]; then
	grep ssl=1 /etc/webmin/miniserv.conf >/dev/null 2>/dev/null
	if [ "\$?" = "0" ]; then
		sslmode=1
	fi
fi
musthost=`grep musthost= /etc/webmin/miniserv.conf | sed -e 's/musthost=//'`
if [ "$musthost" != "" ]; then
	host=$musthost
fi
if [ "\$sslmode" = "1" ]; then
	echo "Webmin install complete. You can now login to https://\$host:\$port/"
else
	echo "Webmin install complete. You can now login to http://\$host:\$port/"
fi
echo "as root with your root password."
/bin/true

%preun
if [ "\$1" = 0 ]; then
	grep root=/usr/libexec/webmin /etc/webmin/miniserv.conf >/dev/null 2>&1
	if [ "\$?" = 0 ]; then
		# RPM is being removed, and no new version of webmin
		# has taken it's place. Run uninstalls and stop the server
		echo "Running uninstall scripts .."
		(cd /usr/libexec/webmin ; WEBMIN_CONFIG=/etc/webmin WEBMIN_VAR=/var/webmin LANG= /usr/libexec/webmin/run-uninstalls.pl)
		/etc/init.d/webmin stop >/dev/null 2>&1 </dev/null
		/etc/webmin/stop >/dev/null 2>&1 </dev/null
	fi
fi
/bin/true

%postun
if [ "\$1" = 0 ]; then
	grep root=/usr/libexec/webmin /etc/webmin/miniserv.conf >/dev/null 2>&1
	if [ "\$?" = 0 ]; then
		# RPM is being removed, and no new version of webmin
		# has taken it's place. Rename away the /etc/webmin directory
		rm -rf /etc/webmin.rpmsave
		mv /etc/webmin /etc/webmin.rpmsave
		rm -rf /var/webmin
	fi
fi
/bin/true

%triggerpostun -- webmin
if [ ! -d /var/webmin -a "\$1" = 2 ]; then
	echo Re-creating /var/webmin directory
	mkdir /var/webmin
fi
if [ ! -r /etc/webmin/miniserv.conf -a -d /etc/.webmin-backup -a "\$1" = 2 ]; then
	echo Recovering /etc/webmin directory
	rm -rf /etc/.webmin-broken
	mv /etc/webmin /etc/.webmin-broken
	mv /etc/.webmin-backup /etc/webmin
	/etc/init.d/webmin stop >/dev/null 2>&1 </dev/null
	/etc/init.d/webmin start >/dev/null 2>&1 </dev/null
else
	rm -rf /etc/.webmin-backup
fi
/bin/true

EOF
close(SPEC);

$cmd = -x "/usr/bin/rpmbuild" ? "rpmbuild" : "rpm";
system("$cmd -ba --target=noarch $spec_dir/webmin-$ver.spec") && exit;
if (-d "rpm") {
	system("mv $rpms_dir/webmin-$ver-$rel.noarch.rpm rpm/webmin-$ver-$rel.noarch.rpm");
	print "Moved to rpm/webmin-$ver-$rel.noarch.rpm\n";
	system("mv $srpms_dir/webmin-$ver-$rel.src.rpm rpm/webmin-$ver-$rel.src.rpm");
	print "Moved to rpm/webmin-$ver-$rel.src.rpm\n";
	system("chown jcameron: rpm/webmin-$ver-$rel.noarch.rpm rpm/webmin-$ver-$rel.src.rpm");
	if (!$nosign) {
		system("rpm --resign rpm/webmin-$ver-$rel.noarch.rpm rpm/webmin-$ver-$rel.src.rpm");
		}
	}

if (!$webmail && -d "/usr/local/webadmin/rpm/yum") {
	# Add to our repository
	system("cp rpm/webmin-$ver-$rel.noarch.rpm /usr/local/webadmin/rpm/yum");
	}


