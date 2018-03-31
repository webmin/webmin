#!/usr/bin/perl
# setup.pl
# This script should be run after the webmin archive is unpacked, in order
# to setup the various config files

use POSIX;
use Socket;

# Find install directory
$ENV{'LANG'} = '';
$0 =~ s/\\/\//g;
if ($0 =~ /^(.*)\//) {
	chdir($1);
	}
$wadir = getcwd();
$wadir =~ s/\\/\//g;	# always use / separator on windows
$srcdir = $wadir;
open(VERSION, "$wadir/version") ||
	&errorexit("Cannot find the Webmin install directory");
chop($ver = <VERSION>);
close(VERSION);

print "***********************************************************************\n";
print "*            Welcome to the Webmin setup script, version $ver        *\n";
print "***********************************************************************\n";
print "Webmin is a web-based interface that allows Unix-like operating\n";
print "systems and common Unix services to be easily administered.\n";
print "\n";

# Only root can run this
if ($< != 0) {
	&errorexit("The Webmin install script must be run as root");
	}

# Use the supplied destination directory, if any
if ($ARGV[0]) {
	$wadir = $ARGV[0];
	$wadir =~ s/\\/\//g;	# always use / separator on windows
	print "Installing Webmin from $srcdir to $wadir ...\n";
	if (!-d $wadir) {
		mkdir($wadir, 0755) || &errorexit("Failed to create $wadir");
		}
	else {
		# Make sure dest dir is not in use
		@files = grep { !/rpmsave/ } &files_in_dir($wadir);
		if (@files && !-r "$wadir/setup.pl") {
			&errorexit("Installation directory $wadir contains other files");
			}
		}
	}
else {
	print "Installing Webmin in $wadir ...\n"
	}

# Work out perl library path
$ENV{'PERLLIB'} = $wadir;
if ($ENV{'perllib'}) {
	$ENV{'PERLLIB'} .= ":".$ENV{'perllib'};
	}

