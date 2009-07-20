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
$ucproduct = ucfirst($baseproduct);
$tmp_dir = "/tmp/debian";
$debian_dir = "$tmp_dir/DEBIAN";
$control_file = "$debian_dir/control";
$usr_dir = "$tmp_dir/usr/share/$baseproduct";
$pam_dir = "$tmp_dir/etc/pam.d";
$init_dir = "$tmp_dir/etc/init.d";
@rc_dirs = ( "$tmp_dir/etc/rc2.d", "$tmp_dir/etc/rc3.d", "$tmp_dir/etc/rc5.d" );
$pam_file = "$pam_dir/$baseproduct";
$preinstall_file = "$debian_dir/preinst";
$postinstall_file = "$debian_dir/postinst";
$preuninstall_file = "$debian_dir/prerm";
$postuninstall_file = "$debian_dir/postrm";
$copyright_file = "$debian_dir/copyright";
$changelog_file = "$debian_dir/changelog";
$conffiles_file = "$debian_dir/conffiles";

-d "tarballs" || die "makedebian.pl must be run in the $ucproduct root directory";
-r "/etc/debian_version" || die "makedebian.pl must be run on Debian";
chop($webmin_dir = `pwd`);

@ARGV == 1 || die "usage: makedebian.pl [--webmail] <version>";
$ver = $ARGV[0];
-r "tarballs/$product-$ver.tar.gz" || die "tarballs/$product-$ver.tar.gz not found";

# Create the base directories
print "Creating Debian package of ",ucfirst($product)," ",$ver," ...\n";
system("rm -rf $tmp_dir");
mkdir($tmp_dir, 0755);
chmod(0755, $tmp_dir);
mkdir($debian_dir, 0755);
system("mkdir -p $pam_dir");
if ($baseproduct eq "usermin") {
	system("mkdir -p $init_dir");
	foreach $d (@rc_dirs) {
		system("mkdir -p $d");
		}
	}
system("mkdir -p $usr_dir");

# Un-tar the package to the correct locations
system("gunzip -c tarballs/$product-$ver.tar.gz | (cd $tmp_dir ; tar xf -)") &&
	die "un-tar failed!";
system("mv $tmp_dir/$product-$ver/* $usr_dir");
rmdir("$tmp_dir/$product-$ver");
system("mv $usr_dir/$baseproduct-pam $pam_file");
system("cd $usr_dir && (find . -name '*.cgi' ; find . -name '*.pl') | perl perlpath.pl /usr/bin/perl -");
system("cd $usr_dir && rm -f mount/freebsd-mounts*");
system("cd $usr_dir && rm -f mount/openbsd-mounts*");
if ($product eq "webmin") {
	system("cd $usr_dir && rm -f mount/macos-mounts*");
	system("cd $usr_dir && rm -f webmin-gentoo-init");
	system("cd $usr_dir && rm -rf format bsdexports hpuxexports sgiexports zones rbac");
	}
else {
	# Need to create init script
	system("mv $usr_dir/$baseproduct-init $init_dir/$baseproduct");
	foreach $d (@rc_dirs) {
		system("ln -s ../init.d/$baseproduct $d/S99$baseproduct");
		}
	}
system("echo deb >$usr_dir/install-type");
system("echo $product >$usr_dir/deb-name");
system("cd $usr_dir && chmod -R og-w .");
if ($< == 0) {
	system("cd $usr_dir && chown -R root:bin .");
	}
$size = int(`du -sk $tmp_dir`);

