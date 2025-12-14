#!/usr/local/bin/perl
# Build a Debian package of Webmin

use POSIX;

if ($ARGV[0] eq "--webmail" || $ARGV[0] eq "-webmail") {
	$webmail = 1;
	shift(@ARGV);
	}
if ($0 =~ /useradmin|usermin/ || `pwd` =~ /useradmin|usermin/) {
	if ($webmail) {
		$product = "usermin-webmail";
		}
	else {
		$product = "usermin";
		}
	$baseproduct = "usermin";
	$port = 20000;
	}
else {
	$product = "webmin";
	$baseproduct = "webmin";
	$port = 10000;
	}
$deb_maintainer = $ENV{'DEB_MAINTAINER'} ||
		  "Jamie Cameron <jcameron\@webmin.com>";
$ucproduct = ucfirst($baseproduct);
$tmp_dir = "/tmp/debian";
$debian_dir = "$tmp_dir/DEBIAN";
$control_file = "$debian_dir/control";
$doc_dir = "$tmp_dir/usr/share/doc/$baseproduct";
$copyright_file = "$doc_dir/copyright";
$usr_dir = "$tmp_dir/usr/share/$baseproduct";
$bin_dir = "$tmp_dir/usr/bin";
$pam_dir = "$tmp_dir/etc/pam.d";
$pam_file = "$pam_dir/$baseproduct";
$preinstall_file = "$debian_dir/preinst";
$postinstall_file = "$debian_dir/postinst";
$preuninstall_file = "$debian_dir/prerm";
$postuninstall_file = "$debian_dir/postrm";
$debian_copyright_file = "$debian_dir/copyright";
$changelog_file = "$debian_dir/changelog";
$changelog_doc_file = "$doc_dir/changelog";
$conffiles_file = "$debian_dir/conffiles";

-d "tarballs" || die "makedebian.pl must be run in the $ucproduct root directory";
-r "/etc/debian_version" || die "makedebian.pl must be run on Debian";
chop($webmin_dir = `pwd`);

@ARGV == 1 || @ARGV == 2 ||
	die "usage: makedebian.pl [--webmail] <version> [release]";
$ver = $ARGV[0];
if ($ARGV[1]) {
	$rel = "-".$ARGV[1];
	}
$tarfile = "tarballs/$product-$ver$rel.tar.gz";
if (!-r $tarfile) {
	$tarfile = "tarballs/$product-$ver.tar.gz";
	}
-r $tarfile || die "$tarfile not found";

# Create the base directories
print "Creating Debian package of ",ucfirst($product)," ",$ver,$rel," ..\n";
system("rm -rf $tmp_dir");
mkdir($tmp_dir, 0755);
chmod(0755, $tmp_dir);
mkdir($debian_dir, 0755);
system("mkdir -p $pam_dir");
system("mkdir -p $usr_dir");
system("mkdir -p $doc_dir");
system("mkdir -p $bin_dir");

# Un-tar the package to the correct locations
system("gunzip -c $tarfile | (cd $tmp_dir ; tar xf -)") &&
	die "un-tar failed!";
system("mv $tmp_dir/$product-$ver/* $usr_dir");
rmdir("$tmp_dir/$product-$ver");
system("mv $usr_dir/$baseproduct-debian-pam $pam_file");
system("cd $usr_dir && (find . -name '*.cgi' ; find . -name '*.pl') | perl perlpath.pl /usr/bin/perl -");
system("cd $usr_dir && rm -f mount/freebsd-mounts*");
system("cd $usr_dir && rm -f mount/openbsd-mounts*");
if ($product eq "webmin") {
	system("cd $usr_dir && rm -f mount/macos-mounts*");
	system("cd $usr_dir && rm -f webmin-gentoo-init");
	system("cd $usr_dir && rm -rf format bsdexports hpuxexports sgiexports zones rbac bsdfdisk");
	system("cd $usr_dir && rm -rf acl/Authen-SolarisRBAC-0.1*");
	}

# Set install type
system("echo deb >$usr_dir/install-type");
system("echo $product >$usr_dir/deb-name");
system("cd $usr_dir && chmod -R og-w .");
if ($< == 0) {
	system("cd $usr_dir && chown -R root:bin .");
	}