# Validate source directory
@allmods = map { s/\/module.info$//; $_ } glob("*/module.info");
if (!@allmods) {
	&errorexit("ERROR: Failed to get module list");
	}
$allmods = join(" ", @allmods);
print "\n";

chdir($wadir);

# Load package-defined variable overrides
if (-r "$srcdir/setup-pre.pl") {
	require "$srcdir/setup-pre.pl";
	}

# Ask for webmin config directory
print "***********************************************************************\n";
print "Webmin uses separate directories for configuration files and log files.\n";
print "Unless you want to run multiple versions of Webmin at the same time\n";
print "you can just accept the defaults.\n";
print "\n";
print "Config file directory [/etc/webmin]: ";
if ($ENV{'config_directory'}) {
	$config_directory = $ENV{'config_directory'};
	}
else {
	chop($config_directory = <STDIN>);
	}
$config_directory ||= "/etc/webmin";
$config_directory =~ s/\\/\//g;
if ($config_directory !~ /^([a-z]:)?\//i) {
	&errorexit("Config directory must be an absolute path");
	}
if (!-d $config_directory) {
	mkdir($config_directory, 0755) ||
		&errorexit("Failed to create directory $config_directory");
	}
if (-r "$config_directory/config") {
	print "Found existing Webmin configuration in $config_directory\n";
	print "\n";
	$upgrading=1
	}

# We can now load the main Webmin library
$ENV{'WEBMIN_CONFIG'} = $config_directory;
$ENV{'WEBMIN_VAR'} = "/var/webmin";	# not really used
require "$srcdir/web-lib-funcs.pl";

# Check if upgrading from an old version
if ($upgrading) {
	print "\n";

	# Get current var path
	open(VAR, "$config_directory/var-path");
	chop($var_dir = <VAR>);
	$var_directory = $var_dir;
	close(VAR);

	# Force creation if non-existant
	mkdir($var_dir, 0755);

	# Get current perl path
	$perl = &get_perl_path();

	# Get old os name and version
	&read_file("$config_directory/config", \%gconfig);
	$os_type = $gconfig{'os_type'};
	$os_version = $gconfig{'os_version'};
	$real_os_type = $gconfig{'real_os_type'};
	$real_os_version = $gconfig{'real_os_version'};
	&get_miniserv_config(\%miniserv);
	$oldwadir = $miniserv{'root'};
	$path_separator = $gconfig{'os_type'} eq 'windows' ? ';' : ':';
	$null_file = $gconfig{'os_type'} eq 'windows' ? "NUL" : "/dev/null";

	if (!$miniserv{'inetd'}) {
		# Stop old version
		if ($os_type eq "windows") {
			system("$config_directory/stop.bat >/dev/null 2>&1");
			}
		else {
			system("$config_directory/stop >/dev/null 2>&1");
			}
		}

	# Copy files to target directory
	&copy_to_wadir();

	# Update ACLs
	system("$perl ".&quote_path("$wadir/newmods.pl")." $config_directory $allmods");

	# Update miniserv.conf with new root directory and mime types file
	$miniserv{'root'} = $wadir;
	$miniserv{'mimetypes'} = "$wadir/mime.types";
	&put_miniserv_config(\%miniserv);

	# Check for third-party modules in old version
	if ($wadir ne $oldwadir) {
		print "Checking for third-party modules ..\n";
		if ($ENV{'webmin_upgrade"'}) {
			$autothird = 1;
			}
		system("$perl ".&quote_path("$wadir/thirdparty.pl")." ".&quote_path($wadir)." ".&quote_path($oldwadir)." $autothird");
		print "..done\n";
		print "\n";
		}

	# Remove old cache of module infos
	unlink("$config_directory/module.infos.cache");
	}
else {
	# Config directory exists .. make sure it is not in use
	@files = grep { !/rpmsave/ } &files_in_dir($config_directory);
	if (@files && $config_directory ne "/etc/webmin") {
		&errorexit("Config directory $config_directory is not empty");
		}

	# Ask for log directory
	print "Log file directory [/var/webmin]: ";
	if ($ENV{'var_dir'}) {
		$var_dir = $ENV{'var_dir'};
		}
	else {
		chop($var_dir = <STDIN>);
		}
	$var_dir ||= "/var/webmin";
	$var_dir =~ s/\\/\//g;
	$var_directory = $var_dir;
	if ($var_dir !~ /^([a-z]:)?\//i) {
		&errorexit("Log file directory must be an absolute path");
		}
	if ($var_dir eq "/" || $var_dir =~ /^[a-z]:\/$/) {
		&errorexit("Log directory cannot be /");
		}
	if (!-d $var_dir) {
		mkdir($var_dir, 0755) ||
			&errorexit("Failed to create directory $var_dir");
		}
	print "\n";

	# No need to ask where Perl is, because we already have it!
	$perl = &has_command($^X) || $^X;
	if (!-x $perl) {
		&errorexit("Failed to find Perl at $perl");
		}
	if ($] < 5.002) {
		&errorexit("Detected old perl version. Webmin requires perl 5.002 or better to run");
		}
	print "Perl seems to be installed ok\n";
	print "\n";

	# Ask for operating system type
	print "***********************************************************************\n";
	$autoos = $ENV{'autoos'} || 2;
	$temp = &tempname();
	$ex = system("$perl ".&quote_path("$srcdir/oschooser.pl")." ".&quote_path("$srcdir/os_list.txt")." $temp $autoos");
	exit($ex) if ($ex);
	&read_env_file($temp, \%osinfo);
	$os_type = $osinfo{'os_type'};
	$os_version = $osinfo{'os_version'};
	$real_os_type = $osinfo{'real_os_type'};
	$real_os_version = $osinfo{'real_os_version'};
	$gconfig{'os_type'} = $os_type;
	$gconfig{'os_version'} = $os_version;
	$gconfig{'real_os_type'} = $real_os_type;
	$gconfig{'real_os_version'} = $real_os_version;
	$path_separator = $gconfig{'os_type'} eq 'windows' ? ';' : ':';
	$null_file = $gconfig{'os_type'} eq 'windows' ? "NUL" : "/dev/null";
	unlink($temp);
	print "Operating system name:    $real_os_type\n";
	print "Operating system version: $real_os_version\n";
	print "\n";

	if ($os_type eq "windows") {
		# Check Windows dependencies
		if (!&has_command("process.exe")) {
			&errorexit("The command process.exe must be installed to run Webmin on Windows");
			}
		eval "use Win32::Daemon";
		if ($@) {
			&errorexit("The Perl module Win32::Daemon must be installed to run Webmin on Windows");
			}
		}

	# Ask for web server port, name and password
	print "***********************************************************************\n";
	print "Webmin uses its own password protected web server to provide access\n";
	print "to the administration programs. The setup script needs to know :\n";
	print " - What port to run the web server on. There must not be another\n";
	print "   web server already using this port.\n";
	print " - The login name required to access the web server.\n";
	print " - The password required to access the web server.\n";
	print " - If the webserver should use SSL (if your system supports it).\n";
	print " - Whether to start webmin at boot time.\n";
	print "\n";
	print "Web server port (default 10000): ";
	if ($ENV{'port'}) {
		$port = $ENV{'port'};
		}
	else {
		chop($port = <STDIN>);
		}
	$port ||= 10000;
	if ($port < 1 || $port > 65535) {
		&errorexit("$port is not a valid port number");
		}
	socket(FOO, PF_INET, SOCK_STREAM, getprotobyname("tcp"));
	setsockopt(FOO, SOL_SOCKET, SO_REUSEADDR, pack("l", 1));
	bind(FOO, pack_sockaddr_in($port, INADDR_ANY)) ||
		&errorexit("TCP port $port is already in use by another program");
	close(FOO);

	print "Login name (default admin): ";
	if ($ENV{'login'}) {
		$login = $ENV{'login'};
		}
	else {
		chop($login = <STDIN>);
		}
	$login ||= "admin";
	if ($login =~ /:/) {
		&errorexit("Username contains a : character");
		}
	if ($login =~ /\s/) {
		&errorexit("Username contains a space");
		}
	if ($login eq "webmin") {
		&errorexit("Username 'webmin' is reserved for internal use");
		}
	print "Login password: ";
	if ($ENV{'password'}) {
		$password = $ENV{'password'};
		}
	elsif ($ENV{'crypt'}) {
		$crypt = $ENV{'crypt'};
		}
	else {
		chop($password = <STDIN>);
		print "Password again: ";
		chop($password2 = <STDIN>);
		if ($password ne $password2) {
			&errorexit("Passwords don't match");
			}
		if ($password =~ /:/) {
			&errorexit("Password contains a : character");
			}
		}

	# Ask the user if SSL should be used
	if ($ENV{'ssl'} ne '') {
		$ssl = $ENV{'ssl'};
		}
	else {
		$ssl = 0;
		eval "use Net::SSLeay";
		if (!$@) {
			print "Use SSL (y/n): ";
			chop($sslyn = <STDIN>);
			if ($sslyn =~ /^y/i) {
				$ssl = 1;
				}
			}
		else {
			print "The Perl SSLeay library is not installed. SSL not available.\n"
			}
		}

	# Don't use SSL if missing Net::SSLeay
	if ($ssl) {
		eval "use Net::SSLeay";
		if ($@) {
			$ssl = 0;
			}
		}

	# Ask whether to run at boot time
	if ($ENV{'atboot'}) {
		$atboot = $ENV{'atboot'};
		}
	else {
		$atboot = 0;
		print "Start Webmin at boot time (y/n): ";
		chop($atbootyn = <STDIN>);
		if ($atbootyn =~ /^y/i) {
			$atboot = 1;
			}
		}
	$makeboot = $atboot;

	# Copy files to target directory
	print "***********************************************************************\n";
	&copy_to_wadir();

	# Create webserver config file
	open(PERL, ">$config_directory/perl-path");
	print PERL $perl,"\n";
	close(PERL);
	open(VAR, ">$config_directory/var-path");
	print VAR $var_dir,"\n";
	close(VAR);

	print "Creating web server config files..";
	$ufile = "$config_directory/miniserv.users";
	$kfile = "$config_directory/miniserv.pem";
	%miniserv = (	'port' => $port,
		    	'root' => $wadir,
			'mimetypes' => "$wadir/mime.types",
			'addtype_cgi' => 'internal/cgi',
			'realm' => 'Webmin Server',
			'logfile' => "$var_dir/miniserv.log",
			'errorlog' => "$var_dir/miniserv.error",
			'pidfile' => "$var_dir/miniserv.pid",
			'logtime' => 168,
			'ppath' => $ppath,
			'ssl' => $ssl,
			'no_ssl2' => 1,
			'no_ssl3' => 1,
			'no_tls1' => 1,
			'no_tls1_1' => 1,
			'env_WEBMIN_CONFIG' => $config_directory,
			'env_WEBMIN_VAR' => $var_dir,
			'atboot' => $atboot,
			'logout' => "$config_directory/logout-flag",
			'listen' => 10000,
			'denyfile' => "\\.pl\$",
			'log' => 1,
			'blockhost_failures' => 5,
			'blockhost_time' => 60,
			'syslog' => $os_type eq 'windows' ? 0 : 1,
			'userfile' => $ufile,
			'keyfile' => $kfile,
			'preload' => 'main=web-lib-funcs.pl',
			 );
	if ($ENV{'allow'}) {
		$miniserv{'allow'} = $ENV{'allow'};
		}
	if ($ENV{'session'} eq '') {
		$miniserv{'session'} = $os_type eq 'windows' ? 0 : 1;
		}
	else {
		$miniserv{'session'} = $ENV{'session'};
		}
	if ($os_type eq 'windows') {
		$miniserv{'no_pam'} = 1;
		}
	elsif ($ENV{'pam'}) {
		$miniserv{'pam'} = $ENV{'pam'};
		}
	if ($os_type eq 'windows') {
		$miniserv{'nofork'} = 1;
		$miniserv{'restartflag'} = "$var_dir/restart.flag";
		$miniserv{'reloadflag'} = "$var_dir/reload.flag";
		$miniserv{'forkcgis'} = 1;	# Avoid memory leaks
		}
	&put_miniserv_config(\%miniserv);

	# Test MD5 password encryption
	if (&unix_crypt("test", "\\$1\\$A9wB3O18\\$zaZgqrEmb9VNltWTL454R/") eq "\\$1\\$A9wB3O18\\$zaZgqrEmb9VNltWTL454R/") {
		$md5pass = 1;
		}

	# Create users file
	open(UFILE, ">$ufile");
	if ($crypt) {
		print UFILE "$login:$crypt:0\n";
		}
	elsif ($md5pass) {
		print UFILE $login,":",&unix_crypt($password, "\$1\$XXXXXXXX"),"\n";
		}
	else {
		print UFILE $login,":",&unix_crypt($password, "XX"),"\n";
		}
	close(UFILE);
	chmod(0600, $ufile);

	# Generate cert
	if (system("openssl version >/dev/null 2>&1") == 0) {
		# We can generate a new SSL key for this host
		$host = &get_system_hostname();
		$cert = &tempname();
		$key = &tempname();
		open(SSL, "| openssl req -newkey rsa:512 -x509 -nodes -out $cert -keyout $key -days 1825 >/dev/null 2>&1");
		print SSL ".\n";
		print SSL ".\n";
		print SSL ".\n";
		print SSL "Webmin Webserver on $host\n";
		print SSL ".\n";
		print SSL "*\n";
		print SSL "root\@$host\n";
		$ok = close(SSL);
		if (!$?) {
			open(CERTIN, $cert);
			open(KEYIN, $key);
			open(OUT, ">$kfile");
			while(<CERTIN>) {
				print OUT $_;
				}
			while(<KEYIN>) {
				print OUT $_;
				}
			close(CERTIN);
			close(KEYIN);
			close(OUT);
			}
		unlink($cert, $key);
		}
	if (!-r $kfile) {
		# Fall back to the built-in key
		&copy_source_dest("$wadir/miniserv.pem", $kfile);
		}
	chmod(0600, $kfile);
	print "..done\n";
	print "\n";

	print "Creating access control file..\n";
	$afile = "$config_directory/webmin.acl";
	open(AFILE, ">$afile");
	if ($ENV{'defaultmods'}) {
		print AFILE "$login: $ENV{'defaultmods'}\n";
		}
	else {
		print AFILE "$login: $allmods\n";
		}
	close(AFILE);
	chmod(0600, $afile);
	print "..done\n";
	print "\n";

	if ($login ne "root" && $login ne "admin") {
		# Allow use of RPC by this user
		open(ACL, ">$config_directory/$login.acl");
		print ACL "rpc=1\n";
		close(ACL);
		}
	}