# Create the control file
open(CONTROL, ">$control_file");
print CONTROL <<EOF;
Package: $product
Version: $ver
Section: admin
Priority: optional
Architecture: all
Essential: no
Depends: bash, perl, libnet-ssleay-perl, openssl, libauthen-pam-perl, libpam-runtime, libio-pty-perl, libmd5-perl
Pre-Depends: bash, perl
Installed-Size: $size
Maintainer: Jamie Cameron <jcameron\@webmin.com>
Provides: $baseproduct
EOF
if ($product eq "webmin") {
	print CONTROL <<EOF;
Replaces: webmin-adsl, webmin-apache, webmin-bandwidth, webmin-bind, webmin-burner, webmin-cfengine, webmin-cluster, webmin-core, webmin-cpan, webmin-dhcpd, webmin-exim, webmin-exports, webmin-fetchmail, webmin-firewall, webmin-freeswan, webmin-frox, webmin-fsdump, webmin-grub, webmin-heartbeat, webmin-htaccess, webmin-inetd, webmin-jabber, webmin-ldap-netgroups, webmin-ldap-user-simple, webmin-ldap-useradmin, webmin-lilo, webmin-logrotate, webmin-lpadmin, webmin-lvm, webmin-mailboxes, webmin-mon, webmin-mysql, webmin-nis, webmin-openslp, webmin-postfix, webmin-postgresql, webmin-ppp, webmin-pptp-client, webmin-pptp-server, webmin-procmail, webmin-proftpd, webmin-pserver, webmin-quota, webmin-samba, webmin-sarg, webmin-sendmail, webmin-shorewall, webmin-slbackup, webmin-smart-status, webmin-snort, webmin-software, webmin-spamassassin, webmin-squid, webmin-sshd, webmin-status, webmin-stunnel, webmin-updown, webmin-usermin, webmin-vgetty, webmin-webalizer, webmin-wuftpd, webmin-wvdial, webmin-xinetd
Description: A web-based administration interface for Unix systems.
	     Using Webmin you can configure DNS, Samba, NFS, local/remote
	     filesystems and more using your web browser.  After installation,
	     enter the URL https://localhost:10000/ into your browser and
	     login as root with your root password.
EOF
	}
