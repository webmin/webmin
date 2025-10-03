#!/usr/bin/perl
# setup.pl
# This script should be run after the webmin archive is unpacked, in order
# to setup the various config files

use POSIX;
use Socket;

# Find install directory
$ENV{'LANG'} = '';
$0 =~ s/\\/\//g;
$bootscript = $ENV{'bootscript'} || "webmin";
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
my $spaces_count_def = 12;
my $verleneach = int(length($ver) / 2);
my $space_count = int($spaces_count_def - $verleneach);
my $space_count_cond = " " x $space_count;
print "****************************************************************************\n";
print "* $space_count_cond Welcome to the Webmin setup script, version $ver $space_count_cond  *\n";
print "****************************************************************************\n";
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
	print "Installing Webmin from $srcdir to $wadir\n";
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
	print "Installing Webmin in $wadir\n"
	}

# Work out perl library path
$ENV{'PERLLIB'} = $wadir;
$ENV{'WEBMIN_LIBDIR'} = $wadir;
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
print "****************************************************************************\n";
print "Webmin uses separate directories for configuration files and log files.\n";
print "Unless you want to run multiple versions of Webmin at the same time\n";
print "you can just accept the defaults.\n";
print "\n";
my $envetcdir = $ENV{'config_directory'} || "/etc/webmin";
print "Config file directory [$envetcdir]: ";
if ($ENV{'config_directory'}) {
	$config_directory = $ENV{'config_directory'};
	print "$envetcdir\n";
	print ".. predefined\n";
	$envetcdirexists = 1;
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
	make_dir_recursive_local($config_directory, 0755) ||
		&errorexit("Failed to create directory $config_directory");
	}
if (-r "$config_directory/config") {
	print ".. found\n" if (!$envetcdirexists);
	$upgrading = 1;
	}

# We can now load the main Webmin library
$ENV{'WEBMIN_CONFIG'} = $config_directory;
$ENV{'WEBMIN_VAR'} = "/var/webmin";	# Only used for initial load of web-lib
require "$srcdir/web-lib-funcs.pl";

# Do we need to reload instead
# Can be deleted with Webmin 2.0
$killmodenonepl = 0;