if (!$ENV{'noperlpath"'} && $os_type ne 'windows') {
	print "Inserting path to perl into scripts..\n";
	system("(find ".&quote_path($wadir)." -name '*.cgi' -print ; find ".&quote_path($wadir)." -name '*.pl' -print) | $perl ".&quote_path("$wadir/perlpath.pl")." $perl -");
	print "..done\n";
        print "\n";
	}

print "Creating start and stop scripts..\n";
if ($os_type eq "windows") {
	open(START, ">>$config_directory/start.bat");
	print START "$perl \"$wadir/miniserv.pl\" $config_directory/miniserv.conf\n";
	close(START);
	$start_cmd = "sc start ".($ENV{'bootscript'} || "webmin");

	open(STOP, ">>$config_directory/stop.bat");
	print STOP "echo Not implemented\n";
	close(STOP);
	}
else {
	open(START, ">$config_directory/start");
	print START "#!/bin/sh\n";
	print START "echo Starting Webmin server in $wadir\n";
	print START "trap '' 1\n";
	print START "LANG=\n";
	print START "export LANG\n";
	print START "unset PERLIO\n";
	print START "export PERLIO\n";
	print START "PERLLIB=$perllib\n";
	print START "export PERLLIB\n";
	if ($os_type eq "hpux") {
		print START "exec '$wadir/miniserv.pl' $config_directory/miniserv.conf &\n";
		}
	else {
		print START "exec '$wadir/miniserv.pl' $config_directory/miniserv.conf\n";
		}
	close(START);
	$start_cmd = "$config_directory/start";

	open(STOP, ">$config_directory/stop");
	print STOP "#!/bin/sh\n";
	print STOP "echo Stopping Webmin server in $wadir\n";
	print STOP "pidfile=\`grep \"^pidfile=\" $config_directory/miniserv.conf | sed -e 's/pidfile=//g'\`\n";
	print STOP "kill \`cat \$pidfile\`\n";
	close(STOP);

	open(RESTART, ">$config_directory/restart");
	print RESTART "#!/bin/sh\n";
	print RESTART "$config_directory/stop && $config_directory/start\n";
	close(RESTART);

	chmod(0755, "$config_directory/start", "$config_directory/stop",
		    "$config_directory/restart");
	}