else {
	print CONTROL <<EOF;
Replaces: usermin-at, usermin-changepass, usermin-chfn, usermin-commands, usermin-cron, usermin-cshrc, usermin-fetchmail, usermin-forward, usermin-gnupg, usermin-htaccess, usermin-htpasswd, usermin-mailbox, usermin-man, usermin-mysql, usermin-plan, usermin-postgresql, usermin-proc, usermin-procmail, usermin-quota, usermin-schedule, usermin-shell, usermin-spamassassin, usermin-ssh, usermin-tunnel, usermin-updown, usermin-usermount
Description: A web-based user account administration interface for Unix systems.
	     After installation, enter the URL http://localhost:20000/ into your	     browser and login as any user on your system.
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

# Create the config files file, for those we don't want to replace
open(CONF, ">$conffiles_file");
print CONF "/etc/pam.d/$baseproduct\n";
close(CONF);

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
if [ "\$1" != "upgrade" ]; then
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
inetd=`grep "^inetd=" /etc/$baseproduct/miniserv.conf 2>/dev/null | sed -e 's/inetd=//g'`
if [ "\$1" = "upgrade" ]; then
	# Upgrading the package, so stop the old webmin properly
	if [ "\$inetd" != "1" ]; then
		/etc/init.d/$baseproduct stop >/dev/null 2>&1 </dev/null
	fi
fi
cd /usr/share/$baseproduct
config_dir=/etc/$baseproduct
var_dir=/var/$baseproduct
perl=/usr/bin/perl
autoos=3
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
nochown=1
autothird=1
noperlpath=1
nouninstall=1
nostart=1
export config_dir var_dir perl autoos port login crypt host ssl nochown autothird noperlpath nouninstall nostart allow atboot
./setup.sh >/tmp/.webmin/$product-setup.out 2>&1
if [ "$product" = "webmin" ]; then
	grep sudo= /etc/$product/miniserv.conf >/dev/null 2>&1
	if [ "\$?" = 1 ]; then
		# Allow sudo-based logins for Ubuntu
		echo sudo=1 >>/etc/$product/miniserv.conf
	fi
fi
rm -f /var/lock/subsys/$baseproduct
if [ "$inetd" != "1" ]; then
	if [ -x "`which invoke-rc.d 2>/dev/null`" ]; then
		invoke-rc.d $baseproduct start >/dev/null 2>&1 </dev/null
	else
		/etc/init.d/$baseproduct start >/dev/null 2>&1 </dev/null
	fi
fi
cat >/etc/$baseproduct/uninstall.sh <<EOFF
#!/bin/sh
printf "Are you sure you want to uninstall $ucproduct? (y/n) : "
read answer
printf "\\n"
if [ "\\\$answer" = "y" ]; then
	echo "Removing $ucproduct package .."
	dpkg --remove $product
	echo "Done!"
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
	echo "$ucproduct install complete. You can now login to https://\$host:\$port/"
else
	echo "$ucproduct install complete. You can now login to http://\$host:\$port/"
fi
if [ "$product" = "webmin" ]; then
	echo "as root with your root password, or as any user who can use sudo"
	echo "to run commands as root."
else
	echo "as any user on the system."
fi
EOF
close(SCRIPT);
system("chmod 755 $postinstall_file");

# Create the pre-uninstall script
open(SCRIPT, ">$preuninstall_file");
print SCRIPT <<EOF;
#!/bin/sh
if [ "\$1" != "upgrade" ]; then
	grep root=/usr/share/$baseproduct /etc/$baseproduct/miniserv.conf >/dev/null 2>&1
	if [ "\$?" = 0 ]; then
		# Package is being removed, and no new version of webmin
		# has taken it's place. Run uninstalls and stop the server
		if [ "$product" = "webmin" ]; then
			echo "Running uninstall scripts .."
			(cd /usr/share/$baseproduct ; WEBMIN_CONFIG=/etc/$baseproduct WEBMIN_VAR=/var/$baseproduct LANG= /usr/share/$baseproduct/run-uninstalls.pl)
		fi
		/etc/init.d/$baseproduct stop >/dev/null 2>&1 </dev/null
		/etc/$baseproduct/stop >/dev/null 2>&1 </dev/null
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
if [ "\$1" != "upgrade" ]; then
	grep root=/usr/share/$baseproduct /etc/$baseproduct/miniserv.conf >/dev/null 2>&1
	if [ "\$?" = 0 ]; then
		# Package is being removed, and no new version of webmin
		# has taken it's place. Delete the config files
		rm -rf /etc/$baseproduct /var/$baseproduct
	fi
fi
EOF
close(SCRIPT);
system("chmod 755 $postuninstall_file");

# Run the actual build command
system("fakeroot dpkg --build $tmp_dir deb/${product}_${ver}_all.deb") &&
	die "dpkg failed";
#system("rm -rf $tmp_dir");
print "Wrote deb/${product}_${ver}_all.deb\n";
$md5 = `md5sum tarballs/$product-$ver.tar.gz`;
$md5 =~ s/\s+.*\n//g;
@st = stat("tarballs/$product-$ver.tar.gz");

# Create the .diff file, which just contains the debian directory
$diff_orig_dir = "$tmp_dir/$product-$ver-orig";
$diff_new_dir = "$tmp_dir/$product-$ver";
mkdir($diff_orig_dir, 0755);
mkdir($diff_new_dir, 0755);
system("cp -r $debian_dir $diff_new_dir");
system("cd $tmp_dir && diff -r -N -u $product-$ver-orig $product-$ver >$webmin_dir/deb/${product}_${ver}.diff");
$diffmd5 = `md5sum deb/${product}_${ver}.diff`;
$diffmd5 =~ s/\s+.*\n//g;
@diffst = stat("deb/${product}_${ver}.diff");

# Create the .dsc file
open(DSC, ">deb/${product}_$ver.plain");
print DSC <<EOF;
Format: 1.0
Source: $product
Version: $ver
Binary: $product
Maintainer: Jamie Cameron <jcameron\@webmin.com>
Architecture: all
Standards-Version: 3.6.1
Build-Depends-Indep: debhelper (>= 4.1.16), debconf (>= 0.5.00), perl
Uploaders: Jamie Cameron <jcameron\@webmin.com>
Files:
 $md5 $st[7] ${product}-${ver}.tar.gz
 $diffmd5 $diffst[7] ${product}_${ver}.diff

EOF
close(DSC);
unlink("deb/${product}_$ver.dsc");
system("gpg --output deb/${product}_$ver.dsc --clearsign deb/${product}_$ver.plain");
unlink("deb/${product}_$ver.plain");
print "Wrote source deb/${product}_$ver.dsc\n";

if (-d "/usr/local/webadmin/deb/repository") {
	# Add to our repository
	chdir("/usr/local/webadmin/deb/repository");
	system("reprepro -Vb . remove sarge $product");
	system("reprepro -Vb . includedeb sarge ../${product}_${ver}_all.deb");
	chdir("/usr/local/webadmin");
	}

# Create PGP signature
unlink("sigs/${product}_${ver}_all.deb-sig.asc");
system("gpg --armor --output sigs/${product}_${ver}_all.deb-sig.asc --default-key jcameron\@webmin.com --detach-sig deb/${product}_${ver}_all.deb");

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


