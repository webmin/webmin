#!/usr/local/bin/perl
# Builds a tar.gz package of a specified Webmin version

@ARGV == 1 || @ARGV == 2 || usage();
if ($ARGV[0] eq "-minimal" || $ARGV[0] eq "--minimal") {
	$min++;
	shift(@ARGV);
	}
$vers = $ARGV[0];
$vers =~ /^[0-9\.]+$/ || usage();
$tardir = $min ? "minimal" : "tarballs";
$vfile = $min ? "$vers-minimal" : $vers;
$zipdir = "zips";

@files = ("config.cgi", "config-*-linux",
	  "config-solaris", "images", "index.cgi", "mime.types",
	  "miniserv.pl", "os_list.txt", "perlpath.pl", "setup.sh", "setup.pl",
	  "version", "web-lib.pl", "web-lib-funcs.pl", "README",
	  "config_save.cgi", "chooser.cgi", "miniserv.pem",
	  "config-aix",
	  "newmods.pl", "copyconfig.pl", "config-hpux", "config-freebsd",
	  "changepass.pl", "help.cgi", "user_chooser.cgi",
	  "group_chooser.cgi", "config-irix", "config-osf1", "thirdparty.pl",
	  "oschooser.pl", "config-unixware",
	  "config-openserver", "switch_user.cgi", "lang", "lang_list.txt",
	  "webmin-init", "webmin-caldera-init", "webmin-daemon",
	  "config-openbsd",
	  "config-macos", "LICENCE",
	  "session_login.cgi", "acl_security.pl",
	  "defaultacl", "rpc.cgi", "date_chooser.cgi", "switch_skill.cgi",
	  "install-module.pl", "LICENCE.ja", 
	  "favicon.ico", "config-netbsd", "fastrpc.cgi",
	  "defaulttheme", "feedback.cgi", "feedback_form.cgi",
	  "javascript-lib.pl", "webmin-pam", "webmin-debian-pam", "maketemp.pl",
	  "run-uninstalls.pl",
	  "webmin-gentoo-init", "run-postinstalls.pl",
	  "config-lib.pl", "entities_map.txt", "ui-lib.pl",
	  "password_form.cgi", "password_change.cgi", "pam_login.cgi",
	  "module_chooser.cgi", "config-windows", "xmlrpc.cgi",
	  "uptracker.cgi", "create-module.pl", "webmin_search.cgi",
	  "webmin-search-lib.pl", "WebminCore.pm",
	  "record-login.pl", "record-logout.pl", "robots.txt",
	 );
if ($min) {
	# Only those required by others
	@mlist = ("cron", "init", "inittab", "proc", "webmin", "acl", "servers",
		  "man", "webminlog", "system-status");
	}
else {
	# All the modules
	@mlist =
	  ("cron", "dfsadmin", "dnsadmin", "exports", "inetd", "init",
	  "mount", "samba", "useradmin", "fdisk", "format", "proc", "webmin",
	  "quota", "software", "pap", "acl", "apache", "lpadmin", "bind8",
	  "sendmail", "squid", "bsdexports", "hpuxexports", "file",
	  "net", "dhcpd", "majordomo", "custom", "lilo", "telnet", "servers",
	  "time", "wuftpd", "syslog", "mysql", "man",
	  "inittab", "raid", "postfix", "webminlog", "postgresql", "xinetd",
	  "status", "cpan", "caldera", "pam", "nis", "shell", "grub",
	  "fetchmail", "passwd", "at", "proftpd", "sshd",
	  "heartbeat", "cluster-software", "cluster-useradmin", "qmailadmin",
	  "mon", "mscstyle3", "jabber", "stunnel", "burner", "usermin",
	  "fsdump", "lvm", "sentry", "cfengine", "pserver", "procmail",
	  "cluster-webmin", "firewall", "sgiexports", "vgetty", "openslp",
	  "webalizer", "shorewall", "adsl-client", "updown", "ppp-client",
	  "pptp-server", "pptp-client", "ipsec", "ldap-useradmin",
	  "change-user", "cluster-shell", "cluster-cron", "spam",
	  "htaccess-htpasswd", "logrotate", "cluster-passwd", "mailboxes",
	  "ipfw", "frox", "sarg", "bandwidth", "cluster-copy", "backup-config",
	  "smart-status", "idmapd", "krb5", "smf", "ipfilter", "rbac",
	  "tunnel", "zones", "cluster-usermin", "dovecot", "syslog-ng",
	  "mailcap", "blue-theme", "ldap-client", "phpini", "filter",
	  "bacula-backup", "ldap-server", "exim", "tcpwrappers",
	  "package-updates", "system-status",
	  );
	}
@dirlist = ( "Webmin" );

if (-d "/usr/local/webadmin") {
	chdir("/usr/local/webadmin");
	system("./koi8-to-cp1251.pl");
	system("./make-small-icons.pl /usr/local/webadmin");
	}
$dir = "webmin-$vers";
system("rm -rf $tardir/$dir");
mkdir("$tardir/$dir", 0755);

# Copy top-level files to directory
print "Adding top-level files\n";
$flist = join(" ", @files);
system("cp -r -L $flist $tardir/$dir");
system("touch $tardir/$dir/install-type");
system("echo $vers > $tardir/$dir/version");
if ($min) {
	system("touch $tardir/$dir/minimal-install");
	}