if ($ARGV[1] && $ARGV[1] > 1) {
	system("echo $ARGV[1] >$usr_dir/release");
	}
else {
	system("rm -f $usr_dir/release");
	}

# Create the link to webmin command
if ($product eq "webmin") {
	system("ln -s /usr/share/$baseproduct/bin/webmin $bin_dir/webmin");
	}

# Create the control file
$size = int(`du -sk $tmp_dir`);
@deps = ( "perl", "libnet-ssleay-perl", "openssl", "libauthen-pam-perl", "libpam-runtime", "libio-pty-perl", "unzip", "shared-mime-info", "tar", "libdigest-sha-perl", "libdigest-md5-perl", "gzip" );
$deps = join(", ", @deps);
@recommends = ( "libdatetime-perl", "libdatetime-timezone-perl", "libdatetime-locale-perl", "libtime-piece-perl", "libencode-detect-perl", "libtime-hires-perl", "libsocket6-perl", "html2text", "qrencode", "libdbi-perl", "libdbd-mysql-perl", "libdbd-mariadb-perl", "libjson-xs-perl", "libsys-syslog-perl" );
$recommends = join(", ", @recommends);
open(CONTROL, ">$control_file");
print CONTROL <<EOF;
Package: $product
Version: $ver$rel
Section: admin
Priority: optional
Architecture: all
Depends: $deps
Recommends: $recommends
Pre-Depends: perl
Installed-Size: $size
Maintainer: $deb_maintainer
Provides: $baseproduct
EOF
if ($product eq "webmin") {
	print CONTROL <<EOF;
Replaces: webmin-adsl, webmin-apache, webmin-bandwidth, webmin-bind, webmin-burner, webmin-cfengine, webmin-cluster, webmin-core, webmin-cpan, webmin-dhcpd, webmin-exim, webmin-exports, webmin-fetchmail, webmin-firewall, webmin-freeswan, webmin-frox, webmin-fsdump, webmin-grub, webmin-heartbeat, webmin-htaccess, webmin-inetd, webmin-jabber, webmin-ldap-netgroups, webmin-ldap-user-simple, webmin-ldap-useradmin, webmin-lilo, webmin-logrotate, webmin-lpadmin, webmin-lvm, webmin-mailboxes, webmin-mon, webmin-mysql, webmin-nis, webmin-openslp, webmin-postfix, webmin-postgresql, webmin-ppp, webmin-pptp-client, webmin-pptp-server, webmin-procmail, webmin-proftpd, webmin-pserver, webmin-quota, webmin-samba, webmin-sarg, webmin-sendmail, webmin-shorewall, webmin-slbackup, webmin-smart-status, webmin-snort, webmin-software, webmin-spamassassin, webmin-squid, webmin-sshd, webmin-status, webmin-stunnel, webmin-updown, webmin-usermin, webmin-vgetty, webmin-webalizer, webmin-wuftpd, webmin-wvdial, webmin-xinetd, webmin-filemin, webmin-authentic-theme
Description: web-based administration interface for Unix systems
 Using Webmin you can configure DNS, Samba, NFS, local/remote filesystems
 and more using your web browser. After installation, enter the URL
 https://localhost:10000/ into your browser and login as root with your root
 password.
EOF
	}
else {
	print CONTROL <<EOF;
Replaces: usermin-at, usermin-changepass, usermin-chfn, usermin-commands, usermin-cron, usermin-cshrc, usermin-fetchmail, usermin-forward, usermin-gnupg, usermin-htaccess, usermin-htpasswd, usermin-mailbox, usermin-man, usermin-mysql, usermin-plan, usermin-postgresql, usermin-proc, usermin-procmail, usermin-quota, usermin-schedule, usermin-shell, usermin-spamassassin, usermin-ssh, usermin-tunnel, usermin-updown, usermin-usermount, usermin-filemin, usermin-authentic-theme
Description: web-based user account administration interface for Unix systems
 After installation, enter the URL http://localhost:20000/ into your browser
 and login as any user on your system.
EOF
	}
close(CONTROL);

