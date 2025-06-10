#!/usr/bin/perl
# makepackage.pl <version>
# Copy files from some directory to /opt/webmin and build a package

@ARGV || die "usage: makepackage.pl <version> [directory]";
$dir = $ARGV[1] || "/usr/local/webadmin/tarballs/webmin-$ARGV[0]";
$> == 0 || die "makepackage.pl must be run as root";
-r "$dir/version" || die "$dir does not look like a webmin directory";
chop($v = `cat $dir/version`);

print "Copying $dir to /opt/webmin ..\n";
system("rm -rf /opt/webmin");
mkdir("/opt/webmin", 0755);
system("cd $dir && /opt/csw/bin/gtar cf - . | (cd /opt/webmin ; /opt/csw/bin/gtar xf -)");
open(MODE, ">/opt/webmin/install-type");
print MODE "solaris-pkg\n";
close(MODE);
system("chown -R root /opt/webmin");
system("chgrp -R bin /opt/webmin");
system("chmod -R og-rxw /opt/webmin");
print ".. done\n\n";

print "Deleting non-Solaris modules ..\n";
system("cd /opt/webmin ; rm -rf /opt/webmin/{adsl-client,exports,fdisk,firewall,frox,grub,heartbeat,idmapd,ipsec,krb5,lilo,lvm,ppp-client,pptp-client,pptp-server,raid,shorewall,smart-status,vgetty,ldap-client,iscsi-server,iscsi-client,iscsi-target,bsdfdisk,firewalld}");
print ".. done\n\n";

print "Setting Perl path to /usr/bin/perl ..\n";
system("(find /opt/webmin -name '*.cgi' -print ; find /opt/webmin -name '*.pl' -print) | perl /opt/webmin/perlpath.pl /usr/bin/perl -");
print ".. done\n\n";

print "Making prototype file ..\n";
chdir("/opt/webmin");
open(PROTO, "> prototype");
print PROTO "i pkginfo=/opt/webmin/pkginfo\n";
close(PROTO);
system("find . -print | grep -v \"^prototype\" | pkgproto >>prototype");
open(PROTO, ">> prototype");
print PROTO "i postinstall=./postinstall\n";
print PROTO "i preremove=./preremove\n";
print PROTO "f none /etc/init.d/webmin=webmin-init 0755 root sys\n";
print PROTO "l none /etc/rc3.d/S99webmin=/etc/init.d/webmin\n";
print PROTO "l none /etc/rc0.d/K10webmin=/etc/init.d/webmin\n";
print PROTO "l none /etc/rc1.d/K10webmin=/etc/init.d/webmin\n";
print PROTO "l none /etc/rc2.d/K10webmin=/etc/init.d/webmin\n";
print PROTO "l none /etc/rcS.d/K10webmin=/etc/init.d/webmin\n";
close(PROTO);
print ".. done\n\n";

print "Making postinstall file ..\n";
open(POST, "> postinstall");
print POST <<EOF;
echo "Executing postinstall script .."
cd /opt/webmin
config_dir=/etc/webmin
var_dir=/var/webmin
perl=/usr/bin/perl
autoos=1
port=10000
login=root
crypt=x
ssl=0
atboot=0
nochown=1
autothird=1
noperlpath=1
nouninstall=1
export config_dir var_dir perl autoos port login crypt ssl atboot nochown autothird noperlpath nouninstall
./setup.sh
EOF
close(POST);
print ".. done\n\n";

print "Making preremove file ..\n";
open(PRE, "> preremove");
print PRE <<EOF;
echo "In preremove script.."
/etc/webmin/stop
grep root=/opt/webmin /etc/webmin/miniserv.conf >/dev/null 2>&1
if [ "\$?" = 0 -a "\$KEEP_ETC_WEBMIN" = "" ]; then
	# Package is being removed, and no new version of webmin
	# has taken it's place. Delete the config files
	echo "Running uninstall scripts .."
	(cd /opt/webmin ; WEBMIN_CONFIG=/etc/webmin WEBMIN_VAR=/var/webmin /opt/webmin/run-uninstalls.pl)
	rm -rf /etc/webmin /var/webmin
fi
EOF
close(PRE);
print ".. done\n\n";

print "Making pkginfo file ..\n";
@tm = localtime(time());
$pstamp = sprintf("%4.4d%2.2%2.2d%2.2d%2.2d%2.2d",
		$tm[5]+1900, $tm[4]+1, $tm[3], $tm[2], $tm[1], $tm[0]);
open(INFO, "> pkginfo");
print INFO <<EOF;
PKG="WSwebmin"
NAME="Webmin - Web-based system administration"
ARCH="all"
VERSION="$v"
CATEGORY="application"
VENDOR="Webmin Software"
EMAIL="jcameron\@webmin.com"
PSTAMP="Jamie Cameron"
BASEDIR="/opt/webmin"
CLASSES="none"
PSTAMP="$pstamp"
MAXINST="2"
EOF
close(INFO);
print ".. done\n\n";

print "Running pkgmk ..\n";
system("pkgmk -o -r /opt/webmin");
print ".. done\n\n";

print "Running pkgtrans ..\n";
system("pkgtrans -s /var/spool/pkg webmin-$v.pkg WSwebmin");
print ".. done\n\n";

print "Delete files in /opt/webmin ..\n";
chdir("/");
system("rm -rf /opt/webmin");
print ".. done\n\n";

print "Delete files in /var/spool/pkg ..\n";
system("rm -rf /var/spool/pkg/WSwebmin");
print ".. done\n\n";

if (-d "/usr/local/webadmin/solaris-pkg") {
	$dest = "/usr/local/webadmin/solaris-pkg/webmin-$v.pkg.gz";
	print "Moving package to $dest ..\n";
	system("gzip -c /var/spool/pkg/webmin-$v.pkg >$dest");
	unlink("/var/spool/pkg/webmin-$v.pkg");
	print ".. done\n\n";
	}