# Check if upgrading from an old version
if ($upgrading) {
	print "\n";

	# Get current var path
	open(VAR, "$config_directory/var-path");
	chop($var_dir = <VAR>);
	$var_directory = $var_dir;
	$ENV{'WEBMIN_VAR'} = $var_directory;
	close(VAR);

	# Get current bootscript name
	if (-r "$config_directory/bootscript-name") {
		open(BOOTVAR, "$config_directory/bootscript-name");
		chop($newbootscript = <BOOTVAR>);
		close(BOOTVAR);
		$bootscript = $newbootscript if ($newbootscript);
		}

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
			if (-r "$config_directory/.pre-install") {
				system("$config_directory/.pre-install >/dev/null 2>&1");
				}
			else {
				$killmodenonepl = 1;
				}
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
		print ".. done\n";
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
	my $envvardir = $ENV{'var_dir'} || "/var/webmin";
	print "Log file directory [$envvardir]: ";
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
		make_dir_recursive_local($var_dir, 0755) ||
			&errorexit("Failed to create directory $var_dir");
		}
	$ENV{'WEBMIN_VAR'} = $var_dir;
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
	print "****************************************************************************\n";
	$autoos = $ENV{'autoos'} || 2;
	$temp = &tempname();
	$ex = system("$perl ".&quote_path("$srcdir/oschooser.pl")." ".&quote_path("$srcdir/os_list.txt")." ".&quote_path($temp)." $autoos");
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
		if (!eval "use Win32::Daemon; 1") {
			&errorexit("The Perl module Win32::Daemon must be installed to run Webmin on Windows");
			}
		}

	# Ask for web server port, name and password
	print "****************************************************************************\n";
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
		system("stty -echo");
		chop($password = <STDIN>);
		system("stty echo");
		print "\nPassword again: ";
		system("stty -echo");
		chop($password2 = <STDIN>);
		system("stty echo");
		print "\n";
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
	print "****************************************************************************\n";
	&copy_to_wadir();

	# Create webserver config file
	open(PERL, ">$config_directory/perl-path");
	print PERL $perl,"\n";
	close(PERL);
	open(VAR, ">$config_directory/var-path");
	print VAR $var_dir,"\n";
	close(VAR);
	open(BOOTS, ">$config_directory/bootscript-name");
	print BOOTS $bootscript,"\n";
	close(BOOTS);

	print "Creating web server config files ..\n";
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
			'logclear' => 1,
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

	# Test available hashing formats
	if (&unix_crypt('test', '$y$j9T$waHytoaqP/CEnKFroGn0S/$fxd5mVc2mBPUc3vv.cpqDckpwrWTyIm2iD4JfnVBi26') eq '$y$j9T$waHytoaqP/CEnKFroGn0S/$fxd5mVc2mBPUc3vv.cpqDckpwrWTyIm2iD4JfnVBi26') {
		$yescryptpass = 1;
		}
	if (&unix_crypt('test', '$6$Tk5o/GEE$zjvXhYf/dr5M7/jan3pgunkNrAsKmQO9r5O8sr/Cr1hFOLkWmsH4iE9hhqdmHwXd5Pzm4ubBWTEjtMeC.h5qv1') eq '$6$Tk5o/GEE$zjvXhYf/dr5M7/jan3pgunkNrAsKmQO9r5O8sr/Cr1hFOLkWmsH4iE9hhqdmHwXd5Pzm4ubBWTEjtMeC.h5qv1') {
		$sha512pass = 1;
		}
	if (&unix_crypt('test', '$1$A9wB3O18$zaZgqrEmb9VNltWTL454R/') eq '$1$A9wB3O18$zaZgqrEmb9VNltWTL454R/') {
		$md5pass = 1;
		}

	# Generate random
	@saltbase = ('a'..'z', 'A'..'Z', '0'..'9');
	$salt8 = join('', map ($saltbase[rand(@saltbase)], 1..8));
	$salt2 = join('', map ($saltbase[rand(@saltbase)], 1..2));

	# Create users file
	open(UFILE, ">$ufile");
	if ($crypt) {
		print UFILE "$login:$crypt:0\n";
		}
	elsif ($yescryptpass) {
		print UFILE $login,":",&unix_crypt($password, "\$y\$j9T\$$salt8"),"\n";
		}
	elsif ($sha512pass) {
		print UFILE $login,":",&unix_crypt($password, "\$6\$$salt8"),"\n";
		}
	elsif ($md5pass) {
		print UFILE $login,":",&unix_crypt($password, "\$1\$$salt8"),"\n";
		}
	else {
		print UFILE $login,":",&unix_crypt($password, $salt2),"\n";
		}
	close(UFILE);
	chmod(0600, $ufile);

	# Generate cert
	if (system("openssl version >/dev/null 2>&1") == 0) {
		# We can generate a new SSL key for this host
		$host = &get_system_hostname();
		$cert = &tempname();
		$key = &tempname();
		$addtextsup = &get_openssl_version() >= 1.1 ? "-addext subjectAltName=DNS:$host,DNS:localhost -addext extendedKeyUsage=serverAuth" : "";
		open(SSL, "| openssl req -newkey rsa:2048 -x509 -nodes -out $cert -keyout $key -days 1825 -sha256 -subj '/CN=$host/C=US/L=Santa Clara' $addtextsup >/dev/null 2>&1");
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
	print ".. done\n";
	print "\n";

	print "Creating access control file ..\n";
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
	print ".. done\n";
	print "\n";

	if ($login ne "root" && $login ne "admin") {
		# Allow use of RPC by this user
		open(ACL, ">$config_directory/$login.acl");
		print ACL "rpc=1\n";
		close(ACL);
		}
	}

if (!$ENV{'noperlpath"'} && $os_type ne 'windows') {
	print "Inserting path to perl into scripts ..\n";
	system("(find ".&quote_path($wadir)." -name '*.cgi' -print ; find ".&quote_path($wadir)." -name '*.pl' -print) | $perl ".&quote_path("$wadir/perlpath.pl")." $perl -");
	print ".. done\n";
        print "\n";
	}