# Create the copyright file
$nowstr = strftime("%a, %d %b %Y %H:%M:%S %z", localtime(time()));
open(COPY, ">$copyright_file");
print COPY <<EOF;
This package was debianized by Jamie Cameron <jcameron\@webmin.com> on
$nowstr.

It was downloaded from: http://www.webmin.com/

Upstream author: Jamie Cameron <jcameron\@webmin.com>

Copyright:

EOF
open(BSD, "$usr_dir/LICENCE");
while(<BSD>) {
	print COPY $_;
	}
close(BSD);
close(COPY);
system("cp $copyright_file $debian_copyright_file");

# Create the config files file, for those we don't want to replace
open(CONF, ">$conffiles_file");
print CONF "/etc/pam.d/$baseproduct\n";
#print CONF "/etc/init.d/$baseproduct\n";	# Put this back sometime after
						# 1.973 has been out for a while
close(CONF);
chmod(0644, $conffiles_file);

# Get the changes for each module and version
$changes = { };
foreach $f (sort { $a cmp $b } ( glob("*/CHANGELOG"), "CHANGELOG" )) {
	# Get the module name and type
	local $mod = $f =~ /^(\S+)\/CHANGELOG/ ? $1 : "core";
	next if ($mod ne "core" && -l $mod);
	local $desc;
	if ($mod eq "core") {
		$desc = "$ucproduct Core";
		}
	else {
		local $m = $f;
		local %minfo;
		$m =~ s/CHANGELOG/module.info/;
		&read_file($m, \%minfo);
		next if (!$minfo{'longdesc'});
		$desc = $minfo{'desc'};
		}

	# Read its change log file
	local $inversion;
	open(LOG, $f);
	while(<LOG>) {
		s/\r|\n//g;
		if (/^----\s+Changes\s+since\s+(\S+)\s+----/) {
			$inversion = $1;
			}
		elsif ($inversion && /\S/) {
			push(@{$changes->{$inversion}->{$desc}}, $_);
			}
		}
	}