print "..done\n";
print "\n";

if ($upgrading) {
	print "Updating config files..\n";
	}
else {
	print "Copying config files..\n";
	}
system("$perl ".&quote_path("$wadir/copyconfig.pl")." ".&quote_path("$os_type/$real_os_type")." ".&quote_path("$os_version/$real_os_version")." ".&quote_path($wadir)." ".$config_directory." \"\" ".$allmods);
if (!$upgrading) {
	# Store the OS and version
	&read_file("$config_directory/config", \%gconfig);
	$gconfig{'os_type'} = $os_type;
	$gconfig{'os_version'} = $os_version;
	$gconfig{'real_os_type'} = $real_os_type;
	$gconfig{'real_os_version'} = $real_os_version;
	$gconfig{'log'} = 1;
	&write_file("$config_directory/config", \%gconfig);
	}
open(VER, ">$config_directory/version");
print VER $ver,"\n";
close(VER);
print "..done\n";
print "\n";

# Set passwd_ fields in miniserv.conf from global config
&get_miniserv_config(\%miniserv);
foreach $field ("passwd_file", "passwd_uindex", "passwd_pindex", "passwd_cindex", "passwd_mindex") {
	if ($gconfig{$field}) {
		$miniserv{$field} = $gconfig{$field};
		}
	}