my $systemctlcmd = &has_command('systemctl');
if (-x $systemctlcmd) {
	my $initsys = &trim(&backquote_command("cat /proc/1/comm 2>/dev/null"));
	if ($initsys ne 'systemd') {
		$systemctlcmd = undef;
		}
	}
print "Creating start and stop scripts ..\n";
if ($os_type eq "windows") {
	open(START, ">>$config_directory/start.bat");
	print START "$perl \"$wadir/miniserv.pl\" $config_directory/miniserv.conf\n";
	close(START);
	$start_cmd = "sc start $bootscript";

	open(STOP, ">>$config_directory/stop.bat");
	print STOP "echo Not implemented\n";
	close(STOP);
	}
else {
	
	# Re-generating main scripts
	
	# Start main
	open(START, ">$config_directory/.start-init");
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

	# Define final start command
	if ($upgrading) {
		if ($killmodenonepl == 1) {
			$start_cmd = "$config_directory/.reload-init >/dev/null 2>&1 </dev/null";
			}
		else {
			$start_cmd = "$config_directory/.post-install >/dev/null 2>&1 </dev/null";
			}
		}
	else {
		$start_cmd = "$config_directory/start >/dev/null 2>&1 </dev/null";
		}

	# Stop main
	open(STOP, ">$config_directory/.stop-init");
	print STOP "#!/bin/sh\n";
	print STOP "if [ \"\$1\" = \"--kill\" ]; then\n";
	print STOP "  echo Force stopping Webmin server in $wadir\n";
	print STOP "else\n";
	print STOP "  echo Stopping Webmin server in $wadir\n";
	print STOP "fi\n";
	print STOP "targets=\"stats.pl shellserver.pl\"\n";
	print STOP "collect_pids() {\n";
	print STOP "  for s in \$targets; do\n";
	print STOP "    ps axww | grep \"$wadir/\" | grep \"/\$s\" | grep -v grep\n";
	print STOP "  done | awk '{print \$1}' | sort -u\n";
	print STOP "}\n";
	print STOP "pids=\$(collect_pids)\n";
	print STOP "[ -n \"\$pids\" ] && kill \$pids 2>/dev/null || true\n";
	print STOP "if [ \"\$1\" = \"--kill\" ]; then\n";
	print STOP "  sleep 1\n";
	print STOP "  pids=\$(collect_pids)\n";
	print STOP "  [ -n \"\$pids\" ] && kill -KILL \$pids 2>/dev/null || true\n";
	print STOP "fi\n";
	print STOP "pidfile=\`grep \"^pidfile=\" $config_directory/miniserv.conf | sed -e 's/pidfile=//g'\`\n";
	print STOP "pid=\`cat \$pidfile 2>/dev/null\`\n";
	print STOP "if [ \"\$pid\" != \"\" ]; then\n";
	print STOP "  kill \$pid || exit 1\n";
	print STOP "  touch $var_dir/stop-flag\n";
	print STOP "  if [ \"\$1\" = \"--kill\" ]; then\n";
	print STOP "    sleep 1\n";
	print STOP "    (ps axf | grep \"$wadir\\\/miniserv\\.pl\" | awk '{print \"kill -9 -- -\" \$1}' | bash ; kill -9 -- -\$pid ; kill -9 \$pid) 2>/dev/null\n";
	print STOP "  fi\n";
	print STOP "  exit 0\n";
	print STOP "else\n";
	print STOP "  if [ \"\$1\" = \"--kill\" ]; then\n";
	print STOP "    (ps axf | grep \"$wadir\\\/miniserv\\.pl\" | awk '{print \"kill -9 -- -\" \$1}' | bash ; kill -9 -- -\$pid ; kill -9 \$pid) 2>/dev/null\n";
	print STOP "  fi\n";
	print STOP "fi\n";
	close(STOP);

	# Restart main
	open(RESTART, ">$config_directory/.restart-init");
	print RESTART "#!/bin/sh\n";
	print RESTART "$config_directory/.stop-init\n";
	print RESTART "$config_directory/.start-init\n";
	close(RESTART);
	
	# Force reload main
	open(FRELOAD, ">$config_directory/.restart-by-force-kill-init");
	print FRELOAD "#!/bin/sh\n";
	print FRELOAD "$config_directory/.stop-init --kill\n";
	print FRELOAD "$config_directory/.start-init\n";
	close(FRELOAD);

	# Reload main
	open(RELOAD, ">$config_directory/.reload-init");
	print RELOAD "#!/bin/sh\n";
	print RELOAD "echo Reloading Webmin server in $wadir\n";
	print RELOAD "pidfile=\`grep \"^pidfile=\" $config_directory/miniserv.conf | sed -e 's/pidfile=//g'\`\n";
	print RELOAD "kill -USR1 \`cat \$pidfile\`\n";
	close(RELOAD);

	# Switch to systemd from init (intermediate)
	if ($killmodenonepl == 1 && -x $systemctlcmd) {
		if ($ver < 1.994) {
			open(SDRELOAD, ">$config_directory/.reload-init-systemd");
			print SDRELOAD "#!/bin/sh\n";
			print SDRELOAD "$config_directory/.stop-init\n";
			print SDRELOAD "$config_directory/start\n";
			close(SDRELOAD);
			chmod(0755, "$config_directory/.reload-init-systemd");
			}
		}

	# Pre install
	open(PREINST, ">$config_directory/.pre-install");
	print PREINST "#!/bin/sh\n";
	print PREINST "$config_directory/.stop-init\n";
	close(PREINST);

	# # Post install
	open(POSTINST, ">$config_directory/.post-install");
	print POSTINST "#!/bin/sh\n";
	print POSTINST "$config_directory/.start-init\n";
	close(POSTINST);

	chmod(0755, "$config_directory/.start-init");
	chmod(0755, "$config_directory/.stop-init");
	chmod(0755, "$config_directory/.restart-init");
	chmod(0755, "$config_directory/.restart-by-force-kill-init");
	chmod(0755, "$config_directory/.reload-init");
	chmod(0755, "$config_directory/.pre-install");
	chmod(0755, "$config_directory/.post-install");

	# Re-generating supplementary

	# Clear existing
	unlink("$config_directory/start");
	unlink("$config_directory/stop");
	unlink("$config_directory/restart");
	unlink("$config_directory/restart-by-force-kill");
	unlink("$config_directory/reload");

	# Create symlinks
	# Start init.d
	symlink("$config_directory/.start-init", "$config_directory/start");
	# Stop init.d
	symlink("$config_directory/.stop-init", "$config_directory/stop");
	# Restart init.d
	symlink("$config_directory/.restart-init", "$config_directory/restart");
	# Force reload init.d
	symlink("$config_directory/.restart-by-force-kill-init", "$config_directory/restart-by-force-kill");
	# Reload init.d
	symlink("$config_directory/.reload-init", "$config_directory/reload");

	# For systemd
	my $perl = &get_perl_path();
	if (-x $systemctlcmd) {

		# Clear existing
		unlink("$config_directory/start");
		unlink("$config_directory/stop");
		unlink("$config_directory/restart");
		unlink("$config_directory/restart-by-force-kill");
		unlink("$config_directory/reload");
		
		# Start systemd
		open(STARTD, ">$config_directory/start");
		print STARTD "$systemctlcmd start $bootscript\n";
		close(STARTD);
		
		# Stop systemd
		open(STOPD, ">$config_directory/stop");
		print STOPD "$systemctlcmd stop $bootscript\n";
		close(STOPD);

		# Restart systemd
		open(RESTARTD, ">$config_directory/restart");
		print RESTARTD "$systemctlcmd restart $bootscript\n";
		close(RESTARTD);

		# Force reload systemd
		open(FRELOADD, ">$config_directory/restart-by-force-kill");
		print FRELOADD "$systemctlcmd stop $bootscript\n";
		print FRELOADD "$config_directory/.stop-init --kill >/dev/null 2>&1\n";
		print FRELOADD "$systemctlcmd start $bootscript\n";
		close(FRELOADD);

		# Reload systemd
		open(RELOADD, ">$config_directory/reload");
		print RELOADD "$systemctlcmd reload $bootscript\n";
		close(RELOADD);

		# Pre install
		open(PREINSTT, ">$config_directory/.pre-install");
		print PREINSTT "#!/bin/sh\n";
		#print PREINSTT "$systemctlcmd kill --signal=SIGSTOP --kill-who=main $bootscript\n";
		close(PREINSTT);

		# Post install
		open(POSTINSTT, ">$config_directory/.post-install");
		print POSTINSTT "#!/bin/sh\n";
		#print POSTINSTT "$systemctlcmd kill --signal=SIGCONT --kill-who=main $bootscript\n";
		print POSTINSTT "$systemctlcmd kill --signal=SIGHUP --kill-who=main $bootscript\n";
		close(POSTINSTT);

		chmod(0755, "$config_directory/start");
		chmod(0755, "$config_directory/stop");
		chmod(0755, "$config_directory/restart");
		chmod(0755, "$config_directory/restart-by-force-kill");
		chmod(0755, "$config_directory/reload");
		chmod(0755, "$config_directory/.pre-install");
		chmod(0755, "$config_directory/.post-install");
		}
}
print ".. done\n";
print "\n";