# Create the changelog file from actual changes, plus the historical changelog
open(CHANGELOG, ">$changelog_file");
foreach $v (sort { $a <=> $b } (keys %$changes)) {
	if ($ver > $v && sprintf("%.2f0", $ver) == $v) {
		$forv = $ver;
		}
	else {
		$forv = sprintf("%.2f0", $v+0.01);
		}
	@st = stat("tarballs/webmin-$forv.tar.gz");
	$vtimestr = strftime("%a, %d %b %Y %H:%M:%S %z", localtime($st[9]));
	print CHANGELOG "$baseproduct ($forv) stable; urgency=low\n";
	print CHANGELOG "\n";
	foreach $desc (keys %{$changes->{$v}}) {
		foreach $c (@{$changes->{$v}->{$desc}}) {
			@lines = &wrap_lines("$desc : $c", 65);
			print CHANGELOG " * $lines[0]\n";
			foreach $l (@lines[1 .. $#lines]) {
				print CHANGELOG "   $l\n";
				}
			}
		}
	print CHANGELOG "\n";
	print CHANGELOG "-- Jamie Cameron <jcameron\@webmin.com> $vtimestr\n";
	print CHANGELOG "\n";
	}
close(CHANGELOG);
system("iconv -f ISO-8859-1 -t UTF-8 $changelog_file >$changelog_doc_file");

# Get the temp-directory creator script
open(TEMP, "maketemp.pl");
while(<TEMP>) {
	$maketemp .= $_;
	}
close(TEMP);
$maketemp =~ s/\\/\\\\/g;
$maketemp =~ s/`/\\`/g;
$maketemp =~ s/\$/\\\$/g;

# Create the pre-install script
# No need for an OS check, as all debians are supported.
open(SCRIPT, ">$preinstall_file");
print SCRIPT <<EOF;
#!/bin/sh
perl <<EOD;
$maketemp
EOD
if [ "\$1" != "upgrade" -a "\$1" != "abort-upgrade" ]; then
	if [ "\$WEBMIN_PORT\" != \"\" ]; then
		port=\$WEBMIN_PORT
	else
		port=$port
	fi
	perl -e 'use Socket; socket(FOO, PF_INET, SOCK_STREAM, getprotobyname("tcp")); setsockopt(FOO, SOL_SOCKET, SO_REUSEADDR, pack("l", 1)); bind(FOO, pack_sockaddr_in(\$ARGV[0], INADDR_ANY)) || exit(1); exit(0);' \$port
	if [ "\$?" != "0" ]; then
		echo Port \$port is already in use
		exit 2
	fi
fi
EOF
close(SCRIPT);
system("chmod 755 $preinstall_file");

# Create the post-install script
open(SCRIPT, ">$postinstall_file");
print SCRIPT <<EOF;
#!/bin/sh
killmodenone=0
justinstalled=1
if [ -d "/etc/$baseproduct" ]; then
	justinstalled=0
fi
inetd=`grep "^inetd=" /etc/$baseproduct/miniserv.conf 2>/dev/null | sed -e 's/inetd=//g'`
productpidfile=`grep "^pidfile=" /etc/$baseproduct/miniserv.conf 2>/dev/null | sed -e 's/pidfile=//g'`
if [ -r "\$productpidfile" ]; then
	productrunning=1
fi
if [ "\$1" = "configure" ]; then
	# Upgrading the package, so stop the old Webmin properly
	if [ "\$inetd" != "1" ]; then
		if [ -f "/etc/$baseproduct/.pre-install" ]; then
			/etc/$baseproduct/.pre-install >/dev/null 2>&1 </dev/null
		else
			killmodenone=1
		fi
	fi
fi
cd /usr/share/$baseproduct
config_dir=/etc/$baseproduct
var_dir=/var/$baseproduct
perl=/usr/bin/perl
autoos=1
if [ "\$WEBMIN_PORT\" != \"\" ]; then
	port=\$WEBMIN_PORT
else
	port=$port
fi
login=root
if [ -r /etc/shadow ]; then
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
export config_dir var_dir perl autoos port login crypt host ssl nochown autothird noperlpath nouninstall nostart allow atboot makeboot nostop nodepsmsg
tempdir=/tmp/.webmin
if [ ! -d \$tempdir ]; then
	tempdir=/tmp
fi
./setup.sh >\$tempdir/$product-setup.out 2>&1
if [ "$product" = "webmin" ]; then
	grep sudo= /etc/$product/miniserv.conf >/dev/null 2>&1
	if [ "\$?" = 1 ]; then
		# Allow sudo-based logins for Ubuntu
		echo sudo=1 >>/etc/$product/miniserv.conf
	fi
fi
rm -f /var/lock/subsys/$baseproduct

if [ "\$inetd" != "1" ]; then
	productucf=Webmin
	if [ "$product" = "usermin" ]; then
		productucf=Usermin
	fi
	if [ "\$justinstalled" = "1" ]; then
		/etc/$baseproduct/start >/dev/null 2>&1 </dev/null
		if [ "\$?" != "0" ]; then
			echo "E: \${productucf} server cannot be started. It is advised to start it manually by\n   running \\"/etc/$baseproduct/restart-by-force-kill\\" command"
		fi
	else
		if [ "$product" = "webmin" ]; then
			if [ "\$killmodenone" != "1" ]; then
				/etc/$baseproduct/.post-install >/dev/null 2>&1 </dev/null
			else
				/etc/$baseproduct/.reload-init >/dev/null 2>&1 </dev/null
				if [ -f /etc/$baseproduct/.reload-init-systemd ]; then
					/etc/$baseproduct/.reload-init-systemd >/dev/null 2>&1 </dev/null
					rm -f /etc/$baseproduct/.reload-init-systemd
				fi
			fi
		else
			if [ "\$productrunning" = "1" ]; then
				/etc/$baseproduct/restart >/dev/null 2>&1 </dev/null
				if [ "\$?" != "0" ]; then
					echo "W: \${productucf} server cannot be restarted. It is advised to restart it manually by\n   running \\"/etc/$baseproduct/restart-by-force-kill\\" command when upgrade process is finished"
				fi
			fi
		fi
	fi
fi

cat >/etc/$baseproduct/uninstall.sh <<EOFF
#!/bin/sh
printf "Are you sure you want to uninstall $ucproduct? (y/n) : "
read answer
printf "\\n"
if [ "\\\$answer" = "y" ]; then
	echo "Removing $ucproduct package .."
	rm -f /usr/share/$baseproduct/authentic-theme/manifest-*
	dpkg --remove --force-depends $product
	systemctlcmd=\\\`which systemctl 2>/dev/null\\\`
	if [ -x "\\\$systemctlcmd" ]; then
		\\\$systemctlcmd stop $product >/dev/null 2>&1 </dev/null
		rm -f /lib/systemd/system/$product.service
		\\\$systemctlcmd daemon-reload
	fi
	echo ".. done"
fi
EOFF
chmod +x /etc/$baseproduct/uninstall.sh
port=`grep "^port=" /etc/$baseproduct/miniserv.conf | sed -e 's/port=//g'`
perl -e 'use Net::SSLeay' >/dev/null 2>/dev/null
sslmode=0
if [ "\$?" = "0" ]; then
	grep ssl=1 /etc/$baseproduct/miniserv.conf >/dev/null 2>/dev/null
	if [ "\$?" = "0" ]; then
		sslmode=1
	fi
fi
if [ "\$sslmode" = "1" ]; then
	echo "$ucproduct install complete. You can now login to https://\$host:\$port/" >>\$tempdir/$product-setup.out 2>&1
else
	echo "$ucproduct install complete. You can now login to http://\$host:\$port/" >>\$tempdir/$product-setup.out 2>&1
fi
if [ "$product" = "webmin" ]; then
	echo "as root with your root password, or as any user who can use sudo" >>\$tempdir/$product-setup.out 2>&1
	echo "to run commands as root." >>\$tempdir/$product-setup.out 2>&1
else
	echo "as any user on the system." >>\$tempdir/$product-setup.out 2>&1
fi
EOF
close(SCRIPT);
system("chmod 755 $postinstall_file");

# Create the pre-uninstall script
open(SCRIPT, ">$preuninstall_file");
print SCRIPT <<EOF;
#!/bin/sh
if [ "\$1" != "upgrade" -a "\$1" != "abort-upgrade" ]; then
	grep root=/usr/share/$baseproduct /etc/$baseproduct/miniserv.conf >/dev/null 2>&1
	if [ "\$?" = 0 ]; then
		# Package is being removed, and no new version of webmin
		# has taken it's place. Run uninstalls and stop the server
		/etc/$baseproduct/stop >/dev/null 2>&1 </dev/null
		if [ "$product" = "webmin" ]; then
			(cd /usr/share/$baseproduct ; WEBMIN_CONFIG=/etc/$baseproduct WEBMIN_VAR=/var/$baseproduct LANG= /usr/share/$baseproduct/run-uninstalls.pl) >/dev/null 2>&1 </dev/null
		else
			rm -f /usr/share/$baseproduct/authentic-theme/manifest-*
			systemctlcmd=\`which systemctl 2>/dev/null\`
			if [ -x "\$systemctlcmd" ]; then
				\$systemctlcmd stop $product >/dev/null 2>&1 </dev/null
				rm -f /lib/systemd/system/$product.service
				\$systemctlcmd daemon-reload
			fi
		fi
		/bin/true
	fi
fi
EOF
close(SCRIPT);
system("chmod 755 $preuninstall_file");

# Create the post-uninstall script
open(SCRIPT, ">$postuninstall_file");
print SCRIPT <<EOF;
#!/bin/sh
if [ "\$1" != "upgrade" -a "\$1" != "abort-upgrade" ]; then
	grep root=/usr/share/$baseproduct /etc/$baseproduct/miniserv.conf >/dev/null 2>&1
	if [ "\$?" = 0 ]; then
		# Package is being removed, and no new version of Webmin
		# has taken its place. Delete the config files
		rm -rf /etc/$baseproduct /var/$baseproduct
		rm -f /etc/pam.d/$baseproduct
	fi
fi
EOF
close(SCRIPT);
system("chmod 755 $postuninstall_file");

foreach my $deb ("deb", "newkey/deb") {
	# Run the actual build command
	system("fakeroot dpkg --build $tmp_dir $deb/${product}_${ver}${rel}_all.deb") &&
		die "dpkg failed";
	print "Wrote $deb/${product}_${ver}${rel}_all.deb\n";
	$md5 = `md5sum $tarfile`;
	$md5 =~ s/\s+.*\n//g;
	@st = stat($tarfile);

	# Create the .diff file, which just contains the debian directory
	$diff_orig_dir = "$tmp_dir/$product-$ver-orig";
	$diff_new_dir = "$tmp_dir/$product-$ver";
	mkdir($diff_orig_dir, 0755);
	mkdir($diff_new_dir, 0755);
	system("cp -r $debian_dir $diff_new_dir");
	system("cd $tmp_dir && diff -r -N -u $product-$ver-orig $product-$ver >$webmin_dir/$deb/${product}_${ver}${rel}.diff");
	$diffmd5 = `md5sum $deb/${product}_${ver}${rel}.diff`;
	$diffmd5 =~ s/\s+.*\n//g;
	@diffst = stat("$deb/${product}_${ver}${rel}.diff");

	# Create the .dsc file
	open(DSC, ">$deb/${product}_$ver$rel.plain");
	print DSC <<EOF;
Format: 1.0
Source: $product
Version: $ver$rel
Binary: $product
Architecture: all
Standards-Version: 3.6.1
Build-Depends-Indep: debhelper (>= 4.1.16), debconf (>= 0.5.00), perl
Maintainer: $deb_maintainer
Uploaders: $deb_maintainer
Files:
 $md5 $st[7] ${product}-${ver}.tar.gz
 $diffmd5 $diffst[7] ${product}_${ver}.diff

EOF
	close(DSC);

	print "Creating signature $deb/${product}_$ver$rel.dsc\n";
	$key = $deb eq "deb" ? "jcameron\@webmin.com"
			     : "developers\@webmin.com";
	unlink("$deb/${product}_$ver$rel.dsc");
	$ex = system("gpg --default-key $key --output $deb/${product}_$ver$rel.dsc --clearsign $deb/${product}_$ver$rel.plain");
	if ($ex) {
		print "Failed to create $deb/${product}_$ver$rel.dsc\n";
		}
	else {
		unlink("$deb/${product}_$ver$rel.plain");
		print "Wrote source $deb/${product}_$ver$rel.dsc\n";
		}

	$dir = $deb eq "deb" ? "sarge" : "stable";
	if (-d "/usr/local/webadmin/$deb/repository") {
		# Add to our repository
		chdir("/usr/local/webadmin/$deb/repository");
		system("reprepro -Vb . remove $dir $product");
		system("reprepro -Vb . includedeb $dir ../${product}_${ver}${rel}_all.deb");
		chdir("/usr/local/webadmin");
		}

	# Create PGP signature
	print "Signing sigs/${product}_${ver}${rel}_all.deb-sig.asc\n";
	unlink("sigs/${product}_${ver}${rel}_all.deb-sig.asc");
	system("gpg --armor --output sigs/${product}_${ver}${rel}_all.deb-sig.asc --default-key $key --detach-sig $deb/${product}_${ver}${rel}_all.deb");
	print "Wrote sigs/${product}_${ver}${rel}_all.deb-sig.asc\n";

	system("rm -rf $diff_orig_dir $diff_new_dir");
	}

# read_file(file, &assoc, [&order], [lowercase])
# Fill an associative array with name=value pairs from a file
sub read_file
{
local $_;
open(ARFILE, $_[0]) || return 0;
while(<ARFILE>) {
	chomp;
	local $hash = index($_, "#");
	local $eq = index($_, "=");
	if ($hash != 0 && $eq >= 0) {
		local $n = substr($_, 0, $eq);
		local $v = substr($_, $eq+1);
		$_[1]->{$_[3] ? lc($n) : $n} = $v;
		push(@{$_[2]}, $n) if ($_[2]);
        	}
        }
close(ARFILE);
if (defined($main::read_file_cache{$_[0]})) {
	%{$main::read_file_cache{$_[0]}} = %{$_[1]};
	}
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