if (!defined($miniserv{'passwd_mode'})) {
	$miniserv{'passwd_mode'} = 0;
	}

# If Perl crypt supports MD5, then make it the default
if ($md5pass) {
	$gconfig{'md5pass'} = 1;
	}

# Set a special theme if none was set before
if ($ENV{'theme'}) {
	$theme = $ENV{'theme'};
	}
elsif (open(THEME, "$wadir/defaulttheme")) {
	chop($theme = <THEME>);
	close(THEME);
	}
if ($theme && -d "$wadir/$theme") {
	$gconfig{'theme'} = $theme;
	$miniserv{'preroot'} = $theme;
	}

# Set the product field in the global config
$gconfig{'product'} ||= "webmin";

if ($makeboot) {
	print "Configuring Webmin to start at boot time..\n";
	chdir("$wadir/init");
	system("$perl ".&quote_path("$wadir/init/atboot.pl")." ".$ENV{'bootscript'});
	print "..done\n";
	print "\n";
	}


# If password delays are not specifically disabled, enable them
if (!defined($miniserv{'passdelay'}) && $os_type ne 'windows') {
	$miniserv{'passdelay'} = 1;
	}

# Save configs
&put_miniserv_config(\%miniserv);
&write_file("$config_directory/config", \%gconfig);