if ($upgrading) {
	print "Updating config files ..\n";
	}
else {
	print "Copying config files ..\n";
	}
system("$perl ".&quote_path("$wadir/copyconfig.pl")." ".&quote_path("$os_type/$real_os_type")." ".&quote_path("$os_version/$real_os_version")." ".&quote_path($wadir)." ".$config_directory." \"\" ".$allmods . " >/dev/null 2>&1");
if (!$upgrading) {
	# Store the OS and version, and enable log and log clearing
	&read_file("$config_directory/config", \%gconfig);
	$gconfig{'os_type'} = $os_type;
	$gconfig{'os_version'} = $os_version;
	$gconfig{'real_os_type'} = $real_os_type;
	$gconfig{'real_os_version'} = $real_os_version;
	$gconfig{'logclear'} = 1;
	$gconfig{'log'} = 1;
	&write_file("$config_directory/config", \%gconfig);
	}
open(VER, ">$config_directory/version");
print VER $ver,"\n";
close(VER);
print ".. done\n";
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

# Use system default for password hashing
$gconfig{'md5pass'} = 0;

# Set a special theme if none was set before
if ($ENV{'theme'}) {
	$theme = $ENV{'theme'};
	}
elsif (open(THEME, "$wadir/defaulttheme")) {
	chop($theme = <THEME>);
	close(THEME);
	# If no default theme found fall back to Framed Theme
	if ($theme && ! -d "$wadir/$theme") {
		$gconfig{'theme'} = "gray-theme";
		$miniserv{'preroot'} = "gray-theme";
		}
	}
