#!/usr/local/bin/perl
# Build an RPM package of Webmin

if (-d "$ENV{'HOME'}/redhat") {
	$base_dir = "$ENV{'HOME'}/redhat";
	}
elsif (-d "$ENV{'HOME'}/rpmbuild") {
	$base_dir = "$ENV{'HOME'}/rpmbuild";
	}
else {
	$base_dir = "/usr/src/redhat";
	$< && die "makerpm.pl must be run as root";
	}
$rpm_maintainer = $ENV{'RPM_MAINTAINER'} || "Jamie Cameron";
$spec_dir = "$base_dir/SPECS";
$source_dir = "$base_dir/SOURCES";
$rpms_dir = "$base_dir/RPMS/noarch";
$srpms_dir = "$base_dir/SRPMS";

if ($ARGV[0] eq "--nosign" || $ARGV[0] eq "-nosign") {
	$nosign = 1;
	shift(@ARGV);
	}
$ver = $ARGV[0] || die "usage: makerpm.pl [--nosign] <version> [release]";
$rel = $ARGV[1] || "1";

$oscheck = <<EOF;
if (-r "/etc/.issue") {
	\$etc_issue = `cat /etc/.issue`;
	}
elsif (-r "/etc/issue") {
	\$etc_issue = `cat /etc/issue`;
	}
if (-r "/etc/os-release") {
	\$os_release = `cat /etc/os-release`;
	}