if (!$ENV{'nouninstall'} && $os_type ne "windows") {
	print "Creating uninstall script $config_directory/uninstall.sh ..\n";
	open(UN, ">$config_directory/uninstall.sh");
	print UN <<EOF;
#!/bin/sh
printf "Are you sure you want to uninstall Webmin? (y/n) : "
read answer
printf "\n"
if [ "\$answer" = "y" ]; then
	$config_directory/stop
	echo "Running uninstall scripts .."
	(cd "$wadir" ; WEBMIN_CONFIG=$config_directory WEBMIN_VAR=$var_dir LANG= "$wadir/run-uninstalls.pl")
	echo "Deleting $wadir .."
	rm -rf "$wadir"
	echo "Deleting $config_directory .."
	rm -rf "$config_directory"
	echo "Done!"
fi
EOF
	chmod(0755, "$config_directory/uninstall.sh");
	print "..done\n";
	print "\n";
	}

if ($os_type ne "windows") {
	print "Changing ownership and permissions ..\n";
	system("chown -R root $config_directory");
	system("chgrp -R bin $config_directory");
	system("chmod -R og-rw $config_directory");
	system("chmod 755 $config_directory/{sendmail,qmailadmin,postfix}*/config >/dev/null 2>&1");
	system("chmod 755 $config_directory/{sendmail,qmailadmin,postfix}*/autoreply.pl >/dev/null 2>&1");
	system("chmod 755 $config_directory/{sendmail,qmailadmin,postfix}*/filter.pl >/dev/null 2>&1");
	system("chmod 755 $config_directory/squid*/squid-auth.pl >/dev/null 2>&1");
	system("chmod 755 $config_directory/squid*/users >/dev/null 2>&1");
	system("chmod 755 $config_directory/cron*/range.pl >/dev/null 2>&1");
	system("chmod +r $config_directory/version");
	if (!$ENV{'nochown'}) {
		system("chown -R root \"$wadir\"");
		system("chgrp -R bin \"$wadir\"");
		system("chmod -R og-w \"$wadir\"");
		system("chmod -R a+rx \"$wadir\"");
		}
	if ($var_dir ne "/var") {
		system("chown -R root $var_dir");
		system("chgrp -R bin $var_dir");
		system("chmod -R og-rwx $var_dir");
		}
	print "..done\n";
        print "\n";
	}