# Add module files
foreach $m (@mlist) {
	print "Adding module $m\n";
	mkdir("$tardir/$dir/$m", 0755);
	$flist = "";
	opendir(DIR, $m);
	foreach $f (readdir(DIR)) {
		if ($f =~ /^\./ || $f eq "test" || $f =~ /\.bak$/ ||
		    $f =~ /\.tmp$/ || $f =~ /\.site$/) { next; }
		$flist .= " $m/$f";
		}
	closedir(DIR);
	system("cp -r -L $flist $tardir/$dir/$m");
	}

# Remove files that shouldn't be publicly available
system("rm -rf $tardir/$dir/status/mailserver*");
system("rm -rf $tardir/$dir/file/plugin.jar");

# Add other directories
foreach $d (@dirlist) {
	print "Adding directory $d\n";
	system("cp -r $d $tardir/$dir");
	}

# Update module.info and theme.info files with depends and version
opendir(DIR, "$tardir/$dir");
while($d = readdir(DIR)) {
	# set depends in module.info to this version
	local $minfo = "$tardir/$dir/$d/module.info";
	local $tinfo = "$tardir/$dir/$d/theme.info";
	if (-r $minfo) {
		local %minfo;
		&read_file($minfo, \%minfo);
		$minfo{'depends'} = join(" ", split(/\s+/, $minfo{'depends'}),
					      $vers);
		$minfo{'version'} = $vers;
		&write_file($minfo, \%minfo);
		}
	elsif (-r $tinfo) {
		local %tinfo;
		&read_file($tinfo, \%tinfo);
		$tinfo{'depends'} = join(" ", split(/\s+/, $tinfo{'depends'}),
					      $vers);
		$tinfo{'version'} = $vers;
		&write_file($tinfo, \%tinfo);
		}
	}
closedir(DIR);

# Remove useless .bak, test and other files, and create the tar.gz file
print "Creating webmin-$vfile.tar.gz\n";
system("find $tardir/$dir -name '*.bak' -o -name test -o -name '*.tmp' -o -name '*.site' -o -name core -o -name .xvpics -o -name .svn | xargs rm -rf");
system("cd $tardir ; tar cvhf - $dir 2>/dev/null | gzip -c >webmin-$vfile.tar.gz");

if (!$min && -d $zipdir) {
	# Create a .zip file too
	print "Creating webmin-$vfile.zip\n";
	system("rm -rf $zipdir/webmin");
	system("mkdir $zipdir/webmin");
	system("cp -rp $tardir/$dir/* $zipdir/webmin");
	system("rm -rf $zipdir/webmin/{fdisk,exports,bsdexports,hpuxexports,sgiexports,zones,rbac,Webmin}");
	system("rm -rf $zipdir/webmin/acl/Authen-SolarisRBAC-0.1/*");
	system("echo zip >$zipdir/webmin/install-type");
	open(FIND, "find $zipdir/webmin -name '*\\**' |");
	while(<FIND>) {
		s/\n//g;
		$orig = $_;
		($nw = $orig) =~ s/\*/ALL/g;
		if ($nw ne $orig) {
			rename($orig, $nw);
			}
		}
	close(FIND);
	unlink("$zipdir/webmin-$vfile.zip");
	system("cd $zipdir && zip -r webmin-$vfile.zip webmin >/dev/null 2>&1");
	}

if (!$min && -d "modules") {
	# Create per-module .wbm files
	print "Creating modules\n";
	opendir(DIR, "$tardir/$dir");
	while($d = readdir(DIR)) {
		# create the module.wbm file
		local $minfo = "$tardir/$dir/$d/module.info";
		next if (!-r $minfo);
		unlink("modules/$d.wbm", "modules/$d.wbm.gz");
		system("(cd $tardir/$dir ; tar chf - $d | gzip -c) >modules/$d.wbm.gz");
		}
	closedir(DIR);
	}

# Create the signature file
if (-d "sigs") {
	unlink("sigs/webmin-$vfile.tar.gz-sig.asc");
	system("gpg --armor --output sigs/webmin-$vfile.tar.gz-sig.asc --default-key jcameron\@webmin.com --detach-sig $tardir/webmin-$vfile.tar.gz");
	}

# Create a change log for this version
if (-d "/home/jcameron/webmin.com") {
	$lastvers = sprintf("%.2f0", $vers - 0.005);	# round down to last stable
	if ($lastvers == $vers) {
		# this is a new full version, so round down to the previous full version
		$lastvers = sprintf("%.2f0", $vers-0.006);
		}
	system("./showchangelog.pl --html $lastvers >/home/jcameron/webmin.com/changes-$vers.html");
	}

if ($min) {
	# Delete the tarball directory
	system("rm -rf $tardir/$dir");
	}

# read_file(file, &assoc, [&order])
# Fill an associative array with name=value pairs from a file
sub read_file
{
open(ARFILE, $_[0]) || return 0;
while(<ARFILE>) {
        chop;
        if (!/^#/ && /^([^=]+)=(.*)$/) {
		$_[1]->{$1} = $2;
		push(@{$_[2]}, $1);
        	}
        }
close(ARFILE);
return 1;
}
 
# write_file(file, array)
# Write out the contents of an associative array as name=value lines
sub write_file
{
local($arr);
$arr = $_[1];
open(ARFILE, "> $_[0]");
foreach $k (keys %$arr) {
        print ARFILE "$k=$$arr{$k}\n";
        }
close(ARFILE);
}

sub usage
{
die "usage: makedist.pl [-minimal] <version>";
}