if ($theme && -d "$wadir/$theme") {
	$gconfig{'theme'} = $theme;
	$miniserv{'preroot'} = $theme;
	}

# Set the product field in the global config
$gconfig{'product'} ||= "webmin";

# Add boot script if needed
if ($makeboot) {
	print "Configuring Webmin to start at boot time ..\n";
	chdir("$wadir/init");
	system("$perl ".&quote_path("$wadir/init/atboot.pl")." $bootscript");
	print ".. done\n";
	print "\n";
	}

# Update boot script if needed
chdir("$wadir/init");
system("$perl ".&quote_path("$wadir/init/updateboot.pl")." $bootscript");

# If password delays are not specifically disabled, enable them
if (!defined($miniserv{'passdelay'}) && $os_type ne 'windows') {
	$miniserv{'passdelay'} = 1;
	}

# Turn on referer checks
if (!defined($gconfig{'referers_none'})) {
	$gconfig{'referers_none'} = 1;
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
	(cd "$wadir" ; WEBMIN_CONFIG=$config_directory WEBMIN_VAR=$var_dir LANG= "$wadir/run-uninstalls.pl") >/dev/null 2>&1 </dev/null
	echo "Deleting $wadir .."
	rm -rf "$wadir"
	echo "Deleting $config_directory .."
	rm -rf "$config_directory"
	echo "Done!"
fi
EOF
	chmod(0755, "$config_directory/uninstall.sh");
	print ".. done\n";
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
	print ".. done\n";
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
	$ENV{'WEBMIN_UPGRADING'} = $upgrading;
	system("$perl ".&quote_path("$wadir/run-postinstalls.pl"));
	print ".. done\n";
	print "\n";
	}