# Save target directory if one was specified
if ($wadir ne $srcdir) {
	open(INSTALL, ">$config_directory/install-dir");
	print INSTALL $wadir,"\n";
	close(INSTALL);
	}
else {
	unlink("$config_directory/install-dir");
	}

if (!$ENV{'nopostinstall'}) {
	print "Running postinstall scripts ..\n";
	chdir($wadir);
	system("$perl ".&quote_path("$wadir/run-postinstalls.pl"));
	print "..done\n";
	print "\n";
	}

# Run package-defined post-install script
if (-r "$srcdir/setup-post.pl") {
	require "$srcdir/setup-post.pl";
	}

if (!$ENV{'nostart'}) {
	if (!$miniserv{'inetd'}) {
		print "Attempting to start Webmin mini web server..\n";
		$ex = system($start_cmd);
		if ($ex) {
			&errorexit("Failed to start web server!");
			}
		print "..done\n";
		print "\n";
		}

	print "***********************************************************************\n";
	print "Webmin has been installed and started successfully. Use your web\n";
	print "browser to go to\n";
	print "\n";
	$host = &get_system_hostname();
	if ($ssl) {
		print "  https://$host:$miniserv{'port'}/\n";
		}
	else {
		print "  http://$host:$miniserv{'port'}/\n";
		}
	print "\n";
	print "and login with the name and password you entered previously.\n";
	print "\n";
	if ($ssl) {
		print "Because Webmin uses SSL for encryption only, the certificate\n";
		print "it uses is not signed by one of the recognized CAs such as\n";
		print "Verisign. When you first connect to the Webmin server, your\n";
		print "browser will ask you if you want to accept the certificate\n";
		print "presented, as it does not recognize the CA. Say yes.\n";
		print "\n";
		}
	}

if ($oldwadir ne $wadir && $upgrading && !$ENV{'deletedold'}) {
	print "The directory from the previous version of Webmin\n";
	print "   $oldwadir\n";
	print "Can now be safely deleted to free up disk space, assuming\n";
	print "that all third-party modules have been copied to the new\n";
	print "version.\n";
	print "\n";
	}

sub errorexit
{
print "ERROR: ",@_,"\n";
print "\n";
exit(1);
}

sub copy_to_wadir
{
if ($wadir ne $srcdir) {
	print "Copying files to $wadir ..\n";
	if (&has_command("tar")) {
		# Unix tar exists
		system("cd ".&quote_path($srcdir)." && tar cf - . | (cd ".&quote_path($wadir)." ; tar xf -)");
		}
	else {
		# Looks like Windows .. use xcopy command
		system("xcopy \"$srcdir\" \"$wadir\" /Y /E /I /Q");
		}
	print "..done\n";
	print "\n";
	}
}

sub files_in_dir
{
opendir(DIR, $_[0]);
local @rv = grep { $_ ne "." && $_ ne ".." } readdir(DIR);
closedir(DIR);
return @rv;
}