\$uname = `uname -a`;
EOF
open(OS, "os_list.txt");
while(<OS>) {
	chop;
	next if (/^Generic\s+Linux/i);
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

if ($rel && $rel > 1) {
	$makerel = "echo $rel >%{buildroot}/usr/libexec/webmin/release";
	}
else {
	$makerel = "rm -f %{buildroot}/usr/libexec/webmin/release";
	}

if ($rel > 1 && -r "tarballs/webmin-$ver-$rel.tar.gz") {
	$tarfile = "webmin-$ver-$rel.tar.gz";
	}
else {
	$tarfile = "webmin-$ver.tar.gz";
	}

system("cp tarballs/$tarfile $source_dir");
open(SPEC, ">$spec_dir/webmin-$ver.spec");
print SPEC <<EOF;
%global __perl_provides %{nil}
%define __spec_install_post %{nil}

Summary: A web-based administration interface for Unix systems.
Name: webmin
Version: $ver
Release: $rel
Provides: %{name}-%{version} perl(WebminCore)
Requires(pre): /usr/bin/perl
Requires: /bin/sh /usr/bin/perl perl(lib) perl(open) perl(Net::SSLeay) perl(Time::Local) perl(Data::Dumper) perl(File::Path) perl(File::Basename) perl(Digest::SHA) perl(Digest::MD5) openssl unzip tar gzip
Recommends: perl(DateTime) perl(DateTime::TimeZone) perl(DateTime::Locale) perl(Time::Piece) perl(Encode::Detect) perl(Time::HiRes) perl(Socket6) perl(Sys::Syslog) html2text shared-mime-info lsof perl-File-Basename perl-File-Path perl-JSON-XS qrencode perl(DBI) perl(DBD::mysql) perl(DBD::MariaDB)
AutoReq: 0
License: BSD-3-Clause
Group: System/Tools
Source: http://www.webmin.com/download/$tarfile
Vendor: $rpm_maintainer
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
mkdir -p %{buildroot}/etc/pam.d
mkdir -p %{buildroot}/usr/bin
cp -rp * %{buildroot}/usr/libexec/webmin
cp webmin-pam %{buildroot}/etc/pam.d/webmin
ln -s /usr/libexec/webmin/bin/webmin %{buildroot}/usr/bin
rm %{buildroot}/usr/libexec/webmin/blue-theme
cp -rp %{buildroot}/usr/libexec/webmin/gray-theme %{buildroot}/usr/libexec/webmin/blue-theme
echo rpm >%{buildroot}/usr/libexec/webmin/install-type
$makerel

%clean
#%{rmDESTDIR}
[ "%{buildroot}" != "/" ] && rm -rf %{buildroot}

%files
%defattr(-,root,root)
/usr/libexec/webmin
/usr/bin/webmin
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
	mkdir /etc/.webmin-backup
	(cd /etc/webmin && tar --exclude history --exclude bandwidth --exclude usage -c -f - .) | (cd /etc/.webmin-backup && tar -x -f -)
fi
# Put back old /etc/webmin saved when an RPM was removed
if [ "\$1" = 1 -a ! -d /etc/webmin -a -d /etc/webmin.rpmsave ]; then
	mv /etc/webmin.rpmsave /etc/webmin
fi
/bin/true

%post
inetd=`grep "^inetd=" /etc/webmin/miniserv.conf 2>/dev/null | sed -e 's/inetd=//g'`
killmodenone=0
if [ "\$1" != 1 ]; then
	# Upgrading the RPM, so stop the old Webmin properly
	if [ "\$inetd" != "1" ]; then
		if [ -f /etc/webmin/.pre-install ]; then
			/etc/webmin/.pre-install >/dev/null 2>&1 </dev/null
		else
			killmodenone=1
		fi
	fi
fi
cd /usr/libexec/webmin
config_dir=/etc/webmin
var_dir=/var/webmin
perl=/usr/bin/perl
autoos=1
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
makeboot=1
nochown=1
autothird=1
noperlpath=1
nouninstall=1
nostart=1
nostop=1
nodepsmsg=1
if [ "\$tempdir" = "" ]; then
	tempdir=/tmp/.webmin
fi
export config_dir var_dir perl autoos port login crypt host ssl nochown autothird noperlpath nouninstall nostart allow atboot makeboot nostop nodepsmsg
./setup.sh >\$tempdir/webmin-setup.out 2>&1
grep sudo= /etc/webmin/miniserv.conf >/dev/null 2>&1
if [ "\$?" = 1 ]; then
	# Allow sudo-based logins
	echo sudo=1 >>/etc/webmin/miniserv.conf
fi
chmod 600 \$tempdir/webmin-setup.out
rm -f /var/lock/subsys/webmin
cd /usr/libexec/webmin
if [ "\$inetd" != "1" ]; then
	if [ "\$1" == 1 ]; then
		/etc/webmin/start >/dev/null 2>&1 </dev/null
		if [ "\$?" != "0" ]; then
			echo "error: Webmin server cannot be started. It is advised to start it manually by\n       running \\"/etc/webmin/restart-by-force-kill\\" command"
		fi
	else
		if [ "\$killmodenone" != "1" ]; then
			/etc/webmin/.post-install >/dev/null 2>&1 </dev/null
		else
			/etc/webmin/.reload-init >/dev/null 2>&1 </dev/null
			if [ "\$?" != "0" ]; then
				echo "warning: Webmin server cannot be restarted. It is advised to restart it manually by\n         running \\"/etc/webmin/restart-by-force-kill\\" when upgrade process is finished"
			fi
			if [ -f /etc/webmin/.reload-init-systemd ]; then
				/etc/webmin/.reload-init-systemd >/dev/null 2>&1 </dev/null
				rm -f /etc/webmin/.reload-init-systemd
			fi
		fi
	fi
fi

cat >/etc/webmin/uninstall.sh <<EOFF
#!/bin/sh
printf "Are you sure you want to uninstall Webmin? (y/n) : "
read answer
printf "\\n"
if [ "\\\$answer" = "y" ]; then
	echo "Removing Webmin RPM package.."
	rpm -e --nodeps webmin
	echo ".. done"
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
if [ "\$1" == 1 ]; then
	if [ "\$sslmode" = "1" ]; then
		echo "Webmin install complete. You can now login to https://\$host:\$port/" >>\$tempdir/webmin-setup.out 2>&1
	else
		echo "Webmin install complete. You can now login to http://\$host:\$port/" >>\$tempdir/webmin-setup.out 2>&1
	fi
	echo "as root with your root password." >>\$tempdir/webmin-setup.out 2>&1
fi
/bin/true

%preun
if [ "\$1" = 0 ]; then
	grep root=/usr/libexec/webmin /etc/webmin/miniserv.conf >/dev/null 2>&1
	if [ "\$?" = 0 ]; then
		# RPM is being removed, and no new version of webmin
		# has taken it's place. Run uninstalls and stop the server
		/etc/webmin/stop >/dev/null 2>&1 </dev/null
		(cd /usr/libexec/webmin ; WEBMIN_CONFIG=/etc/webmin WEBMIN_VAR=/var/webmin LANG= /usr/libexec/webmin/run-uninstalls.pl) >/dev/null 2>&1 </dev/null
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
	mkdir /var/webmin
fi
if [ ! -r /etc/webmin/miniserv.conf -a -d /etc/.webmin-backup -a "\$1" = 2 ]; then
	rm -rf /etc/.webmin-broken
	mv /etc/webmin /etc/.webmin-broken
	mv /etc/.webmin-backup /etc/webmin
	if [ -r /etc/webmin/.post-install ]; then
		/etc/webmin/.post-install >/dev/null 2>&1 </dev/null
	fi
else
	rm -rf /etc/.webmin-backup
fi
/bin/true

EOF
close(SPEC);

$cmd = -x "/usr/bin/rpmbuild" ? "rpmbuild" : "rpm";
system("$cmd -ba --target=noarch $spec_dir/webmin-$ver.spec") && exit;

foreach $rpm ("rpm", "newkey/rpm") {
	if (-d $rpm) {
		system("cp $rpms_dir/webmin-$ver-$rel.noarch.rpm $rpm/webmin-$ver-$rel.noarch.rpm");
		print "Moved to $rpm/webmin-$ver-$rel.noarch.rpm\n";
		system("cp $srpms_dir/webmin-$ver-$rel.src.rpm $rpm/webmin-$ver-$rel.src.rpm");
		print "Moved to $rpm/webmin-$ver-$rel.src.rpm\n";
		system("chown jcameron: $rpm/webmin-$ver-$rel.noarch.rpm $rpm/webmin-$ver-$rel.src.rpm");
		if (!$nosign) {
			$key = $rpm eq "rpm" ? "jcameron\@webmin.com" : "developers\@webmin.com";
			$sigflag = $rpm eq "newkey/rpm" ? "-D '_binary_filedigest_algorithm SHA256'" : "";
			system("rpm --resign -D '_gpg_name $key' $sigflag $rpm/webmin-$ver-$rel.noarch.rpm $rpm/webmin-$ver-$rel.src.rpm");
			}
		}

	if (-d "/usr/local/webadmin/$rpm/yum") {
		# Add to our repository
		system("cp $rpm/webmin-$ver-$rel.noarch.rpm /usr/local/webadmin/$rpm/yum");
		}
	}