# Run package-defined post-install script
if (-r "$srcdir/setup-post.pl") {
	require "$srcdir/setup-post.pl";
	}

if (!$ENV{'nostart'}) {
	if (!$miniserv{'inetd'}) {
		$action = 'start';
		if ($upgrading) {
			$action = 'restart';
		}
		my $start_cmd_extra;
		if ($upgrading && $killmodenonepl == 1) {
			$start_cmd_extra = "$config_directory/.reload-init-systemd >/dev/null 2>&1 </dev/null";
			if (-r $start_cmd_extra) {
				$start_cmd .= " ; $start_cmd_extra";
				}
			}
		print "Attempting to $action Webmin web server ..\n";
		$ex = system($start_cmd);
		unlink($start_cmd_extra)
			if (-r $start_cmd_extra);
		if ($ex) {
			&errorexit("Failed to $action web server!");
			}
		print ".. done\n";
		print "\n";
		}
	$postactionmsg = "installed";
	$postactionmsg2 = "started";
	if ($upgrading) {
		$postactionmsg = "upgraded";
		$postactionmsg2 = "restarted";
	}
	print "****************************************************************************\n";
	print "Webmin has been $postactionmsg and $postactionmsg2 successfully.\n";
	print "\n";
	if (!$ENV{'nodepsmsg'} && !$upgrading) {
		print "Since Webmin was installed outside the package manager, ensure the\n";
		print "following recommended Perl modules and packages are present:\n";
		print " Perl modules:\n";
		print "  - DateTime, DateTime::Locale, DateTime::TimeZone, Data::Dumper,\n";
		print "  - Digest::MD5, Digest::SHA, Encode::Detect, File::Basename,\n";
		print "  - File::Path, Net::SSLeay, Time::HiRes, Time::Local, Time::Piece,\n";
		print "  - Socket6, Sys::Syslog, JSON::XS, lib, open\n";
		print " Packages:\n";
		print "  - openssl - Cryptography library with TLS implementation\n";
		print "  - shared-mime-info - Shared MIME information database\n";
		print "  - tar gzip unzip - File compression and packaging utilities\n";
		print "\n";
		}
	print "Use your web browser to go to the following URL and login\n";
	print "with the name and password you entered previously:\n";
	print "\n";
	$host = &get_system_hostname();
	if ($ssl) {
		print "  https://$host:$miniserv{'port'}\n";
		}
	else {
		print "  http://$host:$miniserv{'port'}\n";
		}
	print "\n";
	if ($ssl) {
		print "Because Webmin uses SSL for encryption only, the certificate\n";
		print "it uses is not signed by one of the recognized CAs such as\n";
		print "Verisign. When you first connect to the Webmin server, your\n";
		print "browser will ask you if you want to accept the certificate\n";
		print "presented, as it does not recognize the CA. Say yes.\n";
		print "\n";
		}
	} else {
		print "****************************************************************************\n";
		print "Webmin has been installed but not started!\n\n";
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
	if ("$^O" !~ /MSWin32/) {
		# Unix tar exists
		system("cd ".&quote_path($srcdir)." && tar cf - . | (cd ".&quote_path($wadir)." ; tar xf -)");
		}
	else {
		# Looks like Windows .. use xcopy command
		system("xcopy \"$srcdir\" \"$wadir\" /Y /E /I /Q");
		}
	print ".. done\n";
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

sub make_dir_recursive_local
{
my ($dir, $mod) = @_;
my @folders = split(/\//, $dir);
my $folder_created;
foreach my $folder (@folders) {
    next if (!$folder);
    $folder_created .= "/$folder";
    if (mkdir($folder_created)) {
        chmod($mod, $folder_created)
            if ($mod && -d $folder_created);
        }
    }
return -d $dir;
}

sub get_openssl_version
{
my $out = &backquote_command("openssl version 2>/dev/null");
if ($out =~ /OpenSSL\s+(\d\.\d)/) {
	return $1;
	}
return 0;
}
