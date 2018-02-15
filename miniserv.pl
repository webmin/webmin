#!/usr/local/bin/perl
# A very simple perl web server used by Webmin

# Require basic libraries
package miniserv;
use Socket;
use POSIX;
use Time::Local;
eval "use Time::HiRes;";

@itoa64 = split(//, "./0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz");

# Find and read config file
if ($ARGV[0] eq "--nofork") {
	$nofork_argv = 1;
	shift(@ARGV);
	}
if (@ARGV != 1) {
	die "Usage: miniserv.pl <config file>";
	}
if ($ARGV[0] =~ /^([a-z]:)?\//i) {
	$config_file = $ARGV[0];
	}
else {
	chop($pwd = `pwd`);
	$config_file = "$pwd/$ARGV[0]";
	}
%config = &read_config_file($config_file);
if ($config{'perllib'}) {
	push(@INC, split(/:/, $config{'perllib'}));
	$ENV{'PERLLIB'} .= ':'.$config{'perllib'};
	}
@startup_msg = ( );

# Check if SSL is enabled and available
if ($config{'ssl'}) {
	eval "use Net::SSLeay";
	if (!$@) {
		$use_ssl = 1;
		# These functions only exist for SSLeay 1.0
		eval "Net::SSLeay::SSLeay_add_ssl_algorithms()";
		eval "Net::SSLeay::load_error_strings()";
		if (defined(&Net::SSLeay::X509_STORE_CTX_get_current_cert) &&
		    defined(&Net::SSLeay::CTX_load_verify_locations) &&
		    (defined(&Net::SSLeay::CTX_set_verify) ||
		     defined(&Net::SSLeay::set_verify))) {
			$client_certs = 1;
			}
		}
	}

# Check if IPv6 is enabled and available
if ($config{'ipv6'}) {
	eval "use Socket6";
	if (!$@) {
		push(@startup_msg, "IPv6 support enabled");
		$use_ipv6 = 1;
		}
	else {
		push(@startup_msg, "IPv6 support cannot be enabled without ".
				   "the Socket6 perl module");
		}
	}

# Check if the syslog module is available to log hacking attempts
if ($config{'syslog'} && !$config{'inetd'}) {
	eval "use Sys::Syslog qw(:DEFAULT setlogsock)";
	if (!$@) {
		$use_syslog = 1;
		}
	}

# check if the TCP-wrappers module is available
if ($config{'libwrap'}) {
	eval "use Authen::Libwrap qw(hosts_ctl STRING_UNKNOWN)";
	if (!$@) {
		$use_libwrap = 1;
		}
	}

# Check if the MD5 perl module is available
eval "use MD5; \$dummy = new MD5; \$dummy->add('foo');";
if (!$@) {
	$use_md5 = "MD5";
	}
else {
	eval "use Digest::MD5; \$dummy = new Digest::MD5; \$dummy->add('foo');";
	if (!$@) {
		$use_md5 = "Digest::MD5";
		}
	}
if ($use_md5) {
	push(@startup_msg, "Using MD5 module $use_md5");
	}

# Check if the SHA512 perl module is available
eval "use Crypt::SHA";
$use_sha512 = $@ ? "Crypt::SHA" : undef;
if ($use_sha512) {
	push(@startup_msg, "Using SHA512 module $use_sha512");
	}

# Get miniserv's perl path and location
$miniserv_path = $0;
open(SOURCE, $miniserv_path);
<SOURCE> =~ /^#!(\S+)/;
$perl_path = $1;
close(SOURCE);
if (!-x $perl_path) {
	$perl_path = $^X;
	}
if (-l $perl_path) {
	$linked_perl_path = readlink($perl_path);
	}
@miniserv_argv = @ARGV;

# Check vital config options
&update_vital_config();

$sidname = $config{'sidname'};
die "Session authentication cannot be used in inetd mode"
	if ($config{'inetd'} && $config{'session'});

# check if the PAM module is available to authenticate
if ($config{'assume_pam'}) {
	# Just assume that it will work. This can also be used to work around
	# a Solaris bug in which using PAM before forking caused it to fail
	# later!
	$use_pam = 1;
	}
elsif (!$config{'no_pam'}) {
	eval "use Authen::PAM;";
	if (!$@) {
		# check if the PAM authentication can be used by opening a
		# PAM handle
		local $pamh;
		if (ref($pamh = new Authen::PAM($config{'pam'},
						$config{'pam_test_user'},
						\&pam_conv_func))) {
			# Now test a login to see if /etc/pam.d/webmin is set
			# up properly.
			$pam_conv_func_called = 0;
			$pam_username = "test";
			$pam_password = "test";
			$pamh->pam_authenticate();
			if ($pam_conv_func_called) {
				push(@startup_msg,
				     "PAM authentication enabled");
				$use_pam = 1;
				}
			else {
				push(@startup_msg,
				    "PAM test failed - maybe ".
				    "/etc/pam.d/$config{'pam'} does not exist");
				}
			}
		else {
			push(@startup_msg,
			     "PAM initialization of Authen::PAM failed");
			}
		}
	else {
		push(@startup_msg,
		     "Perl module Authen::PAM needed for PAM is ".
		     "not installed : $@");
		}
	}
if ($config{'pam_only'} && !$use_pam) {
	foreach $msg (@startup_msg) {
	     print STDERR $msg,"\n";
	}
	print STDERR "PAM use is mandatory, but could not be enabled!\n";
	print STDERR "no_pam and pam_only both are set!\n" if ($config{no_pam});
	exit(1);
	}
elsif ($pam_msg && !$use_pam) {
	push(@startup_msg,
	     "Continuing without the Authen::PAM perl module");
	}

# Check if the User::Utmp perl module is installed
if ($config{'utmp'}) {
	eval "use User::Utmp;";
	if (!$@) {
		$write_utmp = 1;
		push(@startup_msg, "UTMP logging enabled");
		}
	else {
		push(@startup_msg, 
		     "Perl module User::Utmp needed for Utmp logging is ".
		     "not installed : $@");
		}
	}

# See if the crypt function fails
eval "crypt('foo', 'xx')";
if ($@) {
	eval "use Crypt::UnixCrypt";
	if (!$@) {
		$use_perl_crypt = 1;
		push(@startup_msg, 
		     "Using Crypt::UnixCrypt for password encryption");
		}
	else {
		push(@startup_msg, 
		     "crypt() function un-implemented, and Crypt::UnixCrypt ".
		     "not installed - password authentication will fail");
		}
	}

# Check if /dev/urandom really generates random IDs, by calling it twice
local $rand1 = &generate_random_id("foo", 1);
local $rand2 = &generate_random_id("foo", 2);
if ($rand1 eq $rand2) {
	$bad_urandom = 1;
	push(@startup_msg,
	     "Random number generator file /dev/urandom is not reliable");
	}

# Check if we can call sudo
if ($config{'sudo'} && &has_command("sudo")) {
	eval "use IO::Pty";
	if (!$@) {
		$use_sudo = 1;
		}
	else {
		push(@startup_msg,
		     "Perl module IO::Pty needed for calling sudo is not ".
		     "installed : $@");
		}
	}

# init days and months for http_date
@weekday = ( "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" );
@month = ( "Jan", "Feb", "Mar", "Apr", "May", "Jun",
	   "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" );

# Change dir to the server root
@roots = ( $config{'root'} );
for($i=0; defined($config{"extraroot_$i"}); $i++) {
	push(@roots, $config{"extraroot_$i"});
	}
chdir($roots[0]);
eval { $user_homedir = (getpwuid($<))[7]; };
if ($@) {
	# getpwuid doesn't work on windows
	$user_homedir = $ENV{"HOME"} || $ENV{"USERPROFILE"} || "/";
	$on_windows = 1;
	}

# Read users file
&read_users_file();

# Setup SSL if possible and if requested
if (!-r $config{'keyfile'}) {
	# Key file doesn't exist!
	if ($config{'keyfile'}) {
		print STDERR "SSL key file $config{'keyfile'} does not exist\n";
		}
	$use_ssl = 0;
	}
elsif ($config{'certfile'} && !-r $config{'certfile'}) {
	# Cert file doesn't exist!
	print STDERR "SSL cert file $config{'certfile'} does not exist\n";
	$use_ssl = 0;
	}
@ipkeys = &get_ipkeys(\%config);
if ($use_ssl) {
	if ($config{'ssl_version'}) {
		# Force an SSL version
		$Net::SSLeay::version = $config{'ssl_version'};
		$Net::SSLeay::ssl_version = $config{'ssl_version'};
		}
	$client_certs = 0 if (!-r $config{'ca'} || !%certs);
	$ssl_contexts{"*"} = &create_ssl_context($config{'keyfile'},
						 $config{'certfile'},
						 $config{'extracas'});
	foreach $ipkey (@ipkeys) {
		$ctx = &create_ssl_context($ipkey->{'key'}, $ipkey->{'cert'},
				   $ipkey->{'extracas'} || $config{'extracas'});
		foreach $ip (@{$ipkey->{'ips'}}) {
			$ssl_contexts{$ip} = $ctx;
			}
		}

	# Setup per-hostname SSL contexts on the main IP
	if (defined(&Net::SSLeay::CTX_set_tlsext_servername_callback)) {
		Net::SSLeay::CTX_set_tlsext_servername_callback(
		    $ssl_contexts{"*"},
		    sub {
			my $ssl = shift;
			my $h = Net::SSLeay::get_servername($ssl);
			my $c = $ssl_contexts{$h} ||
				$h =~ /^[^\.]+\.(.*)$/ && $ssl_contexts{"*.$1"};
			if ($c) {
				Net::SSLeay::set_SSL_CTX($ssl, $c);
				}
			});
		}
	}

# Load gzip library if enabled
if ($config{'gzip'} eq '1') {
	eval "use Compress::Zlib";
	if (!$@) {
		$use_gzip = 1;
		}
	}

# Setup syslog support if possible and if requested
if ($use_syslog) {
	open(ERRDUP, ">&STDERR");
	open(STDERR, ">/dev/null");
	$log_socket = $config{"logsock"} || "unix";
	eval 'openlog($config{"pam"}, "cons,pid,ndelay", "authpriv"); setlogsock($log_socket)';
	if ($@) {
		$use_syslog = 0;
		}
	else {
		local $msg = ucfirst($config{'pam'})." starting";
		eval { syslog("info", "%s", $msg); };
		if ($@) {
			eval {
				setlogsock("inet");
				syslog("info", "%s", $msg);
				};
			if ($@) {
				# All attempts to use syslog have failed..
				$use_syslog = 0;
				}
			}
		}
	open(STDERR, ">&ERRDUP");
	close(ERRDUP);
	}

# Read MIME types file and add extra types
&read_mime_types();

# get the time zone
if ($config{'log'}) {
	local(@gmt, @lct, $days, $hours, $mins);
	@gmt = gmtime(time());
	@lct = localtime(time());
	$days = $lct[3] - $gmt[3];
	$hours = ($days < -1 ? 24 : 1 < $days ? -24 : $days * 24) +
		 $lct[2] - $gmt[2];
	$mins = $hours * 60 + $lct[1] - $gmt[1];
	$timezone = ($mins < 0 ? "-" : "+"); $mins = abs($mins);
	$timezone .= sprintf "%2.2d%2.2d", $mins/60, $mins%60;
	}

# Build various maps from the config files
&build_config_mappings();

# start up external authentication program, if needed
if ($config{'extauth'}) {
	socketpair(EXTAUTH, EXTAUTH2, AF_UNIX, SOCK_STREAM, PF_UNSPEC);
	if (!($extauth = fork())) {
		close(EXTAUTH);
		close(STDIN);
		close(STDOUT);
		open(STDIN, "<&EXTAUTH2");
		open(STDOUT, ">&EXTAUTH2");
		exec($config{'extauth'}) or die "exec failed : $!\n";
		}
	close(EXTAUTH2);
	local $os = select(EXTAUTH);
	$| = 1; select($os);
	}

# Pre-load any libraries
if (!$config{'inetd'}) {
	foreach $pl (split(/\s+/, $config{'preload'})) {
		($pkg, $lib) = split(/=/, $pl);
		$pkg =~ s/[^A-Za-z0-9]/_/g;
		eval "package $pkg; do '$config{'root'}/$lib'";
		if ($@) {
			print STDERR "Failed to pre-load $lib in $pkg : $@\n";
			}
		else {
			print STDERR "Pre-loaded $lib in $pkg\n";
			}
		}
	foreach $pl (split(/\s+/, $config{'premodules'})) {
		if ($pl =~ /\//) {
			($dir, $mod) = split(/\//, $pl);
			}
		else {
			($dir, $mod) = (undef, $pl);
			}
		push(@INC, "$config{'root'}/$dir");
		eval "package $mod; use $mod ()";
		if ($@) {
			print STDERR "Failed to pre-load $mod : $@\n";
			}
		}
	}

# Open debug log if set
if ($config{'debuglog'}) {
	open(DEBUG, ">>$config{'debuglog'}");
	chmod(0700, $config{'debuglog'});
	select(DEBUG); $| = 1; select(STDOUT);
	print DEBUG "miniserv.pl starting ..\n";
	}

# Write out (empty) blocked hosts file
&write_blocked_file();

# Initially read webmin cron functions and last execution times
&read_webmin_crons();
%webmincron_last = ( );
&read_file($config{'webmincron_last'}, \%webmincron_last);

# Pre-cache lang files
&precache_files();

if ($config{'inetd'}) {
	# We are being run from inetd - go direct to handling the request
	&redirect_stderr_to_log();
	$SIG{'HUP'} = 'IGNORE';
	$SIG{'TERM'} = 'DEFAULT';
	$SIG{'PIPE'} = 'DEFAULT';
	open(SOCK, "+>&STDIN");

	# Check if it is time for the logfile to be cleared
	if ($config{'logclear'}) {
		local $write_logtime = 0;
		local @st = stat("$config{'logfile'}.time");
		if (@st) {
			if ($st[9]+$config{'logtime'}*60*60 < time()){
				# need to clear log
				$write_logtime = 1;
				unlink($config{'logfile'});
				}
			}
		else { $write_logtime = 1; }
		if ($write_logtime) {
			open(LOGTIME, ">$config{'logfile'}.time");
			print LOGTIME time(),"\n";
			close(LOGTIME);
			}
		}

	# Work out if IPv6 is being used locally
	local $sn = getsockname(SOCK);
	print DEBUG "sn=$sn\n";
	print DEBUG "length=",length($sn),"\n";
	$localipv6 = length($sn) > 16;
	print DEBUG "localipv6=$localipv6\n";

	# Initialize SSL for this connection
	if ($use_ssl) {
		$ssl_con = &ssl_connection_for_ip(SOCK, $localipv6);
		$ssl_con || exit;
		}

	# Work out the hostname for this web server
	$host = &get_socket_name(SOCK, $localipv6);
	print DEBUG "host=$host\n";
	$host || exit;
	$port = $config{'port'};
	$acptaddr = getpeername(SOCK);
	print DEBUG "acptaddr=$acptaddr\n";
	print DEBUG "length=",length($acptaddr),"\n";
	$acptaddr || exit;

	# Work out remote and local IPs
	$ipv6 = length($acptaddr) > 16;
	print DEBUG "ipv6=$ipv6\n";
	(undef, $locala) = &get_socket_ip(SOCK, $localipv6);
	print DEBUG "locala=$locala\n";
	(undef, $peera, undef) = &get_address_ip($acptaddr, $ipv6);
	print DEBUG "peera=$peera\n";

	print DEBUG "main: Starting handle_request loop pid=$$\n";
	while(&handle_request($peera, $locala, $ipv6)) { }
	print DEBUG "main: Done handle_request loop pid=$$\n";
	close(SOCK);
	exit;
	}

# Build list of sockets to listen on
$config{'bind'} = '' if ($config{'bind'} eq '*');
if ($config{'bind'}) {
	# Listening on a specific IP
	if (&check_ip6address($config{'bind'})) {
		# IP is v6
		$use_ipv6 || die "Cannot bind to $config{'bind'} without IPv6";
		push(@sockets, [ inet_pton(AF_INET6(),$config{'bind'}),
				 $config{'port'},
				 PF_INET6() ]);
		}
	else {
		# IP is v4
		push(@sockets, [ inet_aton($config{'bind'}),
				 $config{'port'},
				 PF_INET() ]);
		}
	}
else {
	# Listening on all IPs
	push(@sockets, [ INADDR_ANY, $config{'port'}, PF_INET() ]);
	if ($use_ipv6) {
		# Also IPv6
		push(@sockets, [ in6addr_any(), $config{'port'},
				 PF_INET6() ]);
		}
	}
foreach $s (split(/\s+/, $config{'sockets'})) {
	if ($s =~ /^(\d+)$/) {
		# Just listen on another port on the main IP
		push(@sockets, [ $sockets[0]->[0], $s, $sockets[0]->[2] ]);
		if ($use_ipv6 && !$config{'bind'}) {
			# Also listen on that port on the main IPv6 address
			push(@sockets, [ $sockets[1]->[0], $s,
					 $sockets[1]->[2] ]);
			}
		}
	elsif ($s =~ /^\*:(\d+)$/) {
		# Listening on all IPs on some port
		push(@sockets, [ INADDR_ANY, $1,
				 PF_INET() ]);
		if ($use_ipv6) {
			push(@sockets, [ in6addr_any(), $1,
					 PF_INET6() ]);
			}
		}
	elsif ($s =~ /^(\S+):(\d+)$/) {
		# Listen on a specific port and IP
		my ($ip, $port) = ($1, $2);
		if (&check_ip6address($ip)) {
			$use_ipv6 || die "Cannot bind to $ip without IPv6";
			push(@sockets, [ inet_pton(AF_INET6(),
						   $ip),
					 $port, PF_INET6() ]);
			}
		else {
			push(@sockets, [ inet_aton($ip), $port,
					 PF_INET() ]);
			}
		}
	elsif ($s =~ /^([0-9\.]+):\*$/ || $s =~ /^([0-9\.]+)$/) {
		# Listen on the main port on another IPv4 address
		push(@sockets, [ inet_aton($1), $sockets[0]->[1],
				 PF_INET() ]);
		}
	elsif (($s =~ /^([0-9a-f\:]+):\*$/ || $s =~ /^([0-9a-f\:]+)$/) &&
	       $use_ipv6) {
		# Listen on the main port on another IPv6 address
		push(@sockets, [ inet_pton(AF_INET6(), $1),
				 $sockets[0]->[1],
				 PF_INET6() ]);
		}
	}

# Open all the sockets
$proto = getprotobyname('tcp');
@sockerrs = ( );
$tried_inaddr_any = 0;
for($i=0; $i<@sockets; $i++) {
	$fh = "MAIN$i";
	if (!socket($fh, $sockets[$i]->[2], SOCK_STREAM, $proto)) {
		# Protocol not supported
		push(@sockerrs, "Failed to open socket family $sockets[$i]->[2] : $!");
		next;
		}
	setsockopt($fh, SOL_SOCKET, SO_REUSEADDR, pack("l", 1));
	if ($sockets[$i]->[2] eq PF_INET()) {
		$pack = pack_sockaddr_in($sockets[$i]->[1], $sockets[$i]->[0]);
		}
	else {
		$pack = pack_sockaddr_in6($sockets[$i]->[1], $sockets[$i]->[0]);
		setsockopt($fh, 41, 26, pack("l", 1));	# IPv6 only
		}
	for($j=0; $j<5; $j++) {
		last if (bind($fh, $pack));
		sleep(1);
		}
	if ($j == 5) {
		# All attempts failed .. give up
		if ($sockets[$i]->[0] eq INADDR_ANY ||
		    $use_ipv6 && $sockets[$i]->[0] eq in6addr_any()) {
			push(@sockerrs,
			     "Failed to bind to port $sockets[$i]->[1] : $!");
			$tried_inaddr_any = 1;
			}
		else {
			$ip = &network_to_address($sockets[$i]->[0]);
			push(@sockerrs,
			     "Failed to bind to IP $ip port ".
			     "$sockets[$i]->[1] : $!");
			}
		}
	else {
		listen($fh, &get_somaxconn());
		push(@socketfhs, $fh);
		$ipv6fhs{$fh} = $sockets[$i]->[2] eq PF_INET() ? 0 : 1;
		}
	}
foreach $se (@sockerrs) {
	print STDERR $se,"\n";
	}

# If all binds failed, try binding to any address
if (!@socketfhs && !$tried_inaddr_any) {
	print STDERR "Falling back to listening on any address\n";
	$fh = "MAIN";
	socket($fh, PF_INET(), SOCK_STREAM, $proto) ||
		die "Failed to open socket : $!";
	setsockopt($fh, SOL_SOCKET, SO_REUSEADDR, pack("l", 1));
	if (!bind($fh, pack_sockaddr_in($sockets[0]->[1], INADDR_ANY))) {
		print STDERR "Failed to bind to port $sockets[0]->[1] : $!\n";
		exit(1);
		}
	listen($fh, &get_somaxconn());
	push(@socketfhs, $fh);
	}
elsif (!@socketfhs && $tried_inaddr_any) {
	print STDERR "Could not listen on any ports";
	exit(1);
	}

if ($config{'listen'}) {
	# Open the socket that allows other webmin servers to find this one
	$proto = getprotobyname('udp');
	if (socket(LISTEN, PF_INET(), SOCK_DGRAM, $proto)) {
		setsockopt(LISTEN, SOL_SOCKET, SO_REUSEADDR, pack("l", 1));
		bind(LISTEN, pack_sockaddr_in($config{'listen'}, INADDR_ANY));
		listen(LISTEN, &get_somaxconn());
		}
	else {
		$config{'listen'} = 0;
		}
	}

# Split from the controlling terminal, unless configured not to
if (!$config{'nofork'} && !$nofork_argv) {
	if (fork()) { exit; }
	}
eval { setsid(); };	# may not work on Windows

# Close standard file handles
open(STDIN, "</dev/null");
open(STDOUT, ">/dev/null");
&redirect_stderr_to_log();
&log_error("miniserv.pl started");
foreach $msg (@startup_msg) {
	&log_error($msg);
	}

# write out the PID file
&write_pid_file();
$miniserv_main_pid = $$;

# Start the log-clearing process, if needed. This checks every minute
# to see if the log has passed its reset time, and if so clears it
if ($config{'logclear'}) {
	if (!($logclearer = fork())) {
		&close_all_sockets();
		close(LISTEN);
		while(1) {
			local $write_logtime = 0;
			local @st = stat("$config{'logfile'}.time");
			if (@st) {
				if ($st[9]+$config{'logtime'}*60*60 < time()){
					# need to clear log
					$write_logtime = 1;
					unlink($config{'logfile'});
					}
				}
			else { $write_logtime = 1; }
			if ($write_logtime) {
				open(LOGTIME, ">$config{'logfile'}.time");
				print LOGTIME time(),"\n";
				close(LOGTIME);
				}
			sleep(5*60);
			}
		exit;
		}
	push(@childpids, $logclearer);
	}

# Setup the logout time dbm if needed
if ($config{'session'}) {
	eval "use SDBM_File";
	dbmopen(%sessiondb, $config{'sessiondb'}, 0700);
	eval "\$sessiondb{'1111111111'} = 'foo bar';";
	if ($@) {
		dbmclose(%sessiondb);
		eval "use NDBM_File";
		dbmopen(%sessiondb, $config{'sessiondb'}, 0700);
		}
	else {
		delete($sessiondb{'1111111111'});
		}
	}

# Run the main loop
$SIG{'HUP'} = 'miniserv::trigger_restart';
$SIG{'TERM'} = 'miniserv::term_handler';
$SIG{'USR1'} = 'miniserv::trigger_reload';
$SIG{'PIPE'} = 'IGNORE';
local $remove_session_count = 0;
$need_pipes = $config{'passdelay'} || $config{'session'};
$cron_runs = 0;
while(1) {
	# Check if any webmin cron jobs are ready to run
	&execute_ready_webmin_crons($cron_runs++);

	# wait for a new connection, or a message from a child process
	local ($i, $rmask);
	if (@childpids <= $config{'maxconns'}) {
		# Only accept new main socket connects when ready
		local $s;
		foreach $s (@socketfhs) {
			vec($rmask, fileno($s), 1) = 1;
			}
		}
	else {
		printf STDERR "too many children (%d > %d)\n",
			scalar(@childpids), $config{'maxconns'};
		}
	if ($need_pipes) {
		for($i=0; $i<@passin; $i++) {
			vec($rmask, fileno($passin[$i]), 1) = 1;
			}
		}
	vec($rmask, fileno(LISTEN), 1) = 1 if ($config{'listen'});

	# Wait for a connection
	local $sel = select($rmask, undef, undef, 10);

	# Check the flag files
	if ($config{'restartflag'} && -r $config{'restartflag'}) {
		print STDERR "restart flag file detected\n";
		unlink($config{'restartflag'});
		$need_restart = 1;
		}
	if ($config{'reloadflag'} && -r $config{'reloadflag'}) {
		unlink($config{'reloadflag'});
		$need_reload = 1;
		}

	if ($need_restart) {
		# Got a HUP signal while in select() .. restart now
		&restart_miniserv();
		}
	if ($need_reload) {
		# Got a USR1 signal while in select() .. re-read config
		$need_reload = 0;
		&reload_config_file();
		}
	local $time_now = time();

	# Clean up finished processes
	local $pid;
	do {	$pid = waitpid(-1, WNOHANG);
		@childpids = grep { $_ != $pid } @childpids;
		} while($pid != 0 && $pid != -1);

	# run the unblocking procedure to check if enough time has passed to
	# unblock hosts that heve been blocked because of password failures
	$unblocked = 0;
	if ($config{'blockhost_failures'}) {
		$i = 0;
		while ($i <= $#deny) {
			if ($blockhosttime{$deny[$i]} &&
			    $config{'blockhost_time'} != 0 &&
			    ($time_now - $blockhosttime{$deny[$i]}) >=
			     $config{'blockhost_time'}) {
				# the host can be unblocked now
				$hostfail{$deny[$i]} = 0;
				splice(@deny, $i, 1);
				$unblocked = 1;
				}
			$i++;
			}
		}

	# Do the same for blocked users
	if ($config{'blockuser_failures'}) {
		$i = 0;
		while ($i <= $#deny) {
			if ($blockusertime{$deny[$i]} &&
			    $config{'blockuser_time'} != 0 &&
			    ($time_now - $blockusertime{$deny[$i]}) >=
			     $config{'blockuser_time'}) {
				# the user can be unblocked now
				$userfail{$deny[$i]} = 0;
				splice(@denyusers, $i, 1);
				$unblocked = 1;
				}
			$i++;
			}
		}
	if ($unblocked) {
		&write_blocked_file();
		}

	if ($config{'session'} && (++$remove_session_count%50) == 0) {
		# Remove sessions with more than 7 days of inactivity,
		local $s;
		foreach $s (keys %sessiondb) {
			local ($user, $ltime, $lip) =
				split(/\s+/, $sessiondb{$s});
			if ($time_now - $ltime > 7*24*60*60) {
				&run_logout_script($s, $user, undef, undef);
				&write_logout_utmp($user, $lip);
				if ($user =~ /^\!/ || $sessiondb{$s} eq '') {
					# Don't log anything for logged out
					# sessions or those with no data
					}
				elsif ($use_syslog && $user) {
					syslog("info", "%s",
					      "Timeout of session for $user");
					}
				elsif ($use_syslog) {
					syslog("info", "%s",
					      "Timeout of unknown session $s ".
					      "with value $sessiondb{$s}");
					}
				delete($sessiondb{$s});
				}
			}
		}

	if ($use_pam && $config{'pam_conv'}) {
		# Remove PAM sessions with more than 5 minutes of inactivity
		local $c;
		foreach $c (values %conversations) {
			if ($time_now - $c->{'time'} > 5*60) {
				&end_pam_conversation($c);
				if ($use_syslog) {
					syslog("info", "%s", "Timeout of PAM ".
						"session for $c->{'user'}");
					}
				}
			}
		}

	# Don't check any sockets if there is no activity
	next if ($sel <= 0);

	# Check if any of the main sockets have received a new connection
	local $sn = 0;
	foreach $s (@socketfhs) {
		if (vec($rmask, fileno($s), 1)) {
			# got new connection
			$acptaddr = accept(SOCK, $s);
			if (!$acptaddr) { next; }
			binmode(SOCK);	# turn off any Perl IO stuff

			# create pipes
			local ($PASSINr, $PASSINw, $PASSOUTr, $PASSOUTw);
			if ($need_pipes) {
				($PASSINr, $PASSINw, $PASSOUTr, $PASSOUTw) =
					&allocate_pipes();
				}

			# Work out IP and port of client
			local ($peerb, $peera, $peerp) =
				&get_address_ip($acptaddr, $ipv6fhs{$s});

			# Work out the local IP
			(undef, $locala) = &get_socket_ip(SOCK, $ipv6fhs{$s});

			# Check username of connecting user
			$localauth_user = undef;
			if ($config{'localauth'} && $peera eq "127.0.0.1") {
				if (open(TCP, "/proc/net/tcp")) {
					# Get the info direct from the kernel
					$peerh = sprintf("%4.4X", $peerp);
					while(<TCP>) {
						s/^\s+//;
						local @t = split(/[\s:]+/, $_);
						if ($t[1] eq '0100007F' &&
						    $t[2] eq $peerh) {
							$localauth_user =
							    getpwuid($t[11]);
							last;
							}
						}
					close(TCP);
					}
				if (!$localauth_user) {
					# Call lsof for the info
					local $lsofpid = open(LSOF,
						"$config{'localauth'} -i ".
						"TCP\@127.0.0.1:$peerp |");
					while(<LSOF>) {
						if (/^(\S+)\s+(\d+)\s+(\S+)/ &&
						    $2 != $$ && $2 != $lsofpid){
							$localauth_user = $3;
							}
						}
					close(LSOF);
					}
				}

			# Work out the hostname for this web server
			$host = &get_socket_name(SOCK, $ipv6fhs{$s});
			if (!$host) {
				print STDERR
				    "Failed to get local socket name : $!\n";
				close(SOCK);
				next;
				}
			$port = $sockets[$sn]->[1];

			# fork the subprocess
			local $handpid;
			if (!($handpid = fork())) {
				# setup signal handlers
				$SIG{'TERM'} = 'DEFAULT';
				$SIG{'PIPE'} = 'DEFAULT';
				#$SIG{'CHLD'} = 'IGNORE';
				$SIG{'HUP'} = 'IGNORE';
				$SIG{'USR1'} = 'IGNORE';

				# Close the file handle for the session DBM
				dbmclose(%sessiondb);

				# close useless pipes
				if ($need_pipes) {
					&close_all_pipes();
					close($PASSINr); close($PASSOUTw);
					}
				&close_all_sockets();
				close(LISTEN);

				# Initialize SSL for this connection
				if ($use_ssl) {
					$ssl_con = &ssl_connection_for_ip(
							SOCK, $ipv6fhs{$s});
					$ssl_con || exit;
					}

				print DEBUG
				  "main: Starting handle_request loop pid=$$\n";
				while(&handle_request($peera, $locala,
						      $ipv6fhs{$s})) {
					# Loop until keepalive stops
					}
				print DEBUG
				  "main: Done handle_request loop pid=$$\n";
				shutdown(SOCK, 1);
				close(SOCK);
				close($PASSINw); close($PASSOUTw);
				exit;
				}
			push(@childpids, $handpid);
			if ($need_pipes) {
				close($PASSINw); close($PASSOUTr);
				push(@passin, $PASSINr);
				push(@passout, $PASSOUTw);
				}
			close(SOCK);
			}
		$sn++;
		}

	if ($config{'listen'} && vec($rmask, fileno(LISTEN), 1)) {
		# Got UDP packet from another webmin server
		local $rcvbuf;
		local $from = recv(LISTEN, $rcvbuf, 1024, 0);
		next if (!$from);
		local $fromip = inet_ntoa((unpack_sockaddr_in($from))[1]);
		local $toip = inet_ntoa((unpack_sockaddr_in(
					 getsockname(LISTEN)))[1]);
		if ((!@deny || !&ip_match($fromip, $toip, @deny)) &&
		    (!@allow || &ip_match($fromip, $toip, @allow))) {
			local $listenhost = &get_socket_name(LISTEN, 0);
			send(LISTEN, "$listenhost:$config{'port'}:".
				 ($use_ssl || $config{'inetd_ssl'} ? 1 : 0).":".
				 ($config{'listenhost'} ?
					&get_system_hostname() : ""),
				 0, $from)
				if ($listenhost);
			}
		}

	# check for session, password-timeout and PAM messages from subprocesses
	for($i=0; $i<@passin; $i++) {
		if (vec($rmask, fileno($passin[$i]), 1)) {
			# this sub-process is asking about a password
			local $infd = $passin[$i];
			local $outfd = $passout[$i];
			#local $inline = <$infd>;
			local $inline = &sysread_line($infd);
			if ($inline) {
				print DEBUG "main: inline $inline";
				}
			else {
				print DEBUG "main: inline EOF\n";
				}
			if ($inline =~ /^delay\s+(\S+)\s+(\S+)\s+(\d+)/) {
				# Got a delay request from a subprocess.. for
				# valid logins, there is no delay (to prevent
				# denial of service attacks), but for invalid
				# logins the delay increases with each failed
				# attempt.
				if ($3) {
					# login OK.. no delay
					print $outfd "0 0\n";
					$wasblocked = $hostfail{$2} ||
						      $userfail{$1};
					$hostfail{$2} = 0;
					$userfail{$1} = 0;
					if ($wasblocked) {
						&write_blocked_file();
						}
					}
				else {
					# login failed..
					$hostfail{$2}++;
					$userfail{$1}++;
					$blocked = 0;

					# add the host to the block list,
					# if configured
 					if ($config{'blockhost_failures'} &&
					    $hostfail{$2} >=
					      $config{'blockhost_failures'}) {
						push(@deny, $2);
						$blockhosttime{$2} = $time_now;
						$blocked = 1;
						if ($use_syslog) {
							local $logtext = "Security alert: Host $2 blocked after $config{'blockhost_failures'} failed logins for user $1";
							syslog("crit", "%s",
								$logtext);
							}
						}

					# add the user to the user block list,
					# if configured
 					if ($config{'blockuser_failures'} &&
					    $userfail{$1} >=
					      $config{'blockuser_failures'}) {
						push(@denyusers, $1);
						$blockusertime{$1} = $time_now;
						$blocked = 2;
						if ($use_syslog) {
							local $logtext = "Security alert: User $1 blocked after $config{'blockuser_failures'} failed logins";
							syslog("crit", "%s",
								$logtext);
							}
						}

					# Lock out the user's password, if enabled
					if ($config{'blocklock'} &&
					    $userfail{$1} >=
					      $config{'blockuser_failures'}) {
						my $lk = &lock_user_password($1);
						$blocked = 2;
						if ($use_syslog) {
							local $logtext = $lk == 1 ? "Security alert: User $1 locked after $config{'blockuser_failures'} failed logins" : $lk < 0 ? "Security alert: User could not be locked" : "Security alert: User is already locked";
							syslog("crit", "%s",
								$logtext);
							}
						}

					# Send back a delay
					$dl = $userdlay{$1} -
				           int(($time_now - $userlast{$1})/50);
					$dl = $dl < 0 ? 0 : $dl+1;
					print $outfd "$dl $blocked\n";
					$userdlay{$1} = $dl;

					# Write out blocked status file
					if ($blocked) {
						&write_blocked_file();
						}
					}
				$userlast{$1} = $time_now;
				}
			elsif ($inline =~ /^verify\s+(\S+)\s+(\S+)\s+(\S+)/) {
				# Verifying a session ID
				local $session_id = $1;
				local $notimeout = $2;
				local $vip = $3;
				local $skey = $sessiondb{$session_id} ?
						$session_id : 
						&hash_session_id($session_id);
				if (!defined($sessiondb{$skey})) {
					# Session doesn't exist
					print $outfd "0 0\n";
					}
				else {
					local ($user, $ltime, $ip) =
					  split(/\s+/, $sessiondb{$skey});
					local $lot = &get_logout_time($user, $session_id);
					if ($lot &&
					    $time_now - $ltime > $lot*60 &&
					    !$notimeout) {
						# Session has timed out
						print $outfd "1 ",$time_now - $ltime,"\n";
						#delete($sessiondb{$skey});
						}
					elsif ($ip && $vip && $ip ne $vip &&
					       $config{'session_ip'}) {
						# Session was OK, but from the
						# wrong IP address
						print $outfd "3 $ip\n";
						}
					elsif ($user =~ /^\!/) {
						# Logged out session
						print $outfd "0 0\n";
						}
					else {
						# Session is OK
						print $outfd "2 $user\n";
						$sessiondb{$skey} = "$user $time_now $ip";
						}
					}
				}
			elsif ($inline =~ /^new\s+(\S+)\s+(\S+)\s+(\S+)/) {
				# Creating a new session
				local $session_id = $1;
				local $user = $2;
				local $ip = $3;
				$sessiondb{&hash_session_id($session_id)} =
					"$user $time_now $ip";
				}
			elsif ($inline =~ /^delete\s+(\S+)/) {
				# Logging out a session
				local $session_id = $1;
				local $skey = $sessiondb{$session_id} ?
						$session_id : 
						&hash_session_id($session_id);
				local ($user, $ltime, $ip) =
					split(/\s+/, $sessiondb{$skey});
				$user =~ s/^\!//;
				print $outfd $user,"\n";
				$sessiondb{$skey} = "!$user $ltime $ip";
				}
			elsif ($inline =~ /^pamstart\s+(\S+)\s+(\S+)\s+(.*)/) {
				# Starting a new PAM conversation
				local ($cid, $host, $user) = ($1, $2, $3);

				# Does this user even need PAM?
				local ($realuser, $canlogin) =
					&can_user_login($user, undef, $host);
				local $conv;
				if ($canlogin == 0) {
					# Cannot even login!
					print $outfd "0 Invalid username\n";
					}
				elsif ($canlogin != 2) {
					# Not using PAM .. so just ask for
					# the password.
					$conv = { 'user' => $realuser,
						  'host' => $host,
						  'step' => 0,
						  'cid' => $cid,
						  'time' => time() };
					print $outfd "3 Password\n";
					}
				else {
					# Start the PAM conversation
					# sub-process, and get a question
					$conv = { 'user' => $realuser,
						  'host' => $host,
						  'cid' => $cid,
						  'time' => time() };
					local ($PAMINr, $PAMINw, $PAMOUTr,
						$PAMOUTw) = &allocate_pipes();
					local $pampid = fork();
					if (!$pampid) {
						close($PAMOUTr); close($PAMINw);
						&pam_conversation_process(
							$realuser,
							$PAMOUTw, $PAMINr);
						}
					close($PAMOUTw); close($PAMINr);
					$conv->{'pid'} = $pampid;
					$conv->{'PAMOUTr'} = $PAMOUTr;
					$conv->{'PAMINw'} = $PAMINw;
					push(@childpids, $pampid);

					# Get the first PAM question
					local $pok = &recv_pam_question(
						$conv, $outfd);
					if (!$pok) {
						&end_pam_conversation($conv);
						}
					}

				$conversations{$cid} = $conv if ($conv);
				}
			elsif ($inline =~ /^pamanswer\s+(\S+)\s+(.*)/) {
				# A response to a PAM question
				local ($cid, $answer) = ($1, $2);
				local $conv = $conversations{$cid};
				if (!$conv) {
					# No such conversation?
					print $outfd "0 Bad login session\n";
					}
				elsif ($conv->{'pid'}) {
					# Send the PAM response and get
					# the next question
					&send_pam_answer($conv, $answer);
					local $pok = &recv_pam_question($conv, $outfd);
					if (!$pok) {
						&end_pam_conversation($conv);
						}
					}
				else {
					# This must be the password .. try it
					# and send back the results
					local ($vu, $expired, $nonexist) =
						&validate_user($conv->{'user'},
							       $answer,
							       $conf->{'host'});
					local $ok = $vu ? 1 : 0;
					print $outfd "2 $conv->{'user'} $ok $expired $notexist\n";
					&end_pam_conversation($conv);
					}
				}
			elsif ($inline =~ /^writesudo\s+(\S+)\s+(\d+)/) {
				# Store the fact that some user can sudo to root
				local ($user, $ok) = ($1, $2);
				$sudocache{$user} = $ok." ".time();
				}
			elsif ($inline =~ /^readsudo\s+(\S+)/) {
				# Query the user sudo cache (valid for 1 minute)
				local $user = $1;
				local ($ok, $last) =
					split(/\s+/, $sudocache{$user});
				if ($last < time()-60) {
					# Cache too old
					print $outfd "2\n";
					}
				else {
					# Tell client OK or not
					print $outfd "$ok\n";
					}
				}
			elsif ($inline =~ /\S/) {
				# Unknown line from pipe?
				print DEBUG "main: Unknown line from pipe $inline\n";
				print STDERR "Unknown line from pipe $inline\n";
				}
			else {
				# close pipe
				close($infd); close($outfd);
				$passin[$i] = $passout[$i] = undef;
				}
			}
		}
	@passin = grep { defined($_) } @passin;
	@passout = grep { defined($_) } @passout;
	}

# handle_request(remoteaddress, localaddress, ipv6-flag)
# Where the real work is done
sub handle_request
{
local ($acptip, $localip, $ipv6) = @_;
print DEBUG "handle_request: from $acptip to $localip ipv6=$ipv6\n";
if ($config{'loghost'}) {
	$acpthost = &to_hostname($acptip);
	$acpthost = $acptip if (!$acpthost);
	}
else {
	$acpthost = $acptip;
	}
$loghost = $acpthost;
$datestr = &http_date(time());
$ok_code = 200;
$ok_message = "Document follows";
$logged_code = undef;
$reqline = $request_uri = $page = undef;
$authuser = undef;
$validated = undef;

# check address against access list
if (@deny && &ip_match($acptip, $localip, @deny) ||
    @allow && !&ip_match($acptip, $localip, @allow)) {
	&http_error(403, "Access denied for ".&html_strip($acptip));
	return 0;
	}

if ($use_libwrap) {
	# Check address with TCP-wrappers
	if (!hosts_ctl($config{'pam'}, STRING_UNKNOWN,
		       $acptip, STRING_UNKNOWN)) {
		&http_error(403, "Access denied for ".&html_strip($acptip).
				 " by TCP wrappers");
		return 0;
		}
	}
print DEBUG "handle_request: passed IP checks\n";

# Compute a timeout for the start of headers, based on the number of
# child processes. As this increases, we use a shorter timeout to avoid
# an attacker overloading the system.
local $header_timeout = 60 + ($config{'maxconns'} - @childpids) * 10;

# Wait at most 60 secs for start of headers for initial requests, or
# 10 minutes for kept-alive connections
local $rmask;
vec($rmask, fileno(SOCK), 1) = 1;
local $to = $checked_timeout ? 10*60 : $header_timeout;
local $sel = select($rmask, undef, undef, $to);
if (!$sel) {
	if ($checked_timeout) {
		print DEBUG "handle_request: exiting due to timeout of $to\n";
		exit;
		}
	else {
		&http_error(400, "Timeout",
			    "Waited for $to seconds for start of headers");
		}
	}
$checked_timeout++;
print DEBUG "handle_request: passed timeout check\n";

# Read the HTTP request and headers
local $origreqline = &read_line();
($reqline = $origreqline) =~ s/\r|\n//g;
$method = $page = $request_uri = undef;
print DEBUG "handle_request reqline=$reqline\n";
if (!$reqline && (!$use_ssl || $checked_timeout > 1)) {
	# An empty request .. just close the connection
	print DEBUG "handle_request: rejecting empty request\n";
	return 0;
	}
elsif ($reqline !~ /^(\S+)\s+(.*)\s+HTTP\/1\..$/) {
	print DEBUG "handle_request: invalid reqline=$reqline\n";
	if ($use_ssl) {
		# This could be an http request when it should be https
		$use_ssl = 0;
		local $urlhost = $config{'musthost'} || $host;
		$urlhost = "[".$urlhost."]" if (&check_ip6address($urlhost));
		local $url = "https://$urlhost:$port/";
		if ($config{'ssl_redirect'}) {
			# Just re-direct to the correct URL
			sleep(1);	# Give browser a change to finish
					# sending its request
			&write_data("HTTP/1.0 302 Moved Temporarily\r\n");
			&write_data("Date: $datestr\r\n");
			&write_data("Server: $config{'server'}\r\n");
			&write_data("Location: $url\r\n");
			&write_keep_alive(0);
			&write_data("\r\n");
			return 0;
		} elsif ($config{'hide_admin_url'} != 1) {
			# Tell user the correct URL
			&http_error(200, "Document follows",
				"This web server is running in SSL mode. ".
				"Try the URL <a href='$url'>$url</a> ".
				"instead.<br>");
		} else {
			# Throw an error
			&http_error(404, "Page not found",
				"The requested URL was not found on this server ".
				"try <a href='/'>visiting the home page</a> of this site to see what you can find <br>");
		}
	} elsif (ord(substr($reqline, 0, 1)) == 128 && !$use_ssl) {
		# This could be an https request when it should be http ..
		# need to fake a HTTP response
		eval <<'EOF';
			use Net::SSLeay;
			eval "Net::SSLeay::SSLeay_add_ssl_algorithms()";
			eval "Net::SSLeay::load_error_strings()";
			$ssl_ctx = Net::SSLeay::CTX_new();
			Net::SSLeay::CTX_use_RSAPrivateKey_file(
				$ssl_ctx, $config{'keyfile'},
				&Net::SSLeay::FILETYPE_PEM);
			Net::SSLeay::CTX_use_certificate_file(
				$ssl_ctx,
				$config{'certfile'} || $config{'keyfile'},
				&Net::SSLeay::FILETYPE_PEM);
			$ssl_con = Net::SSLeay::new($ssl_ctx);
			pipe(SSLr, SSLw);
			if (!fork()) {
				close(SSLr);
				select(SSLw); $| = 1; select(STDOUT);
				print SSLw $origreqline;
				local $buf;
				while(sysread(SOCK, $buf, 1) > 0) {
					print SSLw $buf;
					}
				close(SOCK);
				exit;
				}
			close(SSLw);
			Net::SSLeay::set_wfd($ssl_con, fileno(SOCK));
			Net::SSLeay::set_rfd($ssl_con, fileno(SSLr));
			Net::SSLeay::accept($ssl_con) || die "accept() failed";
			$use_ssl = 1;
			local $url = $config{'musthost'} ?
					"https://$config{'musthost'}:$port/" :
					"https://$host:$port/";
			if ($config{'ssl_redirect'}) {
				# Just re-direct to the correct URL
				sleep(1);	# Give browser a change to
						# finish sending its request
				&write_data("HTTP/1.0 302 Moved Temporarily\r\n");
				&write_data("Date: $datestr\r\n");
				&write_data("Server: $config{'server'}\r\n");
				&write_data("Location: $url\r\n");
				&write_keep_alive(0);
				&write_data("\r\n");
				return 0;
			} elsif ($config{'hide_admin_url'} != 1) {
				# Tell user the correct URL
				&http_error(200, "Bad Request", "This web server is not running in SSL mode. Try the URL <a href='$url'>$url</a> instead.<br>");
			} else {
				&http_error(404, "Page not found",
					"The requested URL was not found on this server ".
					"try <a href='/'>visiting the home page</a> of this site to see what you can find <br>"
					);
			}
EOF
		if ($@) {
			&http_error(400, "Bad Request");
			}
		}
	else {
		&http_error(400, "Bad Request");
		}
	}
$method = $1;
$request_uri = $page = $2;
%header = ();
local $lastheader;
while(1) {
	($headline = &read_line()) =~ s/\r|\n//g;
	last if ($headline eq "");
	print DEBUG "handle_request: got headline $headline\n";
	if ($headline =~ /^(\S+):\s*(.*)$/) {
		$header{$lastheader = lc($1)} = $2;
		}
	elsif ($headline =~ /^\s+(.*)$/) {
		$header{$lastheader} .= $headline;
		}
	else {
		&http_error(400, "Bad Header ".&html_strip($headline));
		}
	if (&is_bad_header($header{$lastheader}, $lastheader)) {
		delete($header{$lastheader});
		&http_error(400, "Bad Header Contents ".
				 &html_strip($lastheader));
		}
	}

# If a remote IP is given in a header (such as via a proxy), only use it
# for logging unless trust_real_ip is set
local $headerhost = $header{'x-forwarded-for'} ||
		    $header{'x-real-ip'};
if ($config{'trust_real_ip'}) {
	$acpthost = $headerhost || $acpthost;
	if (&check_ipaddress($headerhost) || &check_ip6address($headerhost)) {
		# If a remote IP was given, use it for all access control checks
		# from now on.
		$acptip = $headerhost;
		}
	$loghost = $acpthost;
	}
else {
	$loghost = $headerhost || $loghost;
	}

if (defined($header{'host'})) {
	if ($header{'host'} =~ /^\[(.+)\]:([0-9]+)$/) {
		($host, $port) = ($1, $2);
		}
	elsif ($header{'host'} =~ /^([^:]+):([0-9]+)$/) {
		($host, $port) = ($1, $2);
		}
	else {
		$host = $header{'host'};
		}
	if ($config{'musthost'} && $host ne $config{'musthost'}) {
		# Disallowed hostname used
		&http_error(400, "Invalid HTTP hostname");
		}
	}
$portstr = $port == 80 && !$ssl ? "" :
	   $port == 443 && $ssl ? "" : ":$port";
$hostport = &check_ip6address($host) ? "[".$host."]".$portstr
				     : $host.$portstr;
undef(%in);
if ($page =~ /^([^\?]+)\?(.*)$/) {
	# There is some query string information
	$page = $1;
	$querystring = $2;
	print DEBUG "handle_request: querystring=$querystring\n";
	if ($querystring !~ /=/) {
		$queryargs = $querystring;
		$queryargs =~ s/\+/ /g;
    		$queryargs =~ s/%(..)/pack("c",hex($1))/ge;
		$querystring = "";
		}
	else {
		# Parse query-string parameters
		local @in = split(/\&/, $querystring);
		foreach $i (@in) {
			local ($k, $v) = split(/=/, $i, 2);
			$k =~ s/\+/ /g; $k =~ s/%(..)/pack("c",hex($1))/ge;
			$v =~ s/\+/ /g; $v =~ s/%(..)/pack("c",hex($1))/ge;
			$in{$k} = $v;
			}
		}
	}
$posted_data = undef;
if ($method eq 'POST' &&
    $header{'content-type'} eq 'application/x-www-form-urlencoded') {
	# Read in posted query string information, up the configured maximum
	# post request length
	$clen = $header{"content-length"};
	$clen_read = $clen > $config{'max_post'} ? $config{'max_post'} : $clen;
	while(length($posted_data) < $clen_read) {
		$buf = &read_data($clen_read - length($posted_data));
		if (!length($buf)) {
			&http_error(500, "Failed to read POST request");
			}
		chomp($posted_data);
		$posted_data =~ s/\015$//mg;
		$posted_data .= $buf;
		}
	print DEBUG "clen_read=$clen_read clen=$clen posted_data=",length($posted_data),"\n";
	if ($clen_read != $clen && length($posted_data) > $clen) {
		# If the client sent more data than we asked for, chop the
		# rest off
		$posted_data = substr($posted_data, 0, $clen);
		}
	if (length($posted_data) > $clen) {
		# When the client sent too much, delay so that it gets headers
		sleep(3);
		}
	if ($header{'user-agent'} =~ /MSIE/ &&
	    $header{'user-agent'} !~ /Opera/i) {
		# MSIE includes an extra newline in the data
		$posted_data =~ s/\r|\n//g;
		}
	local @in = split(/\&/, $posted_data);
	foreach $i (@in) {
		local ($k, $v) = split(/=/, $i, 2);
		#$v =~ s/\r|\n//g;
		$k =~ s/\+/ /g; $k =~ s/%(..)/pack("c",hex($1))/ge;
		$v =~ s/\+/ /g; $v =~ s/%(..)/pack("c",hex($1))/ge;
		$in{$k} = $v;
		}
	print DEBUG "handle_request: posted_data=$posted_data\n";
	}

# Reject CONNECT request, which isn't supported
if ($method eq "CONNECT" || $method eq "TRACE") {
	&http_error(405, "Method ".&html_strip($method)." is not supported");
	}

# work out accepted encodings
%acceptenc = map { $_, 1 } split(/,/, $header{'accept-encoding'});

# replace %XX sequences in page
$page =~ s/%(..)/pack("c",hex($1))/ge;

# Check if the browser's user agent indicates a mobile device
$mobile_device = &is_mobile_useragent($header{'user-agent'});

# Check if Host: header is for a mobile URL
foreach my $m (@mobile_prefixes) {
	if ($header{'host'} =~ /^\Q$m\E/i) {
		$mobile_device = 1;
		}
	}

# check for the logout flag file, and if existent deny authentication
if ($config{'logout'} && -r $config{'logout'}.$in{'miniserv_logout_id'}) {
	print DEBUG "handle_request: logout flag set\n";
	$deny_authentication++;
	open(LOGOUT, $config{'logout'}.$in{'miniserv_logout_id'});
	chop($count = <LOGOUT>);
	close(LOGOUT);
	$count--;
	if ($count > 0) {
		open(LOGOUT, ">$config{'logout'}$in{'miniserv_logout_id'}");
		print LOGOUT "$count\n";
		close(LOGOUT);
		}
	else {
		unlink($config{'logout'}.$in{'miniserv_logout_id'});
		}
	}

# check for any redirect for the requested URL
foreach my $pfx (@strip_prefix) {
	my $l = length($pfx);
	if(length($page) >= $l &&
	   substr($page,0,$l) eq $pfx) {
		$page=substr($page,$l);
		last;
		}
	}
$simple = &simplify_path($page, $bogus);
$rpath = $simple;
$rpath .= "&".$querystring if (defined($querystring));
$redir = $redirect{$rpath};
if (defined($redir)) {
	print DEBUG "handle_request: redir=$redir\n";
	&write_data("HTTP/1.0 302 Moved Temporarily\r\n");
	&write_data("Date: $datestr\r\n");
	&write_data("Server: $config{'server'}\r\n");
	local $ssl = $use_ssl || $config{'inetd_ssl'};
	$prot = $ssl ? "https" : "http";
	&write_data("Location: $prot://$hostport$redir\r\n");
	&write_keep_alive(0);
	&write_data("\r\n");
	return 0;
	}

# Check for a DAV request
$davpath = undef;
foreach my $d (@davpaths) {
	if ($simple eq $d || $simple =~ /^\Q$d\E\//) {
		$davpath = $d;
		last;
		}
	}
if (!$davpath && ($method eq "SEARCH" || $method eq "PUT")) {
	&http_error(400, "Bad Request method ".&html_strip($method));
	}

# Check for password if needed
if ($config{'userfile'}) {
	print DEBUG "handle_request: Need authentication\n";
	$validated = 0;
	$blocked = 0;

	# Session authentication is never used for connections by
	# another webmin server, or for specified pages, or for DAV, or XMLRPC,
	# or mobile browsers if requested.
	if ($header{'user-agent'} =~ /webmin/i ||
	    $header{'user-agent'} =~ /$config{'agents_nosession'}/i ||
	    $sessiononly{$simple} || $davpath ||
	    $simple eq "/xmlrpc.cgi" ||
            $acptip eq $config{'host_nosession'} ||
	    $mobile_device && $config{'mobile_nosession'}) {
		print DEBUG "handle_request: Forcing HTTP authentication\n";
		$config{'session'} = 0;
		}

	# Check for SSL authentication
	if ($use_ssl && $verified_client) {
		$peername = Net::SSLeay::X509_NAME_oneline(
				Net::SSLeay::X509_get_subject_name(
					Net::SSLeay::get_peer_certificate(
						$ssl_con)));
		$u = &find_user_by_cert($peername);
		if ($u) {
			$authuser = $u;
			$validated = 2;
			}
		if ($use_syslog && !$validated) {
			syslog("crit", "%s",
			       "Unknown SSL certificate $peername");
			}
		}

	if (!$validated && !$deny_authentication) {
		# check for IP-based authentication
		local $a;
		foreach $a (keys %ipaccess) {
			if ($acptip eq $a) {
				# It does! Auth as the user
				$validated = 3;
				$baseauthuser = $authuser =
					$ipaccess{$a};
				}
			}
		}

	# Check for normal HTTP authentication
	if (!$validated && !$deny_authentication && !$config{'session'} &&
	    $header{authorization} =~ /^basic\s+(\S+)$/i) {
		# authorization given..
		($authuser, $authpass) = split(/:/, &b64decode($1), 2);
		print DEBUG "handle_request: doing basic auth check authuser=$authuser authpass=$authpass\n";
		local ($vu, $expired, $nonexist, $wvu) =
			&validate_user($authuser, $authpass, $host,
				       $acptip, $port);
		print DEBUG "handle_request: vu=$vu expired=$expired nonexist=$nonexist\n";
		if ($vu && (!$expired || $config{'passwd_mode'} == 1)) {
			$authuser = $vu;
			$validated = 1;
			}
		else {
			$validated = 0;
			}
		if ($use_syslog && !$validated) {
			syslog("crit", "%s",
			       ($nonexist ? "Non-existent" :
				$expired ? "Expired" : "Invalid").
			       " login as $authuser from $acpthost");
			}
		if ($authuser =~ /\r|\n|\s/) {
			&http_error(500, "Invalid username",
				    "Username contains invalid characters");
			}
		if ($authpass =~ /\r|\n/) {
			&http_error(500, "Invalid password",
				    "Password contains invalid characters");
			}

		if ($config{'passdelay'} && !$config{'inetd'} && $authuser) {
			# check with main process for delay
			print DEBUG "handle_request: about to ask for password delay\n";
			print $PASSINw "delay $authuser $acptip $validated\n";
			<$PASSOUTr> =~ /(\d+) (\d+)/;
			$blocked = $2;
			print DEBUG "handle_request: password delay $1 $2\n";
			sleep($1);
			}
		}

	# Check for a visit to the special session login page
	if ($config{'session'} && !$deny_authentication &&
	    $page eq $config{'session_login'}) {
		if ($in{'logout'} && $header{'cookie'} =~ /(^|\s|;)$sidname=([a-f0-9]+)/) {
			# Logout clicked .. remove the session
			local $sid = $2;
			print $PASSINw "delete $sid\n";
			local $louser = <$PASSOUTr>;
			chop($louser);
			$logout = 1;
			$already_session_id = undef;
			$authuser = $baseauthuser = undef;
			if ($louser) {
				if ($use_syslog) {
					syslog("info", "%s", "Logout by $louser from $acpthost");
					}
				&run_logout_script($louser, $sid,
						   $loghost, $localip);
				&write_logout_utmp($louser, $actphost);
				}
			}
		else {
			# Validate the user
			if ($in{'user'} =~ /\r|\n|\s/) {
				&run_failed_script($in{'user'}, 'baduser',
						   $loghost, $localip);
				&http_error(500, "Invalid username",
				    "Username contains invalid characters");
				}
			if ($in{'pass'} =~ /\r|\n/) {
				&run_failed_script($in{'user'}, 'badpass',
						   $loghost, $localip);
				&http_error(500, "Invalid password",
				    "Password contains invalid characters");
				}

			local ($vu, $expired, $nonexist, $wvu) =
				&validate_user($in{'user'}, $in{'pass'}, $host,
					       $acptip, $port);
			if ($vu && $wvu) {
				my $uinfo = &get_user_details($wvu);
				if ($uinfo && $uinfo->{'twofactor_provider'}) {
					# Check two-factor token ID
					$err = &validate_twofactor(
						$wvu, $in{'twofactor'});
					if ($err) {
						&run_failed_script(
							$vu, 'twofactor',
							$loghost, $localip);
						$twofactor_msg = $err;
						$vu = undef;
						}
					}
				}
			local $hrv = &handle_login(
					$vu || $in{'user'}, $vu ? 1 : 0,
				      	$expired, $nonexist, $in{'pass'},
					$in{'notestingcookie'});
			return $hrv if (defined($hrv));
			}
		}

	# Check for a visit to the special PAM login page
	if ($config{'session'} && !$deny_authentication &&
	    $use_pam && $config{'pam_conv'} && $page eq $config{'pam_login'} &&
	    !$in{'restart'}) {
		# A question has been entered .. submit it to the main process
		print DEBUG "handle_request: Got call to $page ($in{'cid'})\n";
		print DEBUG "handle_request: For PAM, authuser=$authuser\n";
		if ($in{'answer'} =~ /\r|\n/ || $in{'cid'} =~ /\r|\n|\s/) {
			&http_error(500, "Invalid response",
			    "Response contains invalid characters");
			}

		if (!$in{'cid'}) {
			# Start of a new conversation - answer must be username
			$cid = &generate_random_id($in{'answer'});
			print $PASSINw "pamstart $cid $host $in{'answer'}\n";
			}
		else {
			# A response to a previous question
			$cid = $in{'cid'};
			print $PASSINw "pamanswer $cid $in{'answer'}\n";
			}

		# Read back the response, and the next question (if any)
		local $line = <$PASSOUTr>;
		$line =~ s/\r|\n//g;
		local ($rv, $question) = split(/\s+/, $line, 2);
		if ($rv == 0) {
			# Cannot login!
			local $hrv = &handle_login(
				!$in{'cid'} && $in{'answer'} ? $in{'answer'}
							     : "unknown",
				0, 0, 1, undef);
			return $hrv if (defined($hrv));
			}
		elsif ($rv == 1 || $rv == 3) {
			# Another question .. force use of PAM CGI
			$validated = 1;
			$method = "GET";
			$querystring .= "&cid=$cid&question=".
					&urlize($question);
			$querystring .= "&password=1" if ($rv == 3);
			$queryargs = "";
			$page = $config{'pam_login'};
			$miniserv_internal = 1;
			$logged_code = 401;
			}
		elsif ($rv == 2) {
			# Got back a final ok or failure
			local ($user, $ok, $expired, $nonexist) =
				split(/\s+/, $question);
			local $hrv = &handle_login(
				$user, $ok, $expired, $nonexist, undef,
				$in{'notestingcookie'});
			return $hrv if (defined($hrv));
			}
		elsif ($rv == 4) {
			# A message from PAM .. tell the user
			$validated = 1;
			$method = "GET";
			$querystring .= "&cid=$cid&message=".
					&urlize($question);
			$queryargs = "";
			$page = $config{'pam_login'};
			$miniserv_internal = 1;
			$logged_code = 401;
			}
		}

	# Check for a visit to the special password change page
	if ($config{'session'} && !$deny_authentication &&
	    $page eq $config{'password_change'} && !$validated) {
		# Just let this slide ..
		$validated = 1;
		$miniserv_internal = 3;
		}

	# Check for an existing session
	if ($config{'session'} && !$validated) {
		if ($already_session_id) {
			$session_id = $already_session_id;
			$authuser = $already_authuser;
			$validated = 1;
			}
		elsif (!$deny_authentication &&
		       $header{'cookie'} =~ /(^|\s|;)$sidname=([a-f0-9]+)/) {
			# Try all session cookies
			local $cookie = $header{'cookie'};
			while($cookie =~ s/(^|\s|;)$sidname=([a-f0-9]+)//) {
				$session_id = $2;
				local $notimeout =
					$in{'webmin_notimeout'} ? 1 : 0;
				print $PASSINw "verify $session_id $notimeout $acptip\n";
				<$PASSOUTr> =~ /(\d+)\s+(\S+)/;
				if ($1 == 2) {
					# Valid session continuation
					$validated = 1;
					$authuser = $2;
					$already_authuser = $authuser;
					$timed_out = undef;
					last;
					}
				elsif ($1 == 1) {
					# Session timed out
					$timed_out = $2;
					}
				elsif ($1 == 3) {
					# Session is OK, but from the wrong IP
					print STDERR "Session $session_id was ",
					  "used from $acptip instead of ",
					  "original IP $2\n";
					}
				else {
					# Invalid session ID .. don't set
					# verified flag
					}
				}
			}
		}

	# Check for local authentication
	if ($localauth_user && !$header{'x-forwarded-for'} && !$header{'via'}) {
		my $luser = &get_user_details($localauth_user);
		if ($luser) {
			# Local user exists in webmin users file
			$validated = 1;
			$authuser = $localauth_user;
			}
		else {
			# Check if local user is allowed by unixauth
			local @can = &can_user_login($localauth_user,
						     undef, $host);
			if ($can[0]) {
				$validated = 2;
				$authuser = $localauth_user;
				}
			else {
				$localauth_user = undef;
				}
			}
		}

	if (!$validated) {
		# Check if this path allows anonymous access
		local $a;
		foreach $a (keys %anonymous) {
			if (substr($simple, 0, length($a)) eq $a) {
				# It does! Auth as the user, if IP access
				# control allows him.
				if (&check_user_ip($anonymous{$a}) &&
				    &check_user_time($anonymous{$a})) {
					$validated = 3;
					$baseauthuser = $authuser =
						$anonymous{$a};
					}
				}
			}
		}

	if (!$validated) {
		# Check if this path allows unauthenticated access
		local ($u, $unauth);
		foreach $u (@unauth) {
			$unauth++ if ($simple =~ /$u/);
			}
		if (!$bogus && $unauth) {
			# Unauthenticated directory or file request - approve it
			$validated = 4;
			$baseauthuser = $authuser = undef;
			}
		}

	if (!$validated) {
		if ($blocked == 0) {
			# No password given.. ask
			if ($config{'pam_conv'} && $use_pam) {
				# Force CGI for PAM question, starting with
				# the username which is always needed
				$validated = 1;
				$method = "GET";
				$querystring .= "&initial=1&question=".
						&urlize("Username");
				$querystring .= "&failed=$failed_user" if ($failed_user);
				$querystring .= "&timed_out=$timed_out" if ($timed_out);
				$queryargs = "";
				$page = $config{'pam_login'};
				$miniserv_internal = 1;
				$logged_code = 401;
				}
			elsif ($config{'session'}) {
				# Force CGI for session login
				$validated = 1;
				if ($logout) {
					$querystring .= "&logout=1&page=/";
					}
				else {
					# Re-direct to current module only
					local $rpage = $request_uri;
					if (!$config{'loginkeeppage'}) {
						$rpage =~ s/\?.*$//;
						$rpage =~ s/[^\/]+$//
						}
					$querystring = "page=".&urlize($rpage);
					}
				$method = "GET";
				$querystring .= "&failed=$failed_user"
					if ($failed_user);
				$querystring .= "&twofactor_msg=".&urlize($twofactor_msg)
					if ($twofactor_msg);
				$querystring .= "&timed_out=$timed_out"
					if ($timed_out);
				$queryargs = "";
				$page = $config{'session_login'};
				$miniserv_internal = 1;
				$logged_code = 401;
				}
			else {
				# Ask for login with HTTP authentication
				&write_data("HTTP/1.0 401 Unauthorized\r\n");
				&write_data("Date: $datestr\r\n");
				&write_data("Server: $config{'server'}\r\n");
				&write_data("WWW-authenticate: Basic ".
					   "realm=\"$config{'realm'}\"\r\n");
				&write_keep_alive(0);
				&write_data("Content-type: text/html; Charset=iso-8859-1\r\n");
				&write_data("\r\n");
				&reset_byte_count();
				&write_data("<html>\n");
				&write_data("<head><title>Unauthorized</title></head>\n");
				&write_data("<body><h1>Unauthorized</h1>\n");
				&write_data("A password is required to access this\n");
				&write_data("web server. Please try again. <p>\n");
				&write_data("</body></html>\n");
				&log_request($loghost, undef, $reqline, 401, &byte_count());
				return 0;
				}
			}
		elsif ($blocked == 1) {
			# when the host has been blocked, give it an error
			&http_error(403, "Access denied for $acptip. The host ".
					 "has been blocked because of too ".
					 "many authentication failures.");
			}
		elsif ($blocked == 2) {
			# when the user has been blocked, give it an error
			&http_error(403, "Access denied. The user ".
					 "has been blocked because of too ".
					 "many authentication failures.");
			}
		}
	else {
		# Get the real Webmin username
		local @can = &can_user_login($authuser, undef, $host);
		$baseauthuser = $can[3] || $authuser;

		if ($config{'remoteuser'} && !$< && $validated) {
			# Switch to the UID of the remote user (if he exists)
			local @u = getpwnam($authuser);
			if (@u && $< != $u[2]) {
				$( = $u[3]; $) = "$u[3] $u[3]";
				($>, $<) = ($u[2], $u[2]);
				}
			else {
				&http_error(500, "Unix user ".
				  &html_strip($authuser)." does not exist");
				return 0;
				}
			}
		}

	# Check per-user IP access control
	if (!&check_user_ip($baseauthuser)) {
		&http_error(403, "Access denied for $acptip for ".
				 &html_strip($baseauthuser));
		return 0;
		}

	# Check per-user allowed times
	if (!&check_user_time($baseauthuser)) {
		&http_error(403, "Access denied at the current time");
		return 0;
		}
	}
$uinfo = &get_user_details($baseauthuser);

# Validate the path, and convert to canonical form
rerun:
$simple = &simplify_path($page, $bogus);
print DEBUG "handle_request: page=$page simple=$simple\n";
if ($bogus) {
	&http_error(400, "Invalid path");
	}

# Check for a DAV request
if ($davpath) {
	return &handle_dav_request($davpath);
	}

# Work out the active theme(s)
local $preroots = $mobile_device && defined($config{'mobile_preroot'}) ?
			$config{'mobile_preroot'} :
		 $authuser && defined($config{'preroot_'.$authuser}) ?
			$config{'preroot_'.$authuser} :
	         $uinfo && defined($uinfo->{'preroot'}) ?
			$uinfo->{'preroot'} :
			$config{'preroot'};
local @preroots = reverse(split(/\s+/, $preroots));

# Canonicalize the directories
foreach my $preroot (@preroots) {
	# Always under the current webmin root
	$preroot =~ s/^.*\///g;
	$preroot = $roots[0].'/'.$preroot;
	}

# Look in the theme root directories first
local ($full, @stfull);
$foundroot = undef;
foreach my $preroot (@preroots) {
	$is_directory = 1;
	$sofar = "";
	$full = $preroot.$sofar;
	$scriptname = $simple;
	foreach $b (split(/\//, $simple)) {
		if ($b ne "") { $sofar .= "/$b"; }
		$full = $preroot.$sofar;
		@stfull = stat($full);
		if (!@stfull) { undef($full); last; }

		# Check if this is a directory
		if (-d _) {
			# It is.. go on parsing
			$is_directory = 1;
			next;
			}
		else {
			$is_directory = 0;
			}

		# Check if this is a CGI program
		if (&get_type($full) eq "internal/cgi") {
			$pathinfo = substr($simple, length($sofar));
			$pathinfo .= "/" if ($page =~ /\/$/);
			$scriptname = $sofar;
			last;
			}
		}

	# Don't stop at a directory unless this is the last theme, which
	# is the 'real' one that provides the .cgi scripts
	if ($is_directory && $preroot ne $preroots[$#preroots]) {
		next;
		}

	if ($full) {
		# Found it!
		if ($sofar eq '') {
			$cgi_pwd = $roots[0];
			}
		elsif ($is_directory) {
			$cgi_pwd = "$roots[0]$sofar";
			}
		else {
			"$roots[0]$sofar" =~ /^(.*\/)[^\/]+$/;
			$cgi_pwd = $1;
			}
		$foundroot = $preroot;
		if ($is_directory) {
			# Check for index files in the directory
			local $foundidx;
			foreach $idx (split(/\s+/, $config{"index_docs"})) {
				$idxfull = "$full/$idx";
				local @stidxfull = stat($idxfull);
				if (-r _ && !-d _) {
					$full = $idxfull;
					@stfull = @stidxfull;
					$is_directory = 0;
					$scriptname .= "/"
						if ($scriptname ne "/");
					$foundidx++;
					last;
					}
				}
			@stfull = stat($full) if (!$foundidx);
			}
		}
	last if ($foundroot);
	}
print DEBUG "handle_request: initial full=$full\n";

# Look in the real root directories, stopping when we find a file or directory
if (!$full || $is_directory) {
	ROOT: foreach $root (@roots) {
		$sofar = "";
		$full = $root.$sofar;
		$scriptname = $simple;
		foreach $b ($simple eq "/" ? ( "" ) : split(/\//, $simple)) {
			if ($b ne "") { $sofar .= "/$b"; }
			$full = $root.$sofar;
			@stfull = stat($full);
			if (!@stfull) {
				next ROOT;
				}

			# Check if this is a directory
			if (-d _) {
				# It is.. go on parsing
				next;
				}

			# Check if this is a CGI program
			if (&get_type($full) eq "internal/cgi") {
				$pathinfo = substr($simple, length($sofar));
				$pathinfo .= "/" if ($page =~ /\/$/);
				$scriptname = $sofar;
				last;
				}
			}

		# Run CGI in the same directory as whatever file
		# was requested
		$full =~ /^(.*\/)[^\/]+$/; $cgi_pwd = $1;

		if (-e $full) {
			# Found something!
			$realroot = $root;
			$foundroot = $root;
			last;
			}
		}
	if (!@stfull) { &http_error(404, "File not found"); }
	}
print DEBUG "handle_request: full=$full\n";
@stfull = stat($full) if (!@stfull);

# check filename against denyfile regexp
local $denyfile = $config{'denyfile'};
if ($denyfile && $full =~ /$denyfile/) {
	&http_error(403, "Access denied to ".&html_strip($page));
	return 0;
	}

# Reached the end of the path OK.. see what we've got
if (-d _) {
	# See if the URL ends with a / as it should
	print DEBUG "handle_request: found a directory\n";
	if ($page !~ /\/$/) {
		# It doesn't.. redirect
		&write_data("HTTP/1.0 302 Moved Temporarily\r\n");
		$ssl = $use_ssl || $config{'inetd_ssl'};
		$portstr = $port == 80 && !$ssl ? "" :
			   $port == 443 && $ssl ? "" : ":$port";
		&write_data("Date: $datestr\r\n");
		&write_data("Server: $config{server}\r\n");
		$prot = $ssl ? "https" : "http";
		&write_data("Location: $prot://$hostport$page/\r\n");
		&write_keep_alive(0);
		&write_data("\r\n");
		&log_request($loghost, $authuser, $reqline, 302, 0);
		return 0;
		}
	# A directory.. check for index files
	local $foundidx;
	foreach $idx (split(/\s+/, $config{"index_docs"})) {
		$idxfull = "$full/$idx";
		@stidxfull = stat($idxfull);
		if (-r _ && !-d _) {
			$cgi_pwd = $full;
			$full = $idxfull;
			@stfull = @stidxfull;
			$scriptname .= "/" if ($scriptname ne "/");
			$foundidx++;
			last;
			}
		}
	@stfull = stat($full) if (!$foundidx);
	}
if (-d _) {
	# This is definitely a directory.. list it
	print DEBUG "handle_request: listing directory\n";
	local $resp = "HTTP/1.0 $ok_code $ok_message\r\n".
		      "Date: $datestr\r\n".
		      "Server: $config{server}\r\n".
		      "Content-type: text/html; Charset=iso-8859-1\r\n";
	&write_data($resp);
	&write_keep_alive(0);
	&write_data("\r\n");
	&reset_byte_count();
	&write_data("<h1>Index of $simple</h1>\n");
	&write_data("<pre>\n");
	&write_data(sprintf "%-35.35s %-20.20s %-10.10s\n",
			"Name", "Last Modified", "Size");
	&write_data("<hr>\n");
	opendir(DIR, $full);
	while($df = readdir(DIR)) {
		if ($df =~ /^\./) { next; }
		$fulldf = $full eq "/" ? $full.$df : $full."/".$df;
		(@stbuf = stat($fulldf)) || next;
		if (-d _) { $df .= "/"; }
		@tm = localtime($stbuf[9]);
		$fdate = sprintf "%2.2d/%2.2d/%4.4d %2.2d:%2.2d:%2.2d",
				$tm[3],$tm[4]+1,$tm[5]+1900,
				$tm[0],$tm[1],$tm[2];
		$len = length($df); $rest = " "x(35-$len);
		&write_data(sprintf 
		 "<a href=\"%s\">%-${len}.${len}s</a>$rest %-20.20s %-10.10s\n",
		 &urlize($df), &html_strip($df), $fdate, $stbuf[7]);
		}
	closedir(DIR);
	&log_request($loghost, $authuser, $reqline, $ok_code, &byte_count());
	return 0;
	}

# CGI or normal file
local $rv;
if (&get_type($full) eq "internal/cgi" && $validated != 4) {
	# A CGI program to execute
	print DEBUG "handle_request: executing CGI\n";
	$envtz = $ENV{"TZ"};
	$envuser = $ENV{"USER"};
	$envpath = $ENV{"PATH"};
	$envlang = $ENV{"LANG"};
	$envroot = $ENV{"SystemRoot"};
	$envperllib = $ENV{'PERLLIB'};
	foreach my $k (keys %ENV) {
		delete($ENV{$k});
		}
	$ENV{"PATH"} = $envpath if ($envpath);
	$ENV{"TZ"} = $envtz if ($envtz);
	$ENV{"USER"} = $envuser if ($envuser);
	$ENV{"OLD_LANG"} = $envlang if ($envlang);
	$ENV{"SystemRoot"} = $envroot if ($envroot);
	$ENV{'PERLLIB'} = $envperllib if ($envperllib);
	$ENV{"HOME"} = $user_homedir;
	$ENV{"SERVER_SOFTWARE"} = $config{"server"};
	$ENV{"SERVER_NAME"} = $host;
	$ENV{"SERVER_ADMIN"} = $config{"email"};
	$ENV{"SERVER_ROOT"} = $roots[0];
	$ENV{"SERVER_REALROOT"} = $realroot;
	$ENV{"SERVER_PORT"} = $port;
	$ENV{"REMOTE_HOST"} = $acpthost;
	$ENV{"REMOTE_ADDR"} = $acptip;
	$ENV{"REMOTE_ADDR_PROTOCOL"} = $ipv6 ? 6 : 4;
	$ENV{"REMOTE_USER"} = $authuser;
	$ENV{"BASE_REMOTE_USER"} = $authuser ne $baseauthuser ?
					$baseauthuser : undef;
	$ENV{"REMOTE_PASS"} = $authpass if (defined($authpass) &&
					    $config{'pass_password'});
	if ($uinfo && $uinfo->{'proto'}) {
		$ENV{"REMOTE_USER_PROTO"} = $uinfo->{'proto'};
		$ENV{"REMOTE_USER_ID"} = $uinfo->{'id'};
		}
	print DEBUG "REMOTE_USER = ",$ENV{"REMOTE_USER"},"\n";
	print DEBUG "BASE_REMOTE_USER = ",$ENV{"BASE_REMOTE_USER"},"\n";
	print DEBUG "proto=$uinfo->{'proto'} id=$uinfo->{'id'}\n" if ($uinfo);
	$ENV{"SSL_USER"} = $peername if ($validated == 2);
	$ENV{"ANONYMOUS_USER"} = "1" if ($validated == 3 || $validated == 4);
	$ENV{"DOCUMENT_ROOT"} = $roots[0];
	$ENV{"DOCUMENT_REALROOT"} = $realroot;
	$ENV{"GATEWAY_INTERFACE"} = "CGI/1.1";
	$ENV{"SERVER_PROTOCOL"} = "HTTP/1.0";
	$ENV{"REQUEST_METHOD"} = $method;
	$ENV{"SCRIPT_NAME"} = $scriptname;
	$ENV{"SCRIPT_FILENAME"} = $full;
	$ENV{"REQUEST_URI"} = $request_uri;
	$ENV{"PATH_INFO"} = $pathinfo;
	if ($pathinfo) {
		$ENV{"PATH_TRANSLATED"} = "$roots[0]$pathinfo";
		$ENV{"PATH_REALTRANSLATED"} = "$realroot$pathinfo";
		}
	$ENV{"QUERY_STRING"} = $querystring;
	$ENV{"MINISERV_CONFIG"} = $config_file;
	$ENV{"HTTPS"} = $use_ssl || $config{'inetd_ssl'} ? "ON" : "";
	$ENV{"MINISERV_PID"} = $miniserv_main_pid;
	$ENV{"SESSION_ID"} = $session_id if ($session_id);
	$ENV{"LOCAL_USER"} = $localauth_user if ($localauth_user);
	$ENV{"MINISERV_INTERNAL"} = $miniserv_internal if ($miniserv_internal);
	if (defined($header{"content-length"})) {
		$ENV{"CONTENT_LENGTH"} = $header{"content-length"};
		}
	if (defined($header{"content-type"})) {
		$ENV{"CONTENT_TYPE"} = $header{"content-type"};
		}
	foreach $h (keys %header) {
		($hname = $h) =~ tr/a-z/A-Z/;
		$hname =~ s/\-/_/g;
		$ENV{"HTTP_$hname"} = $header{$h};
		}
	$ENV{"PWD"} = $cgi_pwd;
	foreach $k (keys %config) {
		if ($k =~ /^env_(\S+)$/) {
			$ENV{$1} = $config{$k};
			}
		}
	delete($ENV{'HTTP_AUTHORIZATION'});
	$ENV{'HTTP_COOKIE'} =~ s/;?\s*$sidname=([a-f0-9]+)//;
	$ENV{'MOBILE_DEVICE'} = 1 if ($mobile_device);

	# Check if the CGI can be handled internally
	open(CGI, $full);
	local $first = <CGI>;
	close(CGI);
	$first =~ s/[#!\r\n]//g;
	$nph_script = ($full =~ /\/nph-([^\/]+)$/);
	seek(STDERR, 0, 2);
	if (!$config{'forkcgis'} &&
	    ($first eq $perl_path || $first eq $linked_perl_path ||
	     $first =~ /\/perl$/ || $first =~ /^\/\S+\/env\s+perl$/) &&
	      $] >= 5.004 ||
            $config{'internalcgis'}) {
		# setup environment for eval
		chdir($ENV{"PWD"});
		@ARGV = split(/\s+/, $queryargs);
		$0 = $full;
		if ($posted_data) {
			# Already read the post input
			$postinput = $posted_data;
			}
		$clen = $header{"content-length"};
		$SIG{'CHLD'} = 'DEFAULT';
		eval {
			# Have SOCK closed if the perl exec's something
			use Fcntl;
			fcntl(SOCK, F_SETFD, FD_CLOEXEC);
			};
		#shutdown(SOCK, 0);

		if ($config{'log'}) {
			open(MINISERVLOG, ">>$config{'logfile'}");
			if ($config{'logperms'}) {
				chmod(oct($config{'logperms'}),
				      $config{'logfile'});
				}
			else {
				chmod(0600, $config{'logfile'});
				}
			}
		$doing_cgi_eval = 1;
		$main_process_id = $$;
		$pkg = "main";
		if ($full =~ /^\Q$foundroot\E\/([^\/]+)\//) {
			# Eval in package from Webmin module name
			$pkg = $1;
			$pkg =~ s/[^A-Za-z0-9]/_/g;
			}
		eval "
			\%pkg::ENV = \%ENV;
			package $pkg;
			tie(*STDOUT, 'miniserv');
			tie(*STDIN, 'miniserv');
			do \$miniserv::full;
			die \$@ if (\$@);
			";
		$doing_cgi_eval = 0;
		if ($@) {
			# Error in perl!
			&http_error(500, "Perl execution failed",
				    $config{'noshowstderr'} ? undef : $@);
			}
		elsif (!$doneheaders && !$nph_script) {
			&http_error(500, "Missing Headers");
			}
		$rv = 0;
		}
	else {
		$infile = undef;
		if (!$on_windows) {
			# fork the process that actually executes the CGI
			pipe(CGIINr, CGIINw);
			pipe(CGIOUTr, CGIOUTw);
			pipe(CGIERRr, CGIERRw);
			if (!($cgipid = fork())) {
				@execargs = ( $full, split(/\s+/, $queryargs) );
				chdir($ENV{"PWD"});
				close(SOCK);
				open(STDIN, "<&CGIINr");
				open(STDOUT, ">&CGIOUTw");
				open(STDERR, ">&CGIERRw");
				close(CGIINw); close(CGIOUTr); close(CGIERRr);
				exec(@execargs) ||
					die "Failed to exec $full : $!\n";
				exit(0);
				}
			close(CGIINr); close(CGIOUTw); close(CGIERRw);
			}
		else {
			# write CGI input to a temp file
			$infile = "$config{'tempbase'}.$$";
			open(CGIINw, ">$infile");
			# NOT binary mode, as CGIs don't read in it!
			}

		# send post data
		if ($posted_data) {
			# already read the posted data
			print CGIINw $posted_data;
			}
		$clen = $header{"content-length"};
		if ($method eq "POST" && $clen_read < $clen) {
			$SIG{'PIPE'} = 'IGNORE';
			$got = $clen_read;
			while($got < $clen) {
				$buf = &read_data($clen-$got);
				if (!length($buf)) {
					kill('TERM', $cgipid);
					unlink($infile) if ($infile);
					&http_error(500, "Failed to read ".
							 "POST request");
					}
				$got += length($buf);
				local ($wrote) = (print CGIINw $buf);
				last if (!$wrote);
				}
			# If the CGI terminated early, we still need to read
			# from the browser and throw away
			while($got < $clen) {
				$buf = &read_data($clen-$got);
				if (!length($buf)) {
					kill('TERM', $cgipid);
					unlink($infile) if ($infile);
					&http_error(500, "Failed to read ".
							 "POST request");
					}
				$got += length($buf);
				}
			$SIG{'PIPE'} = 'DEFAULT';
			}
		close(CGIINw);
		shutdown(SOCK, 0);

		if ($on_windows) {
			# Run the CGI program, and feed it input
			chdir($ENV{"PWD"});
			local $qqueryargs = join(" ", map { "\"$_\"" }
						 split(/\s+/, $queryargs));
			if ($first =~ /(perl|perl.exe)$/i) {
				# On Windows, run with Perl
				open(CGIOUTr, "$perl_path \"$full\" $qqueryargs <$infile |");
				}
			else {
				open(CGIOUTr, "\"$full\" $qqueryargs <$infile |");
				}
			binmode(CGIOUTr);
			}

		if (!$nph_script) {
			# read back cgi headers
			select(CGIOUTr); $|=1; select(STDOUT);
			$got_blank = 0;
			while(1) {
				$line = <CGIOUTr>;
				$line =~ s/\r|\n//g;
				if ($line eq "") {
					if ($got_blank || %cgiheader) { last; }
					$got_blank++;
					next;
					}
				if ($line !~ /^(\S+):\s+(.*)$/) {
					$errs = &read_errors(CGIERRr);
					close(CGIOUTr); close(CGIERRr);
					unlink($infile) if ($infile);
					&http_error(500, "Bad Header", $errs);
					}
				$cgiheader{lc($1)} = $2;
				push(@cgiheader, [ $1, $2 ]);
				}
			if ($cgiheader{"location"}) {
				&write_data("HTTP/1.0 302 Moved Temporarily\r\n");
				&write_data("Date: $datestr\r\n");
				&write_data("Server: $config{'server'}\r\n");
				&write_keep_alive(0);
				# ignore the rest of the output. This is a hack,
				# but is necessary for IE in some cases :(
				close(CGIOUTr); close(CGIERRr);
				}
			elsif ($cgiheader{"content-type"} eq "") {
				close(CGIOUTr); close(CGIERRr);
				unlink($infile) if ($infile);
				$errs = &read_errors(CGIERRr);
				&http_error(500, "Missing Content-Type Header",
				    $config{'noshowstderr'} ? undef : $errs);
				}
			else {
				&write_data("HTTP/1.0 $ok_code $ok_message\r\n");
				&write_data("Date: $datestr\r\n");
				&write_data("Server: $config{'server'}\r\n");
				&write_keep_alive(0);
				}
			foreach $h (@cgiheader) {
				&write_data("$h->[0]: $h->[1]\r\n");
				}
			&write_data("\r\n");
			}
		&reset_byte_count();
		while($line = <CGIOUTr>) {
			&write_data($line);
			}
		close(CGIOUTr);
		close(CGIERRr);
		unlink($infile) if ($infile);
		$rv = 0;
		}
	}
else {
	# A file to output
	print DEBUG "handle_request: outputting file $full\n";
	$gzfile = $full.".gz";
	$gzipped = 0;
	if ($config{'gzip'} ne '0' && -r $gzfile && $acceptenc{'gzip'}) {
		# Using gzipped version
		@stopen = stat($gzfile);
		if ($stopen[9] >= $stfull[9] && open(FILE, $gzfile)) {
			print DEBUG "handle_request: using gzipped $gzfile\n";
			$gzipped = 1;
			}
		}
	if (!$gzipped) {
		# Using original file
		@stopen = @stfull;
		open(FILE, $full) || &http_error(404, "Failed to open file");
		}
	binmode(FILE);

	# Build common headers
	local $etime = &get_expires_time($simple);
	local $resp = "HTTP/1.0 $ok_code $ok_message\r\n".
		      "Date: $datestr\r\n".
		      "Server: $config{server}\r\n".
		      "Content-type: ".&get_type($full)."\r\n".
		      "Last-Modified: ".&http_date($stopen[9])."\r\n".
		      "Expires: ".&http_date(time()+$etime)."\r\n".
		      "Cache-Control: public; max-age=".$etime."\r\n";

	if (!$gzipped && $use_gzip && $acceptenc{'gzip'} &&
	    &should_gzip_file($full)) {
		# Load and compress file, then output
		print DEBUG "handle_request: outputting gzipped file $full\n";
		open(FILE, $full) || &http_error(404, "Failed to open file");
		{
			local $/ = undef;
			$data = <FILE>;
		}
		close(FILE);
		@stopen = stat($file);
		$data = Compress::Zlib::memGzip($data);
		$resp .= "Content-length: ".length($data)."\r\n".
			 "Content-Encoding: gzip\r\n";
		&write_data($resp);
		$rv = &write_keep_alive();
		&write_data("\r\n");
		&reset_byte_count();
		&write_data($data);
		}
	else {
		# Stream file output
		$resp .= "Content-length: $stopen[7]\r\n";
		$resp .= "Content-Encoding: gzip\r\n" if ($gzipped);
		&write_data($resp);
		$rv = &write_keep_alive();
		&write_data("\r\n");
		&reset_byte_count();
		my $bufsize = $config{'bufsize'} || 1024;
		while(read(FILE, $buf, $bufsize) > 0) {
			&write_data($buf);
			}
		close(FILE);
		}
	}

# log the request
&log_request($loghost, $authuser, $reqline,
	     $logged_code ? $logged_code :
	     $cgiheader{"location"} ? "302" : $ok_code, &byte_count());
return $rv;
}

# http_error(code, message, body, [dontexit])
sub http_error
{
local $eh = $error_handler_recurse ? undef :
	    $config{"error_handler_$_[0]"} ? $config{"error_handler_$_[0]"} :
	    $config{'error_handler'} ? $config{'error_handler'} : undef;
print DEBUG "http_error code=$_[0] message=$_[1] body=$_[2]\n";
if ($eh) {
	# Call a CGI program for the error
	$page = "/$eh";
	$querystring = "code=$_[0]&message=".&urlize($_[1]).
		       "&body=".&urlize($_[2]);
	$error_handler_recurse++;
	$ok_code = $_[0];
	$ok_message = $_[1];
	goto rerun;
	}
else {
	# Use the standard error message display
	&write_data("HTTP/1.0 $_[0] $_[1]\r\n");
	&write_data("Server: $config{server}\r\n");
	&write_data("Date: $datestr\r\n");
	&write_data("Content-type: text/html; Charset=iso-8859-1\r\n");
	&write_keep_alive(0);
	&write_data("\r\n");
	&reset_byte_count();
	&write_data("<h1>Error - $_[1]</h1>\n");
	if ($_[2]) {
		&write_data("<p>$_[2]</p>\n");
		}
	}
&log_request($loghost, $authuser, $reqline, $_[0], &byte_count())
	if ($reqline);
&log_error($_[1], $_[2] ? " : $_[2]" : "");
shutdown(SOCK, 1);
exit if (!$_[3]);
}

sub get_type
{
if ($_[0] =~ /\.([A-z0-9]+)$/) {
	$t = $mime{$1};
	if ($t ne "") {
		return $t;
		}
	}
return "text/plain";
}

# simplify_path(path, bogus)
# Given a path, maybe containing stuff like ".." and "." convert it to a
# clean, absolute form.
sub simplify_path
{
local($dir, @bits, @fixedbits, $b);
$dir = $_[0];
$dir =~ s/\\/\//g;	# fix windows \ in path
$dir =~ s/^\/+//g;
$dir =~ s/\/+$//g;
$dir =~ s/\0//g;	# remove null bytes
@bits = split(/\/+/, $dir);
@fixedbits = ();
$_[1] = 0;
foreach $b (@bits) {
        if ($b eq ".") {
                # Do nothing..
                }
        elsif ($b eq ".." || $b eq "...") {
                # Remove last dir
                if (scalar(@fixedbits) == 0) {
                        $_[1] = 1;
                        return "/";
                        }
                pop(@fixedbits);
                }
        else {
                # Add dir to list
                push(@fixedbits, $b);
                }
        }
return "/" . join('/', @fixedbits);
}

# b64decode(string)
# Converts a string from base64 format to normal
sub b64decode
{
    local($str) = $_[0];
    local($res);
    $str =~ tr|A-Za-z0-9+=/||cd;
    $str =~ s/=+$//;
    $str =~ tr|A-Za-z0-9+/| -_|;
    while ($str =~ /(.{1,60})/gs) {
        my $len = chr(32 + length($1)*3/4);
        $res .= unpack("u", $len . $1 );
    }
    return $res;
}

# ip_match(remoteip, localip, [match]+)
# Checks an IP address against a list of IPs, networks and networks/masks
sub ip_match
{
local(@io, @mo, @ms, $i, $j, $hn, $needhn);
@io = &check_ip6address($_[0]) ? split(/:/, $_[0])
			       : split(/\./, $_[0]);
for($i=2; $i<@_; $i++) {
	$needhn++ if ($_[$i] =~ /^\*(\S+)$/);
	}
if ($needhn && !defined($hn = $ip_match_cache{$_[0]})) {
	# Reverse-lookup hostname if any rules match based on it
	$hn = &to_hostname($_[0]);
	if (&check_ip6address($_[0])) {
		$hn = "" if (&to_ip6address($hn) ne $_[0]);
		}
	else {
		$hn = "" if (&to_ipaddress($hn) ne $_[0]);
		}
	$ip_match_cache{$_[0]} = $hn;
	}
for($i=2; $i<@_; $i++) {
	local $mismatch = 0;
	if ($_[$i] =~ /^([0-9\.]+)\/(\d+)$/) {
		# Convert CIDR to netmask format
		$_[$i] = $1."/".&prefix_to_mask($2);
		}
	if ($_[$i] =~ /^([0-9\.]+)\/([0-9\.]+)$/) {
		# Compare with IPv4 network/mask
		@mo = split(/\./, $1);
		@ms = split(/\./, $2);
		for($j=0; $j<4; $j++) {
			if ((int($io[$j]) & int($ms[$j])) != (int($mo[$j]) & int($ms[$j]))) {
				$mismatch = 1;
				}
			}
		}
	elsif ($_[$i] =~ /^([0-9\.]+)-([0-9\.]+)$/) {
		# Compare with an IPv4 range (separated by a hyphen -)
		local ($remote, $min, $max);
		local @low = split(/\./, $1);
		local @high = split(/\./, $2);
		for($j=0; $j<4; $j++) {
			$remote += $io[$j] << ((3-$j)*8);
			$min += $low[$j] << ((3-$j)*8);
			$max += $high[$j] << ((3-$j)*8);
			}
		if ($remote < $min || $remote > $max) {
			$mismatch = 1;
			}
		}
	elsif ($_[$i] =~ /^\*(\S+)$/) {
		# Compare with hostname regexp
		$mismatch = 1 if ($hn !~ /^.*\Q$1\E$/i);
		}
	elsif ($_[$i] eq 'LOCAL' && &check_ipaddress($_[1])) {
		# Compare with local IPv4 network
		local @lo = split(/\./, $_[1]);
		if ($lo[0] < 128) {
			$mismatch = 1 if ($lo[0] != $io[0]);
			}
		elsif ($lo[0] < 192) {
			$mismatch = 1 if ($lo[0] != $io[0] ||
					  $lo[1] != $io[1]);
			}
		else {
			$mismatch = 1 if ($lo[0] != $io[0] ||
					  $lo[1] != $io[1] ||
					  $lo[2] != $io[2]);
			}
		}
	elsif ($_[$i] eq 'LOCAL' && &check_ip6address($_[1])) {
		# Compare with local IPv6 network, which is always first 4 words
		local @lo = split(/:/, $_[1]);
		for(my $i=0; $i<4; $i++) {
			$mismatch = 1 if ($lo[$i] ne $io[$i]);
			}
		}
	elsif ($_[$i] =~ /^[0-9\.]+$/) {
		# Compare with a full or partial IPv4 address
		@mo = split(/\./, $_[$i]);
		while(@mo && !$mo[$#mo]) { pop(@mo); }
		for($j=0; $j<@mo; $j++) {
			if ($mo[$j] != $io[$j]) {
				$mismatch = 1;
				}
			}
		}
	elsif ($_[$i] =~ /^[a-f0-9:]+$/) {
		# Compare with a full IPv6 address
		if (&canonicalize_ip6($_[$i]) ne canonicalize_ip6($_[0])) {
			$mismatch = 1;
			}
		}
	elsif ($_[$i] =~ /^([a-f0-9:]+)\/(\d+)$/) {
		# Compare with an IPv6 network
		local $v6size = $2;
		local $v6addr = &canonicalize_ip6($1);
		local $bytes = $v6size / 8;
		@mo = &expand_ipv6_bytes($v6addr);
		local @io6 = &expand_ipv6_bytes(&canonicalize_ip6($_[0]));
		for($j=0; $j<$bytes; $j++) {
			if ($mo[$j] ne $io6[$j]) {
				$mismatch = 1;
				}
			}
		}
	elsif ($_[$i] !~ /^[0-9\.]+$/) {
		# Compare with hostname
		$mismatch = 1 if ($_[0] ne &to_ipaddress($_[$i]));
		}
	return 1 if (!$mismatch);
	}
return 0;
}

# users_match(&uinfo, user, ...)
# Returns 1 if a user is in a list of users and groups
sub users_match
{
local $uinfo = shift(@_);
local $u;
local @ginfo = getgrgid($uinfo->[3]);
foreach $u (@_) {
	if ($u =~ /^\@(\S+)$/) {
		return 1 if (&is_group_member($uinfo, $1));
		}
	elsif ($u =~ /^(\d*)-(\d*)$/ && ($1 || $2)) {
		return (!$1 || $uinfo[2] >= $1) &&
		       (!$2 || $uinfo[2] <= $2);
		}
	else {
		return 1 if ($u eq $uinfo->[0]);
		}
	}
return 0;
}

# restart_miniserv()
# Called when a SIGHUP is received to restart the web server. This is done
# by exec()ing perl with the same command line as was originally used
sub restart_miniserv
{
print STDERR "restarting miniserv\n";
&log_error("Restarting");
close(SOCK);
&close_all_sockets();
&close_all_pipes();
dbmclose(%sessiondb);
kill('KILL', $logclearer) if ($logclearer);
kill('KILL', $extauth) if ($extauth);
exec($perl_path, $miniserv_path, @miniserv_argv);
die "Failed to restart miniserv with $perl_path $miniserv_path";
}

sub trigger_restart
{
$need_restart = 1;
}

sub trigger_reload
{
$need_reload = 1;
}

# to_ip46address(address, ...)
# Convert hostnames to v4 and v6 addresses, if possible
sub to_ip46address
{
local @rv;
foreach my $i (@_) {
	if (&check_ipaddress($i) || &check_ip6address($i)) {
		push(@rv, $i);
		}
	else {
		my $addr = &to_ipaddress($i);
		$addr ||= &to_ip6address($i);
		push(@rv, $addr) if ($addr);
		}
	}
return @rv;
}

# to_ipaddress(address, ...)
sub to_ipaddress
{
local (@rv, $i);
foreach $i (@_) {
	if ($i =~ /(\S+)\/(\S+)/ || $i =~ /^\*\S+$/ ||
	    $i eq 'LOCAL' || $i =~ /^[0-9\.]+$/ || $i =~ /^[a-f0-9:]+$/) {
		# A pattern or IP, not a hostname, so don't change
		push(@rv, $i);
		}
	else {
		# Lookup IP address
		push(@rv, join('.', unpack("CCCC", inet_aton($i))));
		}
	}
return wantarray ? @rv : $rv[0];
}

# to_ip6address(address, ...)
sub to_ip6address
{
local (@rv, $i);
foreach $i (@_) {
	if ($i =~ /(\S+)\/(\S+)/ || $i =~ /^\*\S+$/ ||
	    $i eq 'LOCAL' || $i =~ /^[0-9\.]+$/ || $i =~ /^[a-f0-9:]+$/) {
		# A pattern, not a hostname, so don't change
		push(@rv, $i);
		}
	elsif ($config{'ipv6'}) {
		# Lookup IPv6 address
		local ($inaddr, $addr);
		eval {
			(undef, undef, undef, $inaddr) =
			    getaddrinfo($i, undef, AF_INET6(), SOCK_STREAM);
			};
		if ($inaddr) {
			push(@rv, undef);
			}
		else {
			(undef, $addr) = unpack_sockaddr_in6($inaddr);
			push(@rv, inet_ntop(AF_INET6(), $addr));
			}
		}
	}
return wantarray ? @rv : $rv[0];
}

# to_hostname(ipv4|ipv6-address)
# Reverse-resolves an IPv4 or 6 address to a hostname
sub to_hostname
{
local ($addr) = @_;
if (&check_ip6address($_[0])) {
	return gethostbyaddr(inet_pton(AF_INET6(), $addr),
			     AF_INET6());
	}
else {
	return gethostbyaddr(inet_aton($addr), AF_INET);
	}
}

# read_line(no-wait, no-limit)
# Reads one line from SOCK or SSL
sub read_line
{
local ($nowait, $nolimit) = @_;
local($idx, $more, $rv);
while(($idx = index($main::read_buffer, "\n")) < 0) {
	if (length($main::read_buffer) > 100000 && !$nolimit) {
		&http_error(414, "Request too long",
		    "Received excessive line <pre>".&html_strip($main::read_buffer)."</pre>");
		}

	# need to read more..
	&wait_for_data_error() if (!$nowait);
	if ($use_ssl) {
		$more = Net::SSLeay::read($ssl_con);
		}
	else {
		my $bufsize = $config{'bufsize'} || 1024;
                local $ok = sysread(SOCK, $more, $bufsize);
		$more = undef if ($ok <= 0);
		}
	if ($more eq '') {
		# end of the data
		$rv = $main::read_buffer;
		undef($main::read_buffer);
		return $rv;
		}
	$main::read_buffer .= $more;
	}
$rv = substr($main::read_buffer, 0, $idx+1);
$main::read_buffer = substr($main::read_buffer, $idx+1);
return $rv;
}

# read_data(length)
# Reads up to some amount of data from SOCK or the SSL connection
sub read_data
{
local ($rv);
if (length($main::read_buffer)) {
	if (length($main::read_buffer) > $_[0]) {
		# Return the first part of the buffer
		$rv = substr($main::read_buffer, 0, $_[0]);
		$main::read_buffer = substr($main::read_buffer, $_[0]);
		return $rv;
		}
	else {
		# Return the whole buffer
		$rv = $main::read_buffer;
		undef($main::read_buffer);
		return $rv;
		}
	}
elsif ($use_ssl) {
	# Call SSL read function
	return Net::SSLeay::read($ssl_con, $_[0]);
	}
else {
	# Just do a normal read
	local $buf;
	sysread(SOCK, $buf, $_[0]) || return undef;
	return $buf;
	}
}

# sysread_line(fh)
# Read a line from a file handle, using sysread to get a byte at a time
sub sysread_line
{
local ($fh) = @_;
local $line;
while(1) {
	local ($buf, $got);
	$got = sysread($fh, $buf, 1);
	last if ($got <= 0);
	$line .= $buf;
	last if ($buf eq "\n");
	}
return $line;
}

# wait_for_data(secs)
# Waits at most the given amount of time for some data on SOCK, returning
# 0 if not found, 1 if some arrived.
sub wait_for_data
{
local $rmask;
vec($rmask, fileno(SOCK), 1) = 1;
local $got = select($rmask, undef, undef, $_[0]);
return $got == 0 ? 0 : 1;
}

# wait_for_data_error()
# Waits 60 seconds for data on SOCK, and fails if none arrives
sub wait_for_data_error
{
local $got = &wait_for_data(60);
if (!$got) {
	&http_error(400, "Timeout",
		    "Waited more than 60 seconds for request data");
	}
}

# write_data(data, ...)
# Writes a string to SOCK or the SSL connection
sub write_data
{
local $str = join("", @_);
if ($use_ssl) {
	Net::SSLeay::write($ssl_con, $str);
	}
else {
	syswrite(SOCK, $str, length($str));
	}
# Intentionally introduce a small delay to avoid problems where IE reports
# the page as empty / DNS failed when it get a large response too quickly!
select(undef, undef, undef, .01) if ($write_data_count%10 == 0);
$write_data_count += length($str);
}

# reset_byte_count()
sub reset_byte_count { $write_data_count = 0; }

# byte_count()
sub byte_count { return $write_data_count; }

# log_request(hostname, user, request, code, bytes)
# Write an HTTP request to the log file
sub log_request
{
local ($host, $user, $request, $code, $bytes) = @_;
foreach my $nolog (split(/\s+/, $config{'nolog'})) {
	return if ($request =~ /^$nolog$/);
	}
if ($config{'log'}) {
	local $ident = "-";
	$user ||= "-";
	local $dstr = &make_datestr();
	if (fileno(MINISERVLOG)) {
		seek(MINISERVLOG, 0, 2);
		}
	else {
		open(MINISERVLOG, ">>$config{'logfile'}");
		chmod(0600, $config{'logfile'});
		}
	if (defined($config{'logheaders'})) {
		foreach $h (split(/\s+/, $config{'logheaders'})) {
			$headers .= " $h=\"$header{$h}\"";
			}
		}
	elsif ($config{'logclf'}) {
		$headers = " \"$header{'referer'}\" \"$header{'user-agent'}\"";
		}
	else {
		$headers = "";
		}
	print MINISERVLOG "$host $ident $user [$dstr] \"$request\" ",
			  "$code $bytes$headers\n";
	close(MINISERVLOG);
	}
}

# make_datestr()
sub make_datestr
{
local @tm = localtime(time());
return sprintf "%2.2d/%s/%4.4d:%2.2d:%2.2d:%2.2d %s",
		$tm[3], $month[$tm[4]], $tm[5]+1900,
	        $tm[2], $tm[1], $tm[0], $timezone;
}

# log_error(message)
sub log_error
{
seek(STDERR, 0, 2);
print STDERR "[",&make_datestr(),"] ",
	$acpthost ? ( "[",$acpthost,"] " ) : ( ),
	$page ? ( $page," : " ) : ( ),
	@_,"\n";
}

# read_errors(handle)
# Read and return all input from some filehandle
sub read_errors
{
local($fh, $_, $rv);
$fh = $_[0];
while(<$fh>) { $rv .= $_; }
return $rv;
}

sub write_keep_alive
{
local $mode;
if ($config{'nokeepalive'}) {
	# Keep alives have been disabled in config
	$mode = 0;
	}
elsif (@childpids > $config{'maxconns'}*.8) {
	# Disable because nearing process limit
	$mode = 0;
	}
elsif (@_) {
	# Keep alive specified by caller
	$mode = $_[0];
	}
else {
	# Keep alive determined by browser
	$mode = $header{'connection'} =~ /keep-alive/i;
	}
&write_data("Connection: ".($mode ? "Keep-Alive" : "close")."\r\n");
return $mode;
}

sub term_handler
{
kill('TERM', @childpids) if (@childpids);
kill('KILL', $logclearer) if ($logclearer);
kill('KILL', $extauth) if ($extauth);
exit(1);
}

sub http_date
{
local @tm = gmtime($_[0]);
return sprintf "%s, %d %s %d %2.2d:%2.2d:%2.2d GMT",
		$weekday[$tm[6]], $tm[3], $month[$tm[4]], $tm[5]+1900,
		$tm[2], $tm[1], $tm[0];
}

sub TIEHANDLE
{
my $i; bless \$i, shift;
}
 
sub WRITE
{
$r = shift;
my($buf,$len,$offset) = @_;
&write_to_sock(substr($buf, $offset, $len));
$miniserv::page_capture_out .= substr($buf, $offset, $len)
	if ($miniserv::page_capture);
}
 
sub PRINT
{
$r = shift;
$$r++;
my $buf = join(defined($,) ? $, : "", @_);
$buf .= $\ if defined($\);
&write_to_sock($buf);
$miniserv::page_capture_out .= $buf
	if ($miniserv::page_capture);
}
 
sub PRINTF
{
shift;
my $fmt = shift;
my $buf = sprintf $fmt, @_;
&write_to_sock($buf);
$miniserv::page_capture_out .= $buf
	if ($miniserv::page_capture);
}
 
# Send back already read data while we have it, then read from SOCK
sub READ
{
my $r = shift;
my $bufref = \$_[0];
my $len = $_[1];
my $offset = $_[2];
if ($postpos < length($postinput)) {
	# Reading from already fetched array
	my $left = length($postinput) - $postpos;
	my $canread = $len > $left ? $left : $len;
	substr($$bufref, $offset, $canread) =
		substr($postinput, $postpos, $canread);
	$postpos += $canread;
	return $canread;
	}
else {
	# Read from network socket
	local $data = &read_data($len);
	if ($data eq '' && $len) {
		# End of socket
		shutdown(SOCK, 0);
		}
	substr($$bufref, $offset, length($data)) = $data;
	return length($data);
	}
}

sub OPEN
{
#print STDERR "open() called - should never happen!\n";
}
 
# Read a line of input
sub READLINE
{
my $r = shift;
if ($postpos < length($postinput) &&
    ($idx = index($postinput, "\n", $postpos)) >= 0) {
	# A line exists in the memory buffer .. use it
	my $line = substr($postinput, $postpos, $idx-$postpos+1);
	$postpos = $idx+1;
	return $line;
	}
else {
	# Need to read from the socket
	my $line;
	if ($postpos < length($postinput)) {
		# Start with in-memory data
		$line = substr($postinput, $postpos);
		$postpos = length($postinput);
		}
	my $nl = &read_line(0, 1);
	if ($nl eq '') {
		# End of socket
		shutdown(SOCK, 0);
		}
	$line .= $nl if (defined($nl));
	return $line;
	}
}
 
# Read one character of input
sub GETC
{
my $r = shift;
my $buf;
my $got = READ($r, \$buf, 1, 0);
return $got > 0 ? $buf : undef;
}

sub FILENO
{
return fileno(SOCK);
}
 
sub CLOSE { }
 
sub DESTROY { }

# write_to_sock(data, ...)
sub write_to_sock
{
local $d;
foreach $d (@_) {
	if ($doneheaders || $miniserv::nph_script) {
		&write_data($d);
		}
	else {
		$headers .= $d;
		while(!$doneheaders && $headers =~ s/^([^\r\n]*)(\r)?\n//) {
			if ($1 =~ /^(\S+):\s+(.*)$/) {
				$cgiheader{lc($1)} = $2;
				push(@cgiheader, [ $1, $2 ]);
				}
			elsif ($1 !~ /\S/) {
				$doneheaders++;
				}
			else {
				&http_error(500, "Bad Header");
				}
			}
		if ($doneheaders) {
			if ($cgiheader{"location"}) {
				&write_data(
					"HTTP/1.0 302 Moved Temporarily\r\n");
				&write_data("Date: $datestr\r\n");
				&write_data("Server: $config{server}\r\n");
				&write_keep_alive(0);
				}
			elsif ($cgiheader{"content-type"} eq "") {
				&http_error(500, "Missing Content-Type Header");
				}
			else {
				&write_data("HTTP/1.0 $ok_code $ok_message\r\n");
				&write_data("Date: $datestr\r\n");
				&write_data("Server: $config{server}\r\n");
				&write_keep_alive(0);
				}
			foreach $h (@cgiheader) {
				&write_data("$h->[0]: $h->[1]\r\n");
				}
			&write_data("\r\n");
			&reset_byte_count();
			&write_data($headers);
			}
		}
	}
}

sub verify_client
{
local $cert = Net::SSLeay::X509_STORE_CTX_get_current_cert($_[1]);
if ($cert) {
	local $errnum = Net::SSLeay::X509_STORE_CTX_get_error($_[1]);
	$verified_client = 1 if (!$errnum);
	}
return 1;
}

sub END
{
if ($doing_cgi_eval && $$ == $main_process_id) {
	# A CGI program called exit! This is a horrible hack to 
	# finish up before really exiting
	shutdown(SOCK, 1);
	close(SOCK);
	close($PASSINw); close($PASSOUTw);
	&log_request($loghost, $authuser, $reqline,
		     $cgiheader{"location"} ? "302" : $ok_code, &byte_count());
	}
}

# urlize
# Convert a string to a form ok for putting in a URL
sub urlize {
  local($tmp, $tmp2, $c);
  $tmp = $_[0];
  $tmp2 = "";
  while(($c = chop($tmp)) ne "") {
	if ($c !~ /[A-z0-9]/) {
		$c = sprintf("%%%2.2X", ord($c));
		}
	$tmp2 = $c . $tmp2;
	}
  return $tmp2;
}

# validate_user(username, password, host, remote-ip, webmin-port)
# Checks if some username and password are valid. Returns the modified username,
# the expired / temp pass flag, the non-existence flag, and the underlying
# Webmin username.
sub validate_user
{
local ($user, $pass, $host, $actpip, $port) = @_;
return ( ) if (!$user);
print DEBUG "validate_user: user=$user pass=$pass host=$host\n";
local ($canuser, $canmode, $notexist, $webminuser, $sudo) =
	&can_user_login($user, undef, $host);
print DEBUG "validate_user: canuser=$canuser canmode=$canmode notexist=$notexist webminuser=$webminuser sudo=$sudo\n";
if ($notexist) {
	# User doesn't even exist, so go no further
	return ( undef, 0, 1, $webminuser );
	}
elsif ($canmode == 0) {
	# User does exist but cannot login
	return ( $canuser, 0, 0, $webminuser );
	}
elsif ($canmode == 1) {
	# Attempt Webmin authentication
	my $uinfo = &get_user_details($webminuser);
	if ($uinfo &&
	    &password_crypt($pass, $uinfo->{'pass'}) eq $uinfo->{'pass'}) {
		# Password is valid .. but check for expiry
		local $lc = $uinfo->{'lastchanges'};
		print DEBUG "validate_user: Password is valid lc=$lc pass_maxdays=$config{'pass_maxdays'}\n";
		if ($config{'pass_maxdays'} && $lc && !$uinfo->{'nochange'}) {
			local $daysold = (time() - $lc)/(24*60*60);
			print DEBUG "maxdays=$config{'pass_maxdays'} daysold=$daysold temppass=$uinfo->{'temppass'}\n";
			if ($config{'pass_lockdays'} &&
			    $daysold > $config{'pass_lockdays'}) {
				# So old that the account is locked
				return ( undef, 0, 0, $webminuser );
				}
			elsif ($daysold > $config{'pass_maxdays'}) {
				# Password has expired
				return ( $user, 1, 0, $webminuser );
				}
			}
		if ($uinfo->{'temppass'}) {
			# Temporary password - force change now
			return ( $user, 2, 0, $webminuser );
			}
		return ( $user, 0, 0, $webminuser );
		}
	elsif (!$uinfo) {
		print DEBUG "validate_user: User $webminuser not found\n";
		return ( undef, 0, 0, $webminuser );
		}
	else {
		print DEBUG "validate_user: User $webminuser password mismatch $pass != $uinfo->{'pass'}\n";
		return ( undef, 0, 0, $webminuser );
		}
	}
elsif ($canmode == 2 || $canmode == 3) {
	# Attempt PAM or passwd file authentication
	local $val = &validate_unix_user($canuser, $pass, $acptip, $port);
	print DEBUG "validate_user: unix val=$val\n";
	if ($val && $sudo) {
		# Need to check if this Unix user can sudo
		if (!&check_sudo_permissions($canuser, $pass)) {
			print DEBUG "validate_user: sudo failed\n";
			$val = 0;
			}
		else {
			print DEBUG "validate_user: sudo passed\n";
			}
		}
	return $val == 2 ? ( $canuser, 1, 0, $webminuser ) :
	       $val == 1 ? ( $canuser, 0, 0, $webminuser ) :
			   ( undef, 0, 0, $webminuser );
	}
elsif ($canmode == 4) {
	# Attempt external authentication
	return &validate_external_user($canuser, $pass) ?
		( $canuser, 0, 0, $webminuser ) :
		( undef, 0, 0, $webminuser );
	}
else {
	# Can't happen!
	return ( );
	}
}

# validate_unix_user(user, password, remote-ip, local-port)
# Returns 1 if a username and password are valid under unix, 0 if not,
# or 2 if the account has expired.
# Checks PAM if available, and falls back to reading the system password
# file otherwise.
sub validate_unix_user
{
if ($use_pam) {
	# Check with PAM
	$pam_username = $_[0];
	$pam_password = $_[1];
	eval "use Authen::PAM;";
	local $pamh = new Authen::PAM($config{'pam'}, $pam_username,
				      \&pam_conv_func);
	if (ref($pamh)) {
		$pamh->pam_set_item(PAM_RHOST(), $_[2]) if ($_[2]);
		$pamh->pam_set_item(PAM_TTY(), $_[3]) if ($_[3]);
		local $rcode = 0;
		local $pam_ret = $pamh->pam_authenticate();
		if ($pam_ret == PAM_SUCCESS()) {
			# Logged in OK .. make sure password hasn't expired
			local $acct_ret = $pamh->pam_acct_mgmt();
			$pam_ret = $acct_ret;
			if ($acct_ret == PAM_SUCCESS()) {
				$pamh->pam_open_session();
				$rcode = 1;
				}
			elsif ($acct_ret == PAM_NEW_AUTHTOK_REQD() ||
			       $acct_ret == PAM_ACCT_EXPIRED()) {
				$rcode = 2;
				}
			else {
				print STDERR "Unknown pam_acct_mgmt return value : $acct_ret\n";
				$rcode = 0;
				}
			}
		if ($config{'pam_end'}) {
			$pamh->pam_end($pam_ret);
			}
		return $rcode;
		}
	}
elsif ($config{'pam_only'}) {
	# Pam is not available, but configuration forces it's use!
	return 0;
	}
elsif ($config{'passwd_file'}) {
	# Check in a password file
	local $rv = 0;
	open(FILE, $config{'passwd_file'});
	if ($config{'passwd_file'} eq '/etc/security/passwd') {
		# Assume in AIX format
		while(<FILE>) {
			s/\s*$//;
			if (/^\s*(\S+):/ && $1 eq $_[0]) {
				$_ = <FILE>;
				if (/^\s*password\s*=\s*(\S+)\s*$/) {
					$rv = $1 eq &password_crypt($_[1], $1) ?
						1 : 0;
					}
				last;
				}
			}
		}
	else {
		# Read the system password or shadow file
		while(<FILE>) {
			local @l = split(/:/, $_, -1);
			local $u = $l[$config{'passwd_uindex'}];
			local $p = $l[$config{'passwd_pindex'}];
			if ($u eq $_[0]) {
				$rv = $p eq &password_crypt($_[1], $p) ? 1 : 0;
				if ($config{'passwd_cindex'} ne '' && $rv) {
					# Password may have expired!
					local $c = $l[$config{'passwd_cindex'}];
					local $m = $l[$config{'passwd_mindex'}];
					local $day = time()/(24*60*60);
					if ($c =~ /^\d+/ && $m =~ /^\d+/ &&
					    $day - $c > $m) {
						# Yep, it has ..
						$rv = 2;
						}
					}
				if ($p eq "" && $config{'passwd_blank'}) {
					# Force password change
					$rv = 2;
					}
				last;
				}
			}
		}
	close(FILE);
	return $rv if ($rv);
	}

# Fallback option - check password returned by getpw*
local @uinfo = getpwnam($_[0]);
if ($uinfo[1] ne '' && &password_crypt($_[1], $uinfo[1]) eq $uinfo[1]) {
	return 1;
	}

return 0;	# Totally failed
}

# validate_external_user(user, pass)
# Validate a user by passing the username and password to an external
# squid-style authentication program
sub validate_external_user
{
return 0 if (!$config{'extauth'});
flock(EXTAUTH, 2);
local $str = "$_[0] $_[1]\n";
syswrite(EXTAUTH, $str, length($str));
local $resp = <EXTAUTH>;
flock(EXTAUTH, 8);
return $resp =~ /^OK/i ? 1 : 0;
}

# can_user_login(username, no-append, host)
# Checks if a user can login or not.
# First return value is the username.
# Second is 0 if cannot login, 1 if using Webmin pass, 2 if PAM, 3 if password
# file, 4 if external.
# Third is 1 if the user does not exist at all, 0 if he does.
# Fourth is the Webmin username whose permissions apply, based on unixauth.
# Fifth is a flag indicating if a sudo check is needed.
sub can_user_login
{
local $uinfo = &get_user_details($_[0]);
if (!$uinfo) {
	# See if this user exists in Unix and can be validated by the same
	# method as the unixauth webmin user
	local $realuser = $unixauth{$_[0]};
	local @uinfo;
	local $sudo = 0;
	local $pamany = 0;
	eval { @uinfo = getpwnam($_[0]); };	# may fail on windows
	if (!$realuser && @uinfo) {
		# No unixauth entry for the username .. try his groups 
		foreach my $ua (keys %unixauth) {
			if ($ua =~ /^\@(.*)$/) {
				if (&is_group_member(\@uinfo, $1)) {
					$realuser = $unixauth{$ua};
					last;
					}
				}
			}
		}
	if (!$realuser && @uinfo) {
		# Fall back to unix auth for all Unix users
		$realuser = $unixauth{"*"};
		}
	if (!$realuser && $use_sudo && @uinfo) {
		# Allow login effectively as root, if sudo permits it
		$sudo = 1;
		$realuser = "root";
		}
	if (!$realuser && !@uinfo && $config{'pamany'}) {
		# If the user completely doesn't exist, we can still allow
		# him to authenticate via PAM
		$realuser = $config{'pamany'};
		$pamany = 1;
		}
	if (!$realuser) {
		# For Usermin, always fall back to unix auth for any user,
		# so that later checks with domain added / removed are done.
		$realuser = $unixauth{"*"};
		}
	return (undef, 0, 1, undef) if (!$realuser);
	local $uinfo = &get_user_details($realuser);
	return (undef, 0, 1, undef) if (!$uinfo);
	local $up = $uinfo->{'pass'};

	# Work out possible domain names from the hostname
	local @doms = ( $_[2] );
	if ($_[2] =~ /^([^\.]+)\.(\S+)$/) {
		push(@doms, $2);
		}

	if ($config{'user_mapping'} && !%user_mapping) {
		# Read the user mapping file
		%user_mapping = ();
		open(MAPPING, $config{'user_mapping'});
		while(<MAPPING>) {
			s/\r|\n//g;
			s/#.*$//;
			if (/^(\S+)\s+(\S+)/) {
				if ($config{'user_mapping_reverse'}) {
					$user_mapping{$1} = $2;
					}
				else {
					$user_mapping{$2} = $1;
					}
				}
			}
		close(MAPPING);
		}

	# Check the user mapping file to see if there is an entry for the
	# user login in which specifies a new effective user
	local $um;
	foreach my $d (@doms) {
		$um ||= $user_mapping{"$_[0]\@$d"};
		}
	$um ||= $user_mapping{$_[0]};
	if (defined($um) && ($_[1]&4) == 0) {
		# A mapping exists - use it!
		return &can_user_login($um, $_[1]+4, $_[2]);
		}

	# Check if a user with the entered login and the domains appended
	# or prepended exists, and if so take it to be the effective user
	if (!@uinfo && $config{'domainuser'}) {
		# Try again with name.domain and name.firstpart
		local @firsts = map { /^([^\.]+)/; $1 } @doms;
		if (($_[1]&1) == 0) {
			local ($a, $p);
			foreach $a (@firsts, @doms) {
				foreach $p ("$_[0].${a}", "$_[0]-${a}",
					    "${a}.$_[0]", "${a}-$_[0]",
					    "$_[0]_${a}", "${a}_$_[0]") {
					local @vu = &can_user_login(
							$p, $_[1]+1, $_[2]);
					return @vu if ($vu[1]);
					}
				}
			}
		}

	# Check if the user entered a domain at the end of his username when
	# he really shouldn't have, and if so try without it
	if (!@uinfo && $config{'domainstrip'} &&
	    $_[0] =~ /^(\S+)\@(\S+)$/ && ($_[1]&2) == 0) {
		local ($stripped, $dom) = ($1, $2);
		local @vu = &can_user_login($stripped, $_[1] + 2, $_[2]);
		return @vu if ($vu[1]);
		local @vu = &can_user_login($stripped, $_[1] + 2, $dom);
		return @vu if ($vu[1]);
		}

	return ( undef, 0, 1, undef ) if (!@uinfo && !$pamany);

	if (@uinfo) {
		if (scalar(@allowusers)) {
			# Only allow people on the allow list
			return ( undef, 0, 0, undef )
				if (!&users_match(\@uinfo, @allowusers));
			}
		elsif (scalar(@denyusers)) {
			# Disallow people on the deny list
			return ( undef, 0, 0, undef )
				if (&users_match(\@uinfo, @denyusers));
			}
		if ($config{'shells_deny'}) {
			local $found = 0;
			open(SHELLS, $config{'shells_deny'});
			while(<SHELLS>) {
				s/\r|\n//g;
				s/#.*$//;
				$found++ if ($_ eq $uinfo[8]);
				}
			close(SHELLS);
			return ( undef, 0, 0, undef ) if (!$found);
			}
		}

	if ($up eq 'x') {
		# PAM or passwd file authentication
		print DEBUG "can_user_login: Validate with PAM\n";
		return ( $_[0], $use_pam ? 2 : 3, 0, $realuser, $sudo );
		}
	elsif ($up eq 'e') {
		# External authentication
		print DEBUG "can_user_login: Validate externally\n";
		return ( $_[0], 4, 0, $realuser, $sudo );
		}
	else {
		# Fixed Webmin password
		print DEBUG "can_user_login: Validate by Webmin\n";
		return ( $_[0], 1, 0, $realuser, $sudo );
		}
	}
elsif ($uinfo->{'pass'} eq 'x') {
	# Webmin user authenticated via PAM or password file
	return ( $_[0], $use_pam ? 2 : 3, 0, $_[0] );
	}
elsif ($uinfo->{'pass'} eq 'e') {
	# Webmin user authenticated externally
	return ( $_[0], 4, 0, $_[0] );
	}
else {
	# Normal Webmin user
	return ( $_[0], 1, 0, $_[0] );
	}
}

# the PAM conversation function for interactive logins
sub pam_conv_func
{
$pam_conv_func_called++;
my @res;
while ( @_ ) {
	my $code = shift;
	my $msg = shift;
	my $ans = "";

	$ans = $pam_username if ($code == PAM_PROMPT_ECHO_ON() );
	$ans = $pam_password if ($code == PAM_PROMPT_ECHO_OFF() );

	push @res, PAM_SUCCESS();
	push @res, $ans;
	}
push @res, PAM_SUCCESS();
return @res;
}

sub urandom_timeout
{
close(RANDOM);
}

# get_socket_ip(handle, ipv6-flag)
# Returns the local IP address of some connection, as both a string and in
# binary format
sub get_socket_ip
{
local ($fh, $ipv6) = @_;
local $sn = getsockname($fh);
return undef if (!$sn);
return &get_address_ip($sn, $ipv6);
}

# get_address_ip(address, ipv6-flag)
# Given a sockaddr object in binary format, return the binary address, text
# address and port number
sub get_address_ip
{
local ($sn, $ipv6) = @_;
if ($ipv6) {
	local ($p, $b) = unpack_sockaddr_in6($sn);
	return ($b, inet_ntop(AF_INET6(), $b), $p);
	}
else {
	local ($p, $b) = unpack_sockaddr_in($sn);
	return ($b, inet_ntoa($b), $p);
	}
}

# get_socket_name(handle, ipv6-flag)
# Returns the local hostname or IP address of some connection
sub get_socket_name
{
local ($fh, $ipv6) = @_;
return $config{'host'} if ($config{'host'});
local ($mybin, $myaddr) = &get_socket_ip($fh, $ipv6);
if (!$get_socket_name_cache{$myaddr}) {
	local $myname;
	if (!$config{'no_resolv_myname'}) {
		$myname = gethostbyaddr($mybin,
					$ipv6 ? AF_INET6() : AF_INET);
		}
	$myname ||= $myaddr;
	$get_socket_name_cache{$myaddr} = $myname;
	}
return $get_socket_name_cache{$myaddr};
}

# run_login_script(username, sid, remoteip, localip)
sub run_login_script
{
if ($config{'login_script'}) {
	alarm(5);
	$SIG{'ALRM'} = sub { die "timeout" };
	eval {
		system($config{'login_script'}.
		       " ".join(" ", map { quotemeta($_) || '""' } @_).
		       " >/dev/null 2>&1 </dev/null");
		};
	alarm(0);
	}
}

# run_logout_script(username, sid, remoteip, localip)
sub run_logout_script
{
if ($config{'logout_script'}) {
	alarm(5);
	$SIG{'ALRM'} = sub { die "timeout" };
	eval {
		system($config{'logout_script'}.
		       " ".join(" ", map { quotemeta($_) || '""' } @_).
		       " >/dev/null 2>&1 </dev/null");
		};
	alarm(0);
	}
}

# run_failed_script(username, reason-code, remoteip, localip)
sub run_failed_script
{
if ($config{'failed_script'}) {
	$_[0] =~ s/\r|\n/ /g;
	alarm(5);
	$SIG{'ALRM'} = sub { die "timeout" };
	eval {
		system($config{'failed_script'}.
		       " ".join(" ", map { quotemeta($_) || '""' } @_).
		       " >/dev/null 2>&1 </dev/null");
		};
	alarm(0);
	}
}

# close_all_sockets()
# Closes all the main listening sockets
sub close_all_sockets
{
local $s;
foreach $s (@socketfhs) {
	close($s);
	}
}

# close_all_pipes()
# Close all pipes for talking to sub-processes
sub close_all_pipes
{
local $p;
foreach $p (@passin) { close($p); }
foreach $p (@passout) { close($p); }
foreach $p (values %conversations) {
	if ($p->{'PAMOUTr'}) {
		close($p->{'PAMOUTr'});
		close($p->{'PAMINw'});
		}
	}
}

# check_user_ip(user)
# Returns 1 if some user is allowed to login from the accepting IP, 0 if not
sub check_user_ip
{
local ($username) = @_;
local $uinfo = &get_user_details($username);
return 1 if (!$uinfo);
if ($uinfo->{'deny'} &&
    &ip_match($acptip, $localip, @{$uinfo->{'deny'}}) ||
    $uinfo->{'allow'} &&
    !&ip_match($acptip, $localip, @{$uinfo->{'allow'}})) {
	return 0;
	}
return 1;
}

# check_user_time(user)
# Returns 1 if some user is allowed to login at the current date and time
sub check_user_time
{
local ($username) = @_;
local $uinfo = &get_user_details($username);
return 1 if (!$uinfo || !$uinfo->{'allowdays'} && !$uinfo->{'allowhours'});
local @tm = localtime(time());
if ($uinfo->{'allowdays'}) {
	# Make sure day is allowed
	return 0 if (&indexof($tm[6], @{$uinfo->{'allowdays'}}) < 0);
	}
if ($uinfo->{'allowhours'}) {
	# Make sure time is allowed
	local $m = $tm[2]*60+$tm[1];
	return 0 if ($m < $uinfo->{'allowhours'}->[0] ||
		     $m > $uinfo->{'allowhours'}->[1]);
	}
return 1;
}

# generate_random_id(password, [force-urandom])
# Returns a random session ID number
sub generate_random_id
{
local ($pass, $force_urandom) = @_;
local $sid;
if (!$bad_urandom) {
	# First try /dev/urandom, unless we have marked it as bad
	$SIG{ALRM} = "miniserv::urandom_timeout";
	alarm(5);
	if (open(RANDOM, "/dev/urandom")) {
		my $tmpsid;
		if (read(RANDOM, $tmpsid, 16) == 16) {
			$sid = lc(unpack('h*',$tmpsid));
			}
		close(RANDOM);
		}
	alarm(0);
	}
if (!$sid && !$force_urandom) {
	$sid = time();
	local $mul = 1;
	foreach $c (split(//, &unix_crypt($pass, substr($$, -2)))) {
		$sid += ord($c) * $mul;
		$mul *= 3;
		}
	}
return $sid;
}

# handle_login(username, ok, expired, not-exists, password, [no-test-cookie])
# Called from handle_session to either mark a user as logged in, or not
sub handle_login
{
local ($vu, $ok, $expired, $nonexist, $pass, $notest) = @_;
$authuser = $vu if ($ok);

# check if the test cookie is set
if ($header{'cookie'} !~ /testing=1/ && $vu &&
    !$config{'no_testing_cookie'} && !$notest) {
	&http_error(500, "No cookies",
	   "Your browser does not support cookies, ".
	   "which are required for this web server to ".
	   "work in session authentication mode");
	}

# check with main process for delay
if ($config{'passdelay'} && $vu) {
	print DEBUG "handle_login: requesting delay vu=$vu acptip=$acptip ok=$ok\n";
	print $PASSINw "delay $vu $acptip $ok\n";
	<$PASSOUTr> =~ /(\d+) (\d+)/;
	$blocked = $2;
	sleep($1);
	print DEBUG "handle_login: delay=$1 blocked=$2\n";
	}

if ($ok && (!$expired ||
	    $config{'passwd_mode'} == 1)) {
	# Logged in OK! Tell the main process about
	# the new SID
	local $sid = &generate_random_id($pass);
	print DEBUG "handle_login: sid=$sid\n";
	print $PASSINw "new $sid $authuser $acptip\n";

	# Run the post-login script, if any
	&run_login_script($authuser, $sid,
			  $loghost, $localip);

	# Check for a redirect URL for the user
	local $rurl = &login_redirect($authuser, $pass, $host);
	print DEBUG "handle_login: redirect URL rurl=$rurl\n";
	if ($rurl) {
		# Got one .. go to it
		&write_data("HTTP/1.0 302 Moved Temporarily\r\n");
		&write_data("Date: $datestr\r\n");
		&write_data("Server: $config{'server'}\r\n");
		&write_data("Location: $rurl\r\n");
		&write_keep_alive(0);
		&write_data("\r\n");
		&log_request($loghost, $authuser, $reqline, 302, 0);
		}
	else {
		# Set cookie and redirect to originally requested page
		&write_data("HTTP/1.0 302 Moved Temporarily\r\n");
		&write_data("Date: $datestr\r\n");
		&write_data("Server: $config{'server'}\r\n");
		local $ssl = $use_ssl || $config{'inetd_ssl'};
		$portstr = $port == 80 && !$ssl ? "" :
			   $port == 443 && $ssl ? "" : ":$port";
		$prot = $ssl ? "https" : "http";
		local $sec = $ssl ? "; secure" : "";
		if (!$config{'no_httponly'}) {
			$sec .= "; httpOnly";
			}
		if ($in{'page'} !~ /^\/[A-Za-z0-9\/\.\-\_:]+$/) {
			# Make redirect URL safe
			$in{'page'} = "/";
			}
		local $cpath = $config{'cookiepath'};
		if ($in{'save'}) {
			&write_data("Set-Cookie: $sidname=$sid; path=$cpath; ".
			    "expires=\"Thu, 31-Dec-2037 00:00:00\"$sec\r\n");
			}
		else {
			&write_data("Set-Cookie: $sidname=$sid; path=$cpath".
				    "$sec\r\n");
			}
		&write_data("Location: $prot://$hostport$in{'page'}\r\n");
		&write_keep_alive(0);
		&write_data("\r\n");
		&log_request($loghost, $authuser, $reqline, 302, 0);
		syslog("info", "%s", "Successful login as $authuser from $loghost") if ($use_syslog);
		&write_login_utmp($authuser, $acpthost);
		}
	return 0;
	}
elsif ($ok && $expired &&
       ($config{'passwd_mode'} == 2 || $expired == 2)) {
	# Login was ok, but password has expired or was temporary. Need
	# to force display of password change form.
	&run_failed_script($authuser, 'expiredpass',
			   $loghost, $localip);
	$validated = 1;
	$authuser = undef;
	$querystring = "&user=".&urlize($vu).
		       "&pam=".$use_pam.
		       "&expired=".$expired;
	$method = "GET";
	$queryargs = "";
	$page = $config{'password_form'};
	$logged_code = 401;
	$miniserv_internal = 2;
	syslog("crit", "%s",
		"Expired login as $vu ".
		"from $loghost") if ($use_syslog);
	}
else {
	# Login failed, or password has expired. The login form will be
	# displayed again by later code
	&run_failed_script($vu, $handle_login ? 'wronguser' :
				$expired ? 'expiredpass' : 'wrongpass',
			   $loghost, $localip);
	$failed_user = $vu;
	$request_uri = $in{'page'};
	$already_session_id = undef;
	$method = "GET";
	$authuser = $baseauthuser = undef;
	syslog("crit", "%s",
		($nonexist ? "Non-existent" :
		 $expired ? "Expired" : "Invalid").
		" login as $vu from $loghost")
		if ($use_syslog);
	}
return undef;
}

# write_login_utmp(user, host)
# Record the login by some user in utmp
sub write_login_utmp
{
if ($write_utmp) {
	# Write utmp record for login
	%utmp = ( 'ut_host' => $_[1],
		  'ut_time' => time(),
		  'ut_user' => $_[0],
		  'ut_type' => 7,	# user process
		  'ut_pid' => $miniserv_main_pid,
		  'ut_line' => $config{'pam'},
		  'ut_id' => '' );
	if (defined(&User::Utmp::putut)) {
		User::Utmp::putut(\%utmp);
		}
	else {
		User::Utmp::pututline(\%utmp);
		}
	}
}

# write_logout_utmp(user, host)
# Record the logout by some user in utmp
sub write_logout_utmp
{
if ($write_utmp) {
	# Write utmp record for logout
	%utmp = ( 'ut_host' => $_[1],
		  'ut_time' => time(),
		  'ut_user' => $_[0],
		  'ut_type' => 8,	# dead process
		  'ut_pid' => $miniserv_main_pid,
		  'ut_line' => $config{'pam'},
		  'ut_id' => '' );
	if (defined(&User::Utmp::putut)) {
		User::Utmp::putut(\%utmp);
		}
	else {
		User::Utmp::pututline(\%utmp);
		}
	}
}

# pam_conversation_process(username, write-pipe, read-pipe)
# This function is called inside a sub-process to communicate with PAM. It sends
# questions down one pipe, and reads responses from another
sub pam_conversation_process
{
local ($user, $writer, $reader) = @_;
$miniserv::pam_conversation_process_writer = $writer;
$miniserv::pam_conversation_process_reader = $reader;
eval "use Authen::PAM;";
local $convh = new Authen::PAM(
	$config{'pam'}, $user, \&miniserv::pam_conversation_process_func);
local $pam_ret = $convh->pam_authenticate();
if ($pam_ret == PAM_SUCCESS()) {
	local $acct_ret = $convh->pam_acct_mgmt();
	if ($acct_ret == PAM_SUCCESS()) {
		$convh->pam_open_session();
		print $writer "x2 $user 1 0 0\n";
		}
	elsif ($acct_ret == PAM_NEW_AUTHTOK_REQD() ||
	       $acct_ret == PAM_ACCT_EXPIRED()) {
		print $writer "x2 $user 1 1 0\n";
		}
	else {
		print $writer "x0 Unknown PAM account status $acct_ret\n";
		}
	}
else {
	print $writer "x2 $user 0 0 0\n";
	}
exit(0);
}

# pam_conversation_process_func(type, message, [type, message, ...])
# A pipe that talks to both PAM and the master process
sub pam_conversation_process_func
{
local @rv;
select($miniserv::pam_conversation_process_writer); $| = 1; select(STDOUT);
while(@_) {
	local ($type, $msg) = (shift, shift);
	$msg =~ s/\r|\n//g;
	local $ok = (print $miniserv::pam_conversation_process_writer "$type $msg\n");
	print $miniserv::pam_conversation_process_writer "\n";
	local $answer = <$miniserv::pam_conversation_process_reader>;
	$answer =~ s/\r|\n//g;
	push(@rv, PAM_SUCCESS(), $answer);
	}
push(@rv, PAM_SUCCESS());
return @rv;
}

# allocate_pipes()
# Returns 4 new pipe file handles
sub allocate_pipes
{
local ($PASSINr, $PASSINw, $PASSOUTr, $PASSOUTw);
local $p;
local %taken = ( (map { $_, 1 } @passin),
	         (map { $_->{'PASSINr'} } values %conversations) );
for($p=0; $taken{"PASSINr$p"}; $p++) { }
$PASSINr = "PASSINr$p";
$PASSINw = "PASSINw$p";
$PASSOUTr = "PASSOUTr$p";
$PASSOUTw = "PASSOUTw$p";
pipe($PASSINr, $PASSINw);
pipe($PASSOUTr, $PASSOUTw);
select($PASSINw); $| = 1;
select($PASSINr); $| = 1;
select($PASSOUTw); $| = 1;
select($PASSOUTw); $| = 1;
select(STDOUT);
return ($PASSINr, $PASSINw, $PASSOUTr, $PASSOUTw);
}

# recv_pam_question(&conv, fd)
# Reads one PAM question from the sub-process, and sends it to the HTTP handler.
# Returns 0 if the conversation is over, 1 if not.
sub recv_pam_question
{
local ($conf, $fh) = @_;
local $pr = $conf->{'PAMOUTr'};
select($pr); $| = 1; select(STDOUT);
local $line = <$pr>;
$line =~ s/\r|\n//g;
if (!$line) {
	$line = <$pr>;
	$line =~ s/\r|\n//g;
	}
$conf->{'last'} = time();
if (!$line) {
	# Failed!
	print $fh "0 PAM conversation error\n";
	return 0;
	}
else {
	local ($type, $msg) = split(/\s+/, $line, 2);
	if ($type =~ /^x(\d+)/) {
		# Pass this status code through
		print $fh "$1 $msg\n";
		return $1 == 2 || $1 == 0 ? 0 : 1;
		}
	elsif ($type == PAM_PROMPT_ECHO_ON()) {
		# A normal question
		print $fh "1 $msg\n";
		return 1;
		}
	elsif ($type == PAM_PROMPT_ECHO_OFF()) {
		# A password
		print $fh "3 $msg\n";
		return 1;
		}
	elsif ($type == PAM_ERROR_MSG() || $type == PAM_TEXT_INFO()) {
		# A message that does not require a response
		print $fh "4 $msg\n";
		return 1;
		}
	else {
		# Unknown type!
		print $fh "0 Unknown PAM message type $type\n";
		return 0;
		}
	}
}

# send_pam_answer(&conv, answer)
# Sends a response from the user to the PAM sub-process
sub send_pam_answer
{
local ($conf, $answer) = @_;
local $pw = $conf->{'PAMINw'};
$conf->{'last'} = time();
print $pw "$answer\n";
}

# end_pam_conversation(&conv)
# Clean up PAM conversation pipes and processes
sub end_pam_conversation
{
local ($conv) = @_;
kill('KILL', $conv->{'pid'}) if ($conv->{'pid'});
if ($conv->{'PAMINr'}) {
	close($conv->{'PAMINr'});
	close($conv->{'PAMOUTr'});
	close($conv->{'PAMINw'});
	close($conv->{'PAMOUTw'});
	}
delete($conversations{$conv->{'cid'}});
}

# get_ipkeys(&miniserv)
# Returns a list of IP address to key file mappings from a miniserv.conf entry
sub get_ipkeys
{
local (@rv, $k);
foreach $k (keys %{$_[0]}) {
	if ($k =~ /^ipkey_(\S+)/) {
		local $ipkey = { 'ips' => [ split(/,/, $1) ],
				 'key' => $_[0]->{$k},
				 'index' => scalar(@rv) };
		$ipkey->{'cert'} = $_[0]->{'ipcert_'.$1};
		$ipkey->{'extracas'} = $_[0]->{'ipextracas_'.$1};
		push(@rv, $ipkey);
		}
	}
return @rv;
}

# create_ssl_context(keyfile, [certfile], [extracas])
sub create_ssl_context
{
local ($keyfile, $certfile, $extracas) = @_;
local $ssl_ctx;
eval { $ssl_ctx = Net::SSLeay::new_x_ctx() };
$ssl_ctx ||= Net::SSLeay::CTX_new();
$ssl_ctx || die "Failed to create SSL context : $!";

# Setup PFS, if ciphers are in use
if (-r $config{'dhparams_file'}) {
	eval {
		my $bio = Net::SSLeay::BIO_new_file(
				$config{'dhparams_file'}, 'r');
		my $DHP = Net::SSLeay::PEM_read_bio_DHparams($bio);
		Net::SSLeay::CTX_set_tmp_dh($ssl_ctx, $DHP);
		my $nid = Net::SSLeay::OBJ_sn2nid("secp384r1");
		my $curve = Net::SSLeay::EC_KEY_new_by_curve_name($nid);
		Net::SSLeay::CTX_set_tmp_ecdh($ssl_ctx, $curve);
		Net::SSLeay::BIO_free($bio);
		};
	}
if ($@) {
	print STDERR "Failed to load $config{'dhparams_file'} : $@\n";
	}

if ($client_certs) {
	Net::SSLeay::CTX_load_verify_locations(
		$ssl_ctx, $config{'ca'}, "");
	eval {
		Net::SSLeay::set_verify(
			$ssl_ctx, &Net::SSLeay::VERIFY_PEER, \&verify_client);
		};
	if ($@) {
		Net::SSLeay::CTX_set_verify(
			$ssl_ctx, &Net::SSLeay::VERIFY_PEER, \&verify_client);
		}
	}
if ($extracas && $extracas ne "none") {
	foreach my $p (split(/\s+/, $extracas)) {
		Net::SSLeay::CTX_load_verify_locations(
			$ssl_ctx, $p, "");
		}
	}

Net::SSLeay::CTX_use_PrivateKey_file(
	$ssl_ctx, $keyfile,
	&Net::SSLeay::FILETYPE_PEM) || die "Failed to open SSL key $keyfile";
Net::SSLeay::CTX_use_certificate_file(
	$ssl_ctx, $certfile || $keyfile,
	&Net::SSLeay::FILETYPE_PEM) || die "Failed to open SSL cert $certfile";

if ($config{'no_ssl2'}) {
	eval 'Net::SSLeay::CTX_set_options($ssl_ctx,
		&Net::SSLeay::OP_NO_SSLv2)';
	}
if ($config{'no_ssl3'}) {
	eval 'Net::SSLeay::CTX_set_options($ssl_ctx,
		&Net::SSLeay::OP_NO_SSLv3)';
	}
if ($config{'no_tls1'}) {
	eval 'Net::SSLeay::CTX_set_options($ssl_ctx,
		&Net::SSLeay::OP_NO_TLSv1)';
	}
if ($config{'no_tls1_1'}) {
	eval 'Net::SSLeay::CTX_set_options($ssl_ctx,
		&Net::SSLeay::OP_NO_TLSv1_1)';
	}
if ($config{'no_tls1_2'}) {
	eval 'Net::SSLeay::CTX_set_options($ssl_ctx,
		&Net::SSLeay::OP_NO_TLSv1_2)';
	}
if ($config{'no_sslcompression'}) {
	eval 'Net::SSLeay::CTX_set_options($ssl_ctx,
		&Net::SSLeay::OP_NO_COMPRESSION)';
	}
if ($config{'ssl_honorcipherorder'}) {
	eval 'Net::SSLeay::CTX_set_options($ssl_ctx,
		&Net::SSLeay::OP_CIPHER_SERVER_PREFERENCE)';
	}

return $ssl_ctx;
}

# ssl_connection_for_ip(socket, ipv6-flag)
# Returns a new SSL connection object for some socket, or undef if failed
sub ssl_connection_for_ip
{
local ($sock, $ipv6) = @_;
local $sn = getsockname($sock);
if (!$sn) {
	print STDERR "Failed to get address for socket $sock\n";
	return undef;
	}
local (undef, $myip, undef) = &get_address_ip($sn, $ipv6);
local $ssl_ctx = $ssl_contexts{$myip} || $ssl_contexts{"*"};
local $ssl_con = Net::SSLeay::new($ssl_ctx);
if ($config{'ssl_cipher_list'}) {
	# Force use of ciphers
	eval "Net::SSLeay::set_cipher_list(
			\$ssl_con, \$config{'ssl_cipher_list'})";
	if ($@) {
		print STDERR "SSL cipher $config{'ssl_cipher_list'} failed : ",
			     "$@\n";
		}
	}
Net::SSLeay::set_fd($ssl_con, fileno($sock));
if (!Net::SSLeay::accept($ssl_con)) {
	print STDERR "Failed to initialize SSL connection\n";
	return undef;
	}
return $ssl_con;
}

# login_redirect(username, password, host)
# Calls the login redirect script (if configured), which may output a URL to
# re-direct a user to after logging in.
sub login_redirect
{
return undef if (!$config{'login_redirect'});
local $quser = quotemeta($_[0]);
local $qpass = quotemeta($_[1]);
local $qhost = quotemeta($_[2]);
local $url = `$config{'login_redirect'} $quser $qpass $qhost`;
chop($url);
return $url;
}

# reload_config_file()
# Re-read %config, and call post-config actions
sub reload_config_file
{
&log_error("Reloading configuration");
%config = &read_config_file($config_file);
&update_vital_config();
&read_users_file();
&read_mime_types();
&build_config_mappings();
&read_webmin_crons();
&precache_files();
if ($config{'session'}) {
	dbmclose(%sessiondb);
	dbmopen(%sessiondb, $config{'sessiondb'}, 0700);
	}
}

# read_config_file(file)
# Reads the given config file, and returns a hash of values
sub read_config_file
{
local %rv;
open(CONF, $_[0]) || die "Failed to open config file $_[0] : $!";
while(<CONF>) {
	s/\r|\n//g;
	if (/^#/ || !/\S/) { next; }
	/^([^=]+)=(.*)$/;
	$name = $1; $val = $2;
	$name =~ s/^\s+//g; $name =~ s/\s+$//g;
	$val =~ s/^\s+//g; $val =~ s/\s+$//g;
	$rv{$name} = $val;
	}
close(CONF);
return %rv;
}

# update_vital_config()
# Updates %config with defaults, and dies if something vital is missing
sub update_vital_config
{
my %vital = ("port", 80,
	  "root", "./",
	  "server", "MiniServ/0.01",
	  "index_docs", "index.html index.htm index.cgi index.php",
	  "addtype_html", "text/html",
	  "addtype_txt", "text/plain",
	  "addtype_gif", "image/gif",
	  "addtype_jpg", "image/jpeg",
	  "addtype_jpeg", "image/jpeg",
	  "realm", "MiniServ",
	  "session_login", "/session_login.cgi",
	  "pam_login", "/pam_login.cgi",
	  "password_form", "/password_form.cgi",
	  "password_change", "/password_change.cgi",
	  "maxconns", 50,
	  "pam", "webmin",
	  "sidname", "sid",
	  "unauth", "^/unauthenticated/ ^/robots.txt\$ ^[A-Za-z0-9\\-/_]+\\.jar\$ ^[A-Za-z0-9\\-/_]+\\.class\$ ^[A-Za-z0-9\\-/_]+\\.gif\$ ^[A-Za-z0-9\\-/_]+\\.png\$ ^[A-Za-z0-9\\-/_]+\\.conf\$ ^[A-Za-z0-9\\-/_]+\\.ico\$ ^/robots.txt\$",
	  "max_post", 10000,
	  "expires", 7*24*60*60,
	  "pam_test_user", "root",
	  "precache", "lang/en */lang/en",
	  "cookiepath", "/",
	 );
foreach my $v (keys %vital) {
	if (!$config{$v}) {
		if ($vital{$v} eq "") {
			die "Missing config option $v";
			}
		$config{$v} = $vital{$v};
		}
	}
if (!$config{'sessiondb'}) {
	$config{'pidfile'} =~ /^(.*)\/[^\/]+$/;
	$config{'sessiondb'} = "$1/sessiondb";
	}
if (!$config{'errorlog'}) {
	$config{'logfile'} =~ /^(.*)\/[^\/]+$/;
	$config{'errorlog'} = "$1/miniserv.error";
	}
if (!$config{'tempbase'}) {
	$config{'pidfile'} =~ /^(.*)\/[^\/]+$/;
	$config{'tempbase'} = "$1/cgitemp";
	}
if (!$config{'blockedfile'}) {
	$config{'pidfile'} =~ /^(.*)\/[^\/]+$/;
	$config{'blockedfile'} = "$1/blocked";
	}
if (!$config{'webmincron_dir'}) {
	$config_file =~ /^(.*)\/[^\/]+$/;
	$config{'webmincron_dir'} = "$1/webmincron/crons";
	}
if (!$config{'webmincron_last'}) {
	$config{'logfile'} =~ /^(.*)\/[^\/]+$/;
	$config{'webmincron_last'} = "$1/miniserv.lastcrons";
	}
if (!$config{'webmincron_wrapper'}) {
	$config{'webmincron_wrapper'} = $config{'root'}.
					"/webmincron/webmincron.pl";
	}
if (!$config{'twofactor_wrapper'}) {
	$config{'twofactor_wrapper'} = $config{'root'}."/acl/twofactor.pl";
	}
}

# read_users_file()
# Fills the %users and %certs hashes from the users file in %config
sub read_users_file
{
undef(%users);
undef(%certs);
undef(%allow);
undef(%deny);
undef(%allowdays);
undef(%allowhours);
undef(%lastchanges);
undef(%nochange);
undef(%temppass);
undef(%twofactor);
if ($config{'userfile'}) {
	open(USERS, $config{'userfile'});
	while(<USERS>) {
		s/\r|\n//g;
		local @user = split(/:/, $_, -1);
		$users{$user[0]} = $user[1];
		$certs{$user[0]} = $user[3] if ($user[3]);
		if ($user[4] =~ /^allow\s+(.*)/) {
			my $allow = $1;
			$allow =~ s/;/:/g;
			$allow{$user[0]} = $config{'alwaysresolve'} ?
				[ split(/\s+/, $allow) ] :
				[ &to_ip46address(split(/\s+/, $allow)) ];
			}
		elsif ($user[4] =~ /^deny\s+(.*)/) {
			my $deny = $1;
			$deny =~ s/;/:/g;
			$deny{$user[0]} = $config{'alwaysresolve'} ?
				[ split(/\s+/, $deny) ] :
				[ &to_ip46address(split(/\s+/, $deny)) ];
			}
		if ($user[5] =~ /days\s+(\S+)/) {
			$allowdays{$user[0]} = [ split(/,/, $1) ];
			}
		if ($user[5] =~ /hours\s+(\d+)\.(\d+)-(\d+).(\d+)/) {
			$allowhours{$user[0]} = [ $1*60+$2, $3*60+$4 ];
			}
		$lastchanges{$user[0]} = $user[6];
		$nochange{$user[0]} = $user[9];
		$temppass{$user[0]} = $user[10];
		if ($user[11] && $user[12]) {
			$twofactor{$user[0]} = { 'provider' => $user[11],
						 'id' => $user[12],
						 'apikey' => $user[13] };
			}
		}
	close(USERS);
	}

# Test user DB, if configured
if ($config{'userdb'}) {
	my $dbh = &connect_userdb($config{'userdb'});
	if (!ref($dbh)) {
		print STDERR "Failed to open users database : $dbh\n"
		}
	else {
		&disconnect_userdb($config{'userdb'}, $dbh);
		}
	}
}

# get_user_details(username)
# Returns a hash ref of user details, either from config files or the user DB
sub get_user_details
{
my ($username) = @_;
if (exists($users{$username})) {
	# In local files
	return { 'name' => $username,
		 'pass' => $users{$username},
		 'certs' => $certs{$username},
		 'allow' => $allow{$username},
		 'deny' => $deny{$username},
		 'allowdays' => $allowdays{$username},
		 'allowhours' => $allowhours{$username},
		 'lastchanges' => $lastchanges{$username},
		 'nochange' => $nochange{$username},
		 'temppass' => $temppass{$username},
		 'preroot' => $config{'preroot_'.$username},
		 'twofactor_provider' => $twofactor{$username}->{'provider'},
		 'twofactor_id' => $twofactor{$username}->{'id'},
		 'twofactor_apikey' => $twofactor{$username}->{'apikey'},
	       };
	}
if ($config{'userdb'}) {
	# Try querying user database
	if (exists($get_user_details_cache{$username})) {
		# Cached already
		return $get_user_details_cache{$username};
		}
	print DEBUG "get_user_details: Connecting to user database\n";
	my ($dbh, $proto, $prefix, $args) = &connect_userdb($config{'userdb'});
	my $user;
	my %attrs;
	if (!ref($dbh)) {
		print DEBUG "get_user_details: Failed : $dbh\n";
		print STDERR "Failed to connect to user database : $dbh\n";
		}
	elsif ($proto eq "mysql" || $proto eq "postgresql") {
		# Fetch user ID and password with SQL
		print DEBUG "get_user_details: Looking for $username in SQL\n";
		my $cmd = $dbh->prepare(
			"select id,pass from webmin_user where name = ?");
		if (!$cmd || !$cmd->execute($username)) {
			print STDERR "Failed to lookup user : ",
				     $dbh->errstr,"\n";
			return undef;
			}
		my ($id, $pass) = $cmd->fetchrow();
		$cmd->finish();
		if (!$id) {
			&disconnect_userdb($config{'userdb'}, $dbh);
			$get_user_details_cache{$username} = undef;
			print DEBUG "get_user_details: User not found\n";
			return undef;
			}
		print DEBUG "get_user_details: id=$id pass=$pass\n";

		# Fetch attributes and add to user object
		print DEBUG "get_user_details: finding user attributes\n";
		my $cmd = $dbh->prepare(
			"select attr,value from webmin_user_attr where id = ?");
		if (!$cmd || !$cmd->execute($id)) {
			print STDERR "Failed to lookup user attrs : ",
				     $dbh->errstr,"\n";
			return undef;
			}
		$user = { 'name' => $username,
			  'id' => $id,
			  'pass' => $pass,
			  'proto' => $proto };
		while(my ($attr, $value) = $cmd->fetchrow()) {
			$attrs{$attr} = $value;
			}
		$cmd->finish();
		}
	elsif ($proto eq "ldap") {
		# Fetch user DN with LDAP
		print DEBUG "get_user_details: Looking for $username in LDAP\n";
		my $rv = $dbh->search(
			base => $prefix,
			filter => '(&(cn='.$username.')(objectClass='.
                                  $args->{'userclass'}.'))',
			scope => 'sub');
		if (!$rv || $rv->code) {
			print STDERR "Failed to lookup user : ",
				     ($rv ? $rv->error : "Unknown error"),"\n";
			return undef;
			}
		my ($u) = $rv->all_entries();
		if (!$u || $u->get_value('cn') ne $username) {
			&disconnect_userdb($config{'userdb'}, $dbh);
                        $get_user_details_cache{$username} = undef;
			print DEBUG "get_user_details: User not found\n";
                        return undef;
			}

		# Extract attributes
		my $pass = $u->get_value('webminPass');
		$user = { 'name' => $username,
			  'id' => $u->dn(),
			  'pass' => $pass,
			  'proto' => $proto };
		foreach my $la ($u->get_value('webminAttr')) {
			my ($attr, $value) = split(/=/, $la, 2);
			$attrs{$attr} = $value;
			}
		}

	# Convert DB attributes into user object fields
	if ($user) {
		print DEBUG "get_user_details: got ",scalar(keys %attrs),
			    " attributes\n";
		$user->{'certs'} = $attrs{'cert'};
		if ($attrs{'allow'}) {
			$user->{'allow'} = $config{'alwaysresolve'} ?
				[ split(/\s+/, $attrs{'allow'}) ] :
				[ &to_ipaddress(split(/\s+/,$attrs{'allow'})) ];
			}
		if ($attrs{'deny'}) {
			$user->{'deny'} = $config{'alwaysresolve'} ?
				[ split(/\s+/, $attrs{'deny'}) ] :
				[ &to_ipaddress(split(/\s+/,$attrs{'deny'})) ];
			}
		if ($attrs{'days'}) {
			$user->{'allowdays'} = [ split(/,/, $attrs{'days'}) ];
			}
		if ($attrs{'hoursfrom'} && $attrs{'hoursto'}) {
			my ($hf, $mf) = split(/\./, $attrs{'hoursfrom'});
			my ($ht, $mt) = split(/\./, $attrs{'hoursto'});
			$user->{'allowhours'} = [ $hf*60+$ht, $ht*60+$mt ];
			}
		$user->{'lastchanges'} = $attrs{'lastchange'};
		$user->{'nochange'} = $attrs{'nochange'};
		$user->{'temppass'} = $attrs{'temppass'};
		$user->{'preroot'} = $attrs{'theme'};
		}
	&disconnect_userdb($config{'userdb'}, $dbh);
	$get_user_details_cache{$user->{'name'}} = $user;
	return $user;
	}
return undef;
}

# find_user_by_cert(cert)
# Returns a username looked up by certificate
sub find_user_by_cert
{
my ($peername) = @_;
my $peername2 = $peername;
$peername2 =~ s/Email=/emailAddress=/ || $peername2 =~ s/emailAddress=/Email=/;

# First check users in local files
foreach my $username (keys %certs) {
	if ($certs{$username} eq $peername ||
	    $certs{$username} eq $peername2) {
		return $username;
		}
	}

# Check user DB
if ($config{'userdb'}) {
	my ($dbh, $proto) = &connect_userdb($config{'userdb'});
	if (!ref($dbh)) {
		return undef;
		}
	elsif ($proto eq "mysql" || $proto eq "postgresql") {
		# Query with SQL
		my $cmd = $dbh->prepare("select webmin_user.name from webmin_user,webmin_user_attr where webmin_user.id = webmin_user_attr.id and webmin_user_attr.attr = 'cert' and webmin_user_attr.value = ?");
		return undef if (!$cmd);
		foreach my $p ($peername, $peername2) {
			my $username;
			if ($cmd->execute($p)) {
				($username) = $cmd->fetchrow();
				}
			$cmd->finish();
			return $username if ($username);
			}
		}
	elsif ($proto eq "ldap") {
		# Lookup in LDAP
		my $rv = $dbh->search(
			base => $prefix,
			filter => '(objectClass='.
				  $args->{'userclass'}.')',
			scope => 'sub',
			attrs => [ 'cn', 'webminAttr' ]);
		if ($rv && !$rv->code) {
			foreach my $u ($rv->all_entries) {
				my @attrs = $u->get_value('webminAttr');
				foreach my $la (@attrs) {
					my ($attr, $value) = split(/=/, $la, 2);
					if ($attr eq "cert" &&
					    ($value eq $peername ||
					     $value eq $peername2)) {
						return $u->get_value('cn');
						}
					}
				}
			}
		}
	}
return undef;
}

# connect_userdb(string)
# Returns a handle for talking to a user database - may be a DBI or LDAP handle.
# On failure returns an error message string. In an array context, returns the
# protocol type too.
sub connect_userdb
{
my ($str) = @_;
my ($proto, $user, $pass, $host, $prefix, $args) = &split_userdb_string($str);
if ($proto eq "mysql") {
	# Connect to MySQL with DBI
	my $drh = eval "use DBI; DBI->install_driver('mysql');";
	$drh || return $text{'sql_emysqldriver'};
	my ($host, $port) = split(/:/, $host);
	my $cstr = "database=$prefix;host=$host";
	$cstr .= ";port=$port" if ($port);
	print DEBUG "connect_userdb: Connecting to MySQL $cstr as $user\n";
	my $dbh = $drh->connect($cstr, $user, $pass, { });
	$dbh || return "Failed to connect to MySQL : ".$drh->errstr;
	print DEBUG "connect_userdb: Connected OK\n";
	return wantarray ? ($dbh, $proto, $prefix, $args) : $dbh;
	}
elsif ($proto eq "postgresql") {
	# Connect to PostgreSQL with DBI
	my $drh = eval "use DBI; DBI->install_driver('Pg');";
	$drh || return $text{'sql_epostgresqldriver'};
	my ($host, $port) = split(/:/, $host);
	my $cstr = "dbname=$prefix;host=$host";
	$cstr .= ";port=$port" if ($port);
	print DEBUG "connect_userdb: Connecting to PostgreSQL $cstr as $user\n";
	my $dbh = $drh->connect($cstr, $user, $pass);
	$dbh || return "Failed to connect to PostgreSQL : ".$drh->errstr;
	print DEBUG "connect_userdb: Connected OK\n";
	return wantarray ? ($dbh, $proto, $prefix, $args) : $dbh;
	}
elsif ($proto eq "ldap") {
	# Connect with perl LDAP module
	eval "use Net::LDAP";
	$@ && return $text{'sql_eldapdriver'};
	my ($host, $port) = split(/:/, $host);
	my $scheme = $args->{'scheme'} || 'ldap';
	if (!$port) {
		$port = $scheme eq 'ldaps' ? 636 : 389;
		}
	my $ldap = Net::LDAP->new($host,
				  port => $port,
				  'scheme' => $scheme);
	$ldap || return "Failed to connect to LDAP : ".$host;
	my $mesg;
	if ($args->{'tls'}) {
		# Switch to TLS mode
		eval { $mesg = $ldap->start_tls(); };
		if ($@ || !$mesg || $mesg->code) {
			return "Failed to switch to LDAP TLS mode : ".
			    ($@ ? $@ : $mesg ? $mesg->error : "Unknown error");
			}
		}
	# Login to the server
	if ($pass) {
		$mesg = $ldap->bind(dn => $user, password => $pass);
		}
	else {
		$mesg = $ldap->bind(dn => $user, anonymous => 1);
		}
	if (!$mesg || $mesg->code) {
		return "Failed to login to LDAP as ".$user." : ".
		       ($mesg ? $mesg->error : "Unknown error");
		}
	return wantarray ? ($ldap, $proto, $prefix, $args) : $ldap;
	}
else {
	return "Unknown protocol $proto";
	}
}

# split_userdb_string(string)
# Converts a string like mysql://user:pass@host/db into separate parts
sub split_userdb_string
{
my ($str) = @_;
if ($str =~ /^([a-z]+):\/\/([^:]*):([^\@]*)\@([a-z0-9\.\-\_]+)\/([^\?]+)(\?(.*))?$/) {
	my ($proto, $user, $pass, $host, $prefix, $argstr) =
		($1, $2, $3, $4, $5, $7);
	my %args = map { split(/=/, $_, 2) } split(/\&/, $argstr);
	return ($proto, $user, $pass, $host, $prefix, \%args);
	}
return ( );
}

# disconnect_userdb(string, &handle)
# Closes a handle opened by connect_userdb
sub disconnect_userdb
{
my ($str, $h) = @_;
if ($str =~ /^(mysql|postgresql):/) {
	# DBI disconnnect
	$h->disconnect();
	}
elsif ($str =~ /^ldap:/) {
	# LDAP disconnect
	$h->disconnect();
	}
}

# read_mime_types()
# Fills %mime with entries from file in %config and extra settings in %config
sub read_mime_types
{
undef(%mime);
if ($config{"mimetypes"} ne "") {
	open(MIME, $config{"mimetypes"});
	while(<MIME>) {
		chop; s/#.*$//;
		if (/^(\S+)\s+(.*)$/) {
			my $type = $1;
			my @exts = split(/\s+/, $2);
			foreach my $ext (@exts) {
				$mime{$ext} = $type;
				}
			}
		}
	close(MIME);
	}
foreach my $k (keys %config) {
	if ($k !~ /^addtype_(.*)$/) { next; }
	$mime{$1} = $config{$k};
	}
}

# build_config_mappings()
# Build the anonymous access list, IP access list, unauthenticated URLs list,
# redirect mapping and allow and deny lists from %config
sub build_config_mappings
{
# build anonymous access list
undef(%anonymous);
foreach my $a (split(/\s+/, $config{'anonymous'})) {
	if ($a =~ /^([^=]+)=(\S+)$/) {
		$anonymous{$1} = $2;
		}
	}

# build IP access list
undef(%ipaccess);
foreach my $a (split(/\s+/, $config{'ipaccess'})) {
	if ($a =~ /^([^=]+)=(\S+)$/) {
		$ipaccess{$1} = $2;
		}
	}

# build unauthenticated URLs list
@unauth = split(/\s+/, $config{'unauth'});

# build redirect mapping
undef(%redirect);
foreach my $r (split(/\s+/, $config{'redirect'})) {
	if ($r =~ /^([^=]+)=(\S+)$/) {
		$redirect{$1} = $2;
		}
	}

# build prefixes to be stripped
undef(@strip_prefix);
foreach my $r (split(/\s+/, $config{'strip_prefix'})) {
	push(@strip_prefix, $r);
	}

# Init allow and deny lists
@deny = split(/\s+/, $config{"deny"});
@deny = &to_ipaddress(@deny) if (!$config{'alwaysresolve'});
@allow = split(/\s+/, $config{"allow"});
@allow = &to_ipaddress(@allow) if (!$config{'alwaysresolve'});
undef(@allowusers);
undef(@denyusers);
if ($config{'allowusers'}) {
	@allowusers = split(/\s+/, $config{'allowusers'});
	}
elsif ($config{'denyusers'}) {
	@denyusers = split(/\s+/, $config{'denyusers'});
	}

# Build list of unixauth mappings
undef(%unixauth);
foreach my $ua (split(/\s+/, $config{'unixauth'})) {
	if ($ua =~ /^(\S+)=(\S+)$/) {
		$unixauth{$1} = $2;
		}
	else {
		$unixauth{"*"} = $ua;
		}
	}

# Build list of non-session-auth pages
undef(%sessiononly);
foreach my $sp (split(/\s+/, $config{'sessiononly'})) {
	$sessiononly{$sp} = 1;
	}

# Build list of logout times
undef(@logouttimes);
foreach my $a (split(/\s+/, $config{'logouttimes'})) {
	if ($a =~ /^([^=]+)=(\S+)$/) {
		push(@logouttimes, [ $1, $2 ]);
		}
	}
push(@logouttimes, [ undef, $config{'logouttime'} ]);

# Build list of DAV pathss
undef(@davpaths);
foreach my $d (split(/\s+/, $config{'davpaths'})) {
	push(@davpaths, $d);
	}
@davusers = split(/\s+/, $config{'dav_users'});

# Mobile agent substrings and hostname prefixes
@mobile_agents = split(/\t+/, $config{'mobile_agents'});
@mobile_prefixes = split(/\s+/, $config{'mobile_prefixes'});

# Expires time list
@expires_paths = ( );
foreach my $pe (split(/\t+/, $config{'expires_paths'})) {
	my ($p, $e) = split(/=/, $pe);
	if ($p && $e ne '') {
		push(@expires_paths, [ $p, $e ]);
		}
	}

# Open debug log
close(DEBUG);
if ($config{'debug'}) {
	open(DEBUG, ">>$config{'debug'}");
	}
else {
	open(DEBUG, ">/dev/null");
	}

# Reset cache of sudo checks
undef(%sudocache);
}

# is_group_member(&uinfo, groupname)
# Returns 1 if some user is a primary or secondary member of a group
sub is_group_member
{
local ($uinfo, $group) = @_;
local @ginfo = getgrnam($group);
return 0 if (!@ginfo);
return 1 if ($ginfo[2] == $uinfo->[3]);	# primary member
foreach my $m (split(/\s+/, $ginfo[3])) {
	return 1 if ($m eq $uinfo->[0]);
	}
return 0;
}

# prefix_to_mask(prefix)
# Converts a number like 24 to a mask like 255.255.255.0
sub prefix_to_mask
{
return $_[0] >= 24 ? "255.255.255.".(256-(2 ** (32-$_[0]))) :
       $_[0] >= 16 ? "255.255.".(256-(2 ** (24-$_[0]))).".0" :
       $_[0] >= 8 ? "255.".(256-(2 ** (16-$_[0]))).".0.0" :
                     (256-(2 ** (8-$_[0]))).".0.0.0";
}

# get_logout_time(user, session-id)
# Given a username, returns the idle time before he will be logged out
sub get_logout_time
{
local ($user, $sid) = @_;
if (!defined($logout_time_cache{$user,$sid})) {
	local $time;
	foreach my $l (@logouttimes) {
		if ($l->[0] =~ /^\@(.*)$/) {
			# Check group membership
			local @uinfo = getpwnam($user);
			if (@uinfo && &is_group_member(\@uinfo, $1)) {
				$time = $l->[1];
				}
			}
		elsif ($l->[0] =~ /^\//) {
			# Check file contents
			open(FILE, $l->[0]);
			while(<FILE>) {
				s/\r|\n//g;
				s/^\s*#.*$//;
				if ($user eq $_) {
					$time = $l->[1];
					last;
					}
				}
			close(FILE);
			}
		elsif (!$l->[0]) {
			# Always match
			$time = $l->[1];
			}
		else {
			# Check username
			if ($l->[0] eq $user) {
				$time = $l->[1];
				}
			}
		last if (defined($time));
		}
	$logout_time_cache{$user,$sid} = $time;
	}
return $logout_time_cache{$user,$sid};
}

# password_crypt(password, salt)
# If the salt looks like MD5 and we have a library for it, perform MD5 hashing
# of a password. Otherwise, do Unix crypt.
sub password_crypt
{
local ($pass, $salt) = @_;
local $rval;
if ($salt =~ /^\$1\$/ && $use_md5) {
	$rval = &encrypt_md5($pass, $salt);
	}
elsif ($salt =~ /^\$6\$/ && $use_sha512) {
	$rval = &encrypt_sha512($pass, $salt);
	}
if (!defined($rval) || $salt ne $rval) {
	$rval = &unix_crypt($pass, $salt);
	}
return $rval;
}

# unix_crypt(password, salt)
# Performs standard Unix hashing for a password
sub unix_crypt
{
local ($pass, $salt) = @_;
if ($use_perl_crypt) {
	return Crypt::UnixCrypt::crypt($pass, $salt);
	}
else {
	return crypt($pass, $salt);
	}
}

# handle_dav_request(davpath)
# Pass a request on to the Net::DAV::Server module
sub handle_dav_request
{
local ($path) = @_;
eval "use Filesys::Virtual::Plain";
eval "use Net::DAV::Server";
eval "use HTTP::Request";
eval "use HTTP::Headers";

if ($Net::DAV::Server::VERSION eq '1.28' && $config{'dav_nolock'}) {
	delete $Net::DAV::Server::implemented{lock};
	delete $Net::DAV::Server::implemented{unlock};
	}

# Read in request data
if (!$posted_data) {
	local $clen = $header{"content-length"};
	while(length($posted_data) < $clen) {
		$buf = &read_data($clen - length($posted_data));
		if (!length($buf)) {
			&http_error(500, "Failed to read POST request");
			}
		$posted_data .= $buf;
		}
	}

# For subsequent logging
open(MINISERVLOG, ">>$config{'logfile'}");

# Switch to user
local $root;
local @u = getpwnam($authuser);
if ($config{'dav_remoteuser'} && !$< && $validated) {
	if (@u) {
		if ($u[2] != 0) {
			$( = $u[3]; $) = "$u[3] $u[3]";
			($>, $<) = ($u[2], $u[2]);
			}
		if ($config{'dav_root'} eq '*') {
			$root = $u[7];
			}
		}
	else {
		&http_error(500, "Unix user ".&html_strip($authuser).
				 " does not exist");
		return 0;
		}
	}
$root ||= $config{'dav_root'};
$root ||= "/";

# Check if this user can use DAV
if (@davusers) {
	&users_match(\@u, @davusers) ||
		&http_error(500, "You are not allowed to access DAV");
	}

# Create DAV server
my $filesys = Filesys::Virtual::Plain->new({root_path => $root});
my $webdav = Net::DAV::Server->new();
$webdav->filesys($filesys);

# Make up a request object, and feed to DAV
local $ho = HTTP::Headers->new;
foreach my $h (keys %header) {
	next if (lc($h) eq "connection");
	$ho->header($h => $header{$h});
	}
if ($path ne "/") {
	$request_uri =~ s/^\Q$path\E//;
	$request_uri = "/" if ($request_uri eq "");
	}
my $request = HTTP::Request->new($method, $request_uri, $ho,
				 $posted_data);
if ($config{'dav_debug'}) {
	print STDERR "DAV request :\n";
	print STDERR "---------------------------------------------\n";
	print STDERR $request->as_string();
	print STDERR "---------------------------------------------\n";
	}
my $response = $webdav->run($request);

# Send back the reply
&write_data("HTTP/1.1 ",$response->code()," ",$response->message(),"\r\n");
local $content = $response->content();
if ($path ne "/") {
	$content =~ s|href>/(.+)<|href>$path/$1<|g;
	$content =~ s|href>/<|href>$path<|g;
	}
foreach my $h ($response->header_field_names) {
	next if (lc($h) eq "connection" || lc($h) eq "content-length");
	&write_data("$h: ",$response->header($h),"\r\n");
	}
&write_data("Content-length: ",length($content),"\r\n");
local $rv = &write_keep_alive(0);
&write_data("\r\n");
&write_data($content);

if ($config{'dav_debug'}) {
	print STDERR "DAV reply :\n";
	print STDERR "---------------------------------------------\n";
	print STDERR "HTTP/1.1 ",$response->code()," ",$response->message(),"\r\n";
	foreach my $h ($response->header_field_names) {
		next if (lc($h) eq "connection" || lc($h) eq "content-length");
		print STDERR "$h: ",$response->header($h),"\r\n";
		}
	print STDERR "Content-length: ",length($content),"\r\n";
	print STDERR "\r\n";
	print STDERR $content;
	print STDERR "---------------------------------------------\n";
	}

# Log it
&log_request($loghost, $authuser, $reqline, $response->code(), 
	     length($response->content()));
}

# get_system_hostname()
# Returns the hostname of this system, for reporting to listeners
sub get_system_hostname
{
# On Windows, try computername environment variable
return $ENV{'computername'} if ($ENV{'computername'});
return $ENV{'COMPUTERNAME'} if ($ENV{'COMPUTERNAME'});

# If a specific command is set, use it first
if ($config{'hostname_command'}) {
	local $out = `($config{'hostname_command'}) 2>&1`;
	if (!$?) {
		$out =~ s/\r|\n//g;
		return $out;
		}
	}

# First try the hostname command
local $out = `hostname 2>&1`;
if (!$? && $out =~ /\S/) {
	$out =~ s/\r|\n//g;
	return $out;
	}

# Try the Sys::Hostname module
eval "use Sys::Hostname";
if (!$@) {
	local $rv = eval "hostname()";
	if (!$@ && $rv) {
		return $rv;
		}
	}

# Must use net name on Windows
local $out = `net name 2>&1`;
if ($out =~ /\-+\r?\n(\S+)/) {
	return $1;
	}

return undef;
}

# indexof(string, array)
# Returns the index of some value in an array, or -1
sub indexof {
  local($i);
  for($i=1; $i <= $#_; $i++) {
    if ($_[$i] eq $_[0]) { return $i - 1; }
  }
  return -1;
}


# has_command(command)
# Returns the full path if some command is in the path, undef if not
sub has_command
{
local($d);
if (!$_[0]) { return undef; }
if (exists($has_command_cache{$_[0]})) {
	return $has_command_cache{$_[0]};
	}
local $rv = undef;
if ($_[0] =~ /^\//) {
	$rv = -x $_[0] ? $_[0] : undef;
	}
else {
	local $sp = $on_windows ? ';' : ':';
	foreach $d (split($sp, $ENV{PATH})) {
		if (-x "$d/$_[0]") {
			$rv = "$d/$_[0]";
			last;
			}
		if ($on_windows) {
			foreach my $sfx (".exe", ".com", ".bat") {
				if (-r "$d/$_[0]".$sfx) {
					$rv = "$d/$_[0]".$sfx;
					last;
					}
				}
			}
		}
	}
$has_command_cache{$_[0]} = $rv;
return $rv;
}

# check_sudo_permissions(user, pass)
# Returns 1 if some user can run any command via sudo
sub check_sudo_permissions
{
local ($user, $pass) = @_;

# First try the pipes
if ($PASSINw) {
	print DEBUG "check_sudo_permissions: querying cache for $user\n";
	print $PASSINw "readsudo $user\n";
	local $can = <$PASSOUTr>;
	chop($can);
	print DEBUG "check_sudo_permissions: cache said $can\n";
	if ($can =~ /^\d+$/ && $can != 2) {
		return int($can);
		}
	}

local $ptyfh = new IO::Pty;
print DEBUG "check_sudo_permissions: ptyfh=$ptyfh\n";
if (!$ptyfh) {
	print STDERR "Failed to create new PTY with IO::Pty\n";
	return 0;
	}
local @uinfo = getpwnam($user);
if (!@uinfo) {
	print STDERR "Unix user $user does not exist for sudo\n";
	return 0;
	}

# Execute sudo in a sub-process, via a pty
local $ttyfh = $ptyfh->slave();
print DEBUG "check_sudo_permissions: ttyfh=$ttyfh\n";
local $tty = $ptyfh->ttyname();
print DEBUG "check_sudo_permissions: tty=$tty\n";
chown($uinfo[2], $uinfo[3], $tty);
pipe(SUDOr, SUDOw);
print DEBUG "check_sudo_permissions: about to fork..\n";
local $pid = fork();
print DEBUG "check_sudo_permissions: fork=$pid pid=$$\n";
if ($pid < 0) {
	print STDERR "fork for sudo failed : $!\n";
	return 0;
	}
if (!$pid) {
	setsid();
	($(, $)) = ( $uinfo[3],
                     "$uinfo[3] ".join(" ", $uinfo[3],
                                            &other_groups($uinfo[0])) );
	($>, $<) = ($uinfo[2], $uinfo[2]);
	$ENV{'USER'} = $ENV{'LOGNAME'} = $user;
	$ENV{'HOME'} = $uinfo[7];

	$ptyfh->make_slave_controlling_terminal();
	close(STDIN); close(STDOUT); close(STDERR);
	untie(*STDIN); untie(*STDOUT); untie(*STDERR);
	close($PASSINw); close($PASSOUTr);
	close(SUDOw);
	close(SOCK);
	close(MAIN);
	open(STDIN, "<&SUDOr");
	open(STDOUT, ">$tty");
	open(STDERR, ">&STDOUT");
	close($ptyfh);
	exec("sudo -l -S");
	print "Exec failed : $!\n";
	exit 1;
	}
print DEBUG "check_sudo_permissions: pid=$pid\n";
close(SUDOr);
$ptyfh->close_slave();

# Send password, and get back response
local $oldfh = select(SUDOw);
$| = 1;
select($oldfh);
print DEBUG "check_sudo_permissions: about to send pass\n";
local $SIG{'PIPE'} = 'ignore';	# Sometimes sudo doesn't ask for a password
print SUDOw $pass,"\n";
print DEBUG "check_sudo_permissions: sent pass=$pass\n";
close(SUDOw);
local $out;
while(<$ptyfh>) {
	print DEBUG "check_sudo_permissions: got $_";
	$out .= $_;
	}
close($ptyfh);
kill('KILL', $pid);
waitpid($pid, 0);
local ($ok) = ($out =~ /\(ALL\)\s+ALL|\(ALL\)\s+NOPASSWD:\s+ALL|\(ALL\s*:\s*ALL\)\s+ALL|\(ALL\s*:\s*ALL\)\s+NOPASSWD:\s+ALL/ ? 1 : 0);

# Update cache
if ($PASSINw) {
	print $PASSINw "writesudo $user $ok\n";
	}

return $ok;
}

sub other_groups
{
my ($user) = @_;
my @rv;
setgrent();
while(my @g = getgrent()) {
        my @m = split(/\s+/, $g[3]);
        push(@rv, $g[2]) if (&indexof($user, @m) >= 0);
        }
endgrent();
return @rv;
}

# is_mobile_useragent(agent)
# Returns 1 if some user agent looks like a cellphone or other mobile device,
# such as a treo.
sub is_mobile_useragent
{
local ($agent) = @_;
local @prefixes = ( 
    "UP.Link",    # Openwave
    "Nokia",      # All Nokias start with Nokia
    "MOT-",       # All Motorola phones start with MOT-
    "SAMSUNG",    # Samsung browsers
    "Samsung",    # Samsung browsers
    "SEC-",       # Samsung browsers
    "AU-MIC",     # Samsung browsers
    "AUDIOVOX",   # Audiovox
    "BlackBerry", # BlackBerry
    "hiptop",     # Danger hiptop Sidekick
    "SonyEricsson", # Sony Ericsson
    "Ericsson",     # Old Ericsson browsers , mostly WAP
    "Mitsu/1.1.A",  # Mitsubishi phones
    "Panasonic WAP", # Panasonic old WAP phones
    "DoCoMo",     # DoCoMo phones
    "Lynx",	  # Lynx text-mode linux browser
    "Links",	  # Another text-mode linux browser
    "Dalvik",	  # Android browser
    );
local @substrings = (
    "UP.Browser",         # Openwave
    "MobilePhone",        # NetFront
    "AU-MIC-A700",        # Samsung A700 Obigo browsers
    "Danger hiptop",      # Danger Sidekick hiptop
    "Windows CE",         # Windows CE Pocket PC
    "IEMobile",           # Windows mobile browser
    "Blazer",             # Palm Treo Blazer
    "BlackBerry",         # BlackBerries can emulate other browsers, but
                          # they still keep this string in the UserAgent
    "SymbianOS",          # New Series60 browser has safari in it and
                          # SymbianOS is the only distinguishing string
    "iPhone",		  # Apple iPhone KHTML browser
    "iPod",		  # iPod touch browser
    "MobileSafari",	  # HTTP client in iPhone
    "Mobile Safari",	  # Samsung Galaxy S6 browser
    "Opera Mini",	  # Opera Mini
    "HTC_P3700",	  # HTC mobile device
    "Pre/",		  # Palm Pre
    "webOS/",		  # Palm WebOS
    "Nintendo DS",	  # DSi / DSi-XL
    );
local @regexps = (
    "Android.*Mobile",	  # Android phone
    );
foreach my $p (@prefixes) {
	return 1 if ($agent =~ /^\Q$p\E/);
	}
foreach my $s (@substrings, @mobile_agents) {
	return 1 if ($agent =~ /\Q$s\E/);
	}
foreach my $s (@regexps) {
	return 1 if ($agent =~ /$s/);
	}
return 0;
}

# write_blocked_file()
# Writes out a text file of blocked hosts and users
sub write_blocked_file
{
open(BLOCKED, ">$config{'blockedfile'}");
foreach my $d (grep { $hostfail{$_} } @deny) {
	print BLOCKED "host $d $hostfail{$d} $blockhosttime{$d}\n";
	}
foreach my $d (grep { $userfail{$_} } @denyusers) {
	print BLOCKED "user $d $userfail{$d} $blockusertime{$d}\n";
	}
close(BLOCKED);
chmod(0700, $config{'blockedfile'});
}

sub write_pid_file
{
open(PIDFILE, ">$config{'pidfile'}");
printf PIDFILE "%d\n", getpid();
close(PIDFILE);
$miniserv_main_pid = getpid();
}

# lock_user_password(user)
# Updates a user's password file entry to lock it, both in memory and on disk.
# Returns 1 if done, -1 if no such user, 0 if already locked
sub lock_user_password
{
local ($user) = @_;
local $uinfo = &get_user_details($user);
if (!$uinfo) {
	# No such user!
	return -1;
	}
if ($uinfo->{'pass'} =~ /^\!/) {
	# Already locked
	return 0;
	}
if (!$uinfo->{'proto'}) {
	# Write to users file
	$users{$user} = "!".$users{$user};
	open(USERS, $config{'userfile'});
	local @ufile = <USERS>;
	close(USERS);
	foreach my $u (@ufile) {
		local @uinfo = split(/:/, $u);
		if ($uinfo[0] eq $user) {
			$uinfo[1] = $users{$user};
			}
		$u = join(":", @uinfo);
		}
	open(USERS, ">$config{'userfile'}");
	print USERS @ufile;
	close(USERS);
	return 0;
	}

if ($config{'userdb'}) {
	# Update user DB
	my ($dbh, $proto, $prefix, $args) = &connect_userdb($config{'userdb'});
	if (!$dbh) {
		return -1;
		}
	elsif ($proto eq "mysql" || $proto eq "postgresql") {
		# Update user attribute
		my $cmd = $dbh->prepare(
			"update webmin_user set pass = ? where id = ?");
		if (!$cmd || !$cmd->execute("!".$uinfo->{'pass'},
					    $uinfo->{'id'})) {
			# Update failed
			print STDERR "Failed to lock password : ",
				     $dbh->errstr,"\n";
			return -1;
			}
		$cmd->finish() if ($cmd);
		}
	elsif ($proto eq "ldap") {
		# Update LDAP object
		my $rv = $dbh->modify($uinfo->{'id'},
		      replace => { 'webminPass' => '!'.$uinfo->{'pass'} });
		if (!$rv || $rv->code) {
			print STDERR "Failed to lock password : ",
				     ($rv ? $rv->error : "Unknown error"),"\n";
			return -1;
			}
		}
	&disconnect_userdb($config{'userdb'}, $dbh);
	return 0;
	}

return -1;	# This should never be reached
}

# hash_session_id(sid)
# Returns an MD5 or Unix-crypted session ID
sub hash_session_id
{
local ($sid) = @_;
if (!$hash_session_id_cache{$sid}) {
	if ($use_md5) {
		# Take MD5 hash
		$hash_session_id_cache{$sid} = &encrypt_md5($sid);
		}
	else {
		# Unix crypt
		$hash_session_id_cache{$sid} = &unix_crypt($sid, "XX");
		}
	}
return $hash_session_id_cache{$sid};
}

# encrypt_md5(string, [salt])
# Returns a string encrypted in MD5 format
sub encrypt_md5
{
local ($passwd, $salt) = @_;
local $magic = '$1$';
if ($salt =~ /^\$1\$([^\$]+)/) {
	# Extract actual salt from already encrypted password
	$salt = $1;
	}

# Add the password
local $ctx = eval "new $use_md5";
$ctx->add($passwd);
if ($salt) {
	$ctx->add($magic);
	$ctx->add($salt);
	}

# Add some more stuff from the hash of the password and salt
local $ctx1 = eval "new $use_md5";
$ctx1->add($passwd);
if ($salt) {
	$ctx1->add($salt);
	}
$ctx1->add($passwd);
local $final = $ctx1->digest();
for($pl=length($passwd); $pl>0; $pl-=16) {
	$ctx->add($pl > 16 ? $final : substr($final, 0, $pl));
	}

# This piece of code seems rather pointless, but it's in the C code that
# does MD5 in PAM so it has to go in!
local $j = 0;
local ($i, $l);
for($i=length($passwd); $i; $i >>= 1) {
	if ($i & 1) {
		$ctx->add("\0");
		}
	else {
		$ctx->add(substr($passwd, $j, 1));
		}
	}
$final = $ctx->digest();

if ($salt) {
	# This loop exists only to waste time
	for($i=0; $i<1000; $i++) {
		$ctx1 = eval "new $use_md5";
		$ctx1->add($i & 1 ? $passwd : $final);
		$ctx1->add($salt) if ($i % 3);
		$ctx1->add($passwd) if ($i % 7);
		$ctx1->add($i & 1 ? $final : $passwd);
		$final = $ctx1->digest();
		}
	}

# Convert the 16-byte final string into a readable form
local $rv;
local @final = map { ord($_) } split(//, $final);
$l = ($final[ 0]<<16) + ($final[ 6]<<8) + $final[12];
$rv .= &to64($l, 4);
$l = ($final[ 1]<<16) + ($final[ 7]<<8) + $final[13];
$rv .= &to64($l, 4);
$l = ($final[ 2]<<16) + ($final[ 8]<<8) + $final[14];
$rv .= &to64($l, 4);
$l = ($final[ 3]<<16) + ($final[ 9]<<8) + $final[15];
$rv .= &to64($l, 4);
$l = ($final[ 4]<<16) + ($final[10]<<8) + $final[ 5];
$rv .= &to64($l, 4);
$l = $final[11];
$rv .= &to64($l, 2);

# Add salt if needed
if ($salt) {
	return $magic.$salt.'$'.$rv;
	}
else {
	return $rv;
	}
}

# encrypt_sha512(password, [salt])
# Hashes a password, possibly with the given salt, with SHA512
sub encrypt_sha512
{
my ($passwd, $salt) = @_;
if ($salt =~ /^\$6\$([^\$]+)/) {
	# Extract actual salt from already encrypted password
	$salt = $1;
	}
$salt ||= '$6$'.substr(time(), -8).'$';
return crypt($passwd, $salt);
}

sub to64
{
local ($v, $n) = @_;
local $r;
while(--$n >= 0) {
        $r .= $itoa64[$v & 0x3f];
        $v >>= 6;
        }
return $r;
}

# read_file(file, &assoc, [&order], [lowercase])
# Fill an associative array with name=value pairs from a file
sub read_file
{
open(ARFILE, $_[0]) || return 0;
while(<ARFILE>) {
	s/\r|\n//g;
        if (!/^#/ && /^([^=]*)=(.*)$/) {
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
local(%old, @order);
&read_file($_[0], \%old, \@order);
open(ARFILE, ">$_[0]");
foreach $k (@order) {
        print ARFILE $k,"=",$_[1]->{$k},"\n" if (exists($_[1]->{$k}));
	}
foreach $k (keys %{$_[1]}) {
        print ARFILE $k,"=",$_[1]->{$k},"\n" if (!exists($old{$k}));
        }
close(ARFILE);
}

# execute_ready_webmin_crons(run-count)
# Find and run any cron jobs that are due, based on their last run time and
# execution interval
sub execute_ready_webmin_crons
{
my ($runs) = @_;
my $now = time();
my $changed = 0;
foreach my $cron (@webmincrons) {
	my $run = 0;
	if ($runs == 0 && $cron->{'boot'}) {
		# If cron job wants to be run at startup, run it now
		$run = 1;
		}
	elsif ($cron->{'disabled'}) {
		# Explicitly disabled
		$run = 0;
		}
	elsif (!$webmincron_last{$cron->{'id'}}) {
		# If not ever run before, don't run right away
		$webmincron_last{$cron->{'id'}} = $now;
		$changed = 1;
		}
	elsif ($cron->{'interval'} &&
	       $now - $webmincron_last{$cron->{'id'}} > $cron->{'interval'}) {
		# Older than interval .. time to run
		$run = 1;
		}
	elsif ($cron->{'mins'} ne '') {
		# Check if current time matches spec, and we haven't run in the
		# last minute
		my @tm = localtime($now);
		if (&matches_cron($cron->{'mins'}, $tm[1], 0) &&
		    &matches_cron($cron->{'hours'}, $tm[2], 0) &&
		    &matches_cron($cron->{'days'}, $tm[3], 1) &&
		    &matches_cron($cron->{'months'}, $tm[4]+1, 1) &&
		    &matches_cron($cron->{'weekdays'}, $tm[6], 0) &&
		    $now - $webmincron_last{$cron->{'id'}} > 60) {
			$run = 1;
			}
		}

	if ($run) {
		print DEBUG "Running cron id=$cron->{'id'} ".
			    "module=$cron->{'module'} func=$cron->{'func'} ".
			    "arg0=$cron->{'arg0'}\n";
		$webmincron_last{$cron->{'id'}} = $now;
		$changed = 1;
		my $pid = &execute_webmin_command($config{'webmincron_wrapper'},
						  [ $cron ]);
		push(@childpids, $pid);
		}
	}
if ($changed) {
	# Write out file containing last run times
	&write_file($config{'webmincron_last'}, \%webmincron_last);
	}
}

# matches_cron(cron-spec, time, first-value)
# Checks if some minute or hour matches some cron spec, which can be * or a list
# of numbers.
sub matches_cron
{
my ($spec, $tm, $first) = @_;
if ($spec eq '*') {
	return 1;
	}
else {
	foreach my $s (split(/,/, $spec)) {
		if ($s == $tm ||
		    $s =~ /^(\d+)\-(\d+)$/ &&
		      $tm >= $1 && $tm <= $2 ||
		    $s =~ /^\*\/(\d+)$/ &&
		      $tm % $1 == $first ||
		    $s =~ /^(\d+)\-(\d+)\/(\d+)$/ &&
		      $tm >= $1 && $tm <= $2 && $tm % $3 == $first) {
			return 1;
			}
		}
	return 0;
	}
}

# read_webmin_crons()
# Read all scheduled webmin cron functions and store them in the @webmincrons
# global list
sub read_webmin_crons
{
@webmincrons = ( );
opendir(CRONS, $config{'webmincron_dir'});
print DEBUG "Reading crons from $config{'webmincron_dir'}\n";
foreach my $f (readdir(CRONS)) {
	if ($f =~ /^(\d+)\.cron$/) {
		my %cron;
		&read_file("$config{'webmincron_dir'}/$f", \%cron);
		$cron{'id'} = $1;
		my $broken = 0;
		foreach my $n ('module', 'func') {
			if (!$cron{$n}) {
				print STDERR "Cron $1 missing $n\n";
				$broken = 1;
				}
			}
		if (!$cron{'interval'} && $cron{'mins'} eq '' &&
		    $cron{'special'} eq '') {
			print STDERR "Cron $1 missing any time spec\n";
			$broken = 1;
			}
		if ($cron{'special'} eq 'hourly') {
			# Run every hour on the hour
			$cron{'mins'} = 0;
			$cron{'hours'} = '*';
			$cron{'days'} = '*';
			$cron{'months'} = '*';
			$cron{'weekdays'} = '*';
			}
		elsif ($cron{'special'} eq 'daily') {
			# Run every day at midnight
			$cron{'mins'} = 0;
			$cron{'hours'} = '0';
			$cron{'days'} = '*';
			$cron{'months'} = '*';
			$cron{'weekdays'} = '*';
			}
		elsif ($cron{'special'} eq 'monthly') {
			# Run every month on the 1st
			$cron{'mins'} = 0;
			$cron{'hours'} = '0';
			$cron{'days'} = '1';
			$cron{'months'} = '*';
			$cron{'weekdays'} = '*';
			}
		elsif ($cron{'special'} eq 'weekly') {
			# Run every month on the 1st
			$cron{'mins'} = 0;
			$cron{'hours'} = '0';
			$cron{'days'} = '*';
			$cron{'months'} = '*';
			$cron{'weekdays'} = '0';
			}
		elsif ($cron{'special'} eq 'yearly' ||
		       $cron{'special'} eq 'annually') {
			# Run every year on 1st january
			$cron{'mins'} = 0;
			$cron{'hours'} = '0';
			$cron{'days'} = '1';
			$cron{'months'} = '1';
			$cron{'weekdays'} = '*';
			}
		elsif ($cron{'special'}) {
			print STDERR "Cron $1 invalid special time $cron{'special'}\n";
			$broken = 1;
			}
		if ($cron{'special'}) {
			delete($cron{'special'});
			}
		if (!$broken) {
			print DEBUG "Adding cron id=$cron{'id'} module=$cron{'module'} func=$cron{'func'} arg0=$cron{'arg0'}\n";
			push(@webmincrons, \%cron);
			}
		}
	}
closedir(CRONS);
}

# precache_files()
# Read into the Webmin cache all files marked for pre-caching
sub precache_files
{
undef(%main::read_file_cache);
foreach my $g (split(/\s+/, $config{'precache'})) {
	next if ($g eq "none");
	foreach my $f (glob("$config{'root'}/$g")) {
		my @st = stat($f);
		next if (!@st);
		$main::read_file_cache{$f} = { };
		&read_file($f, $main::read_file_cache{$f});
		$main::read_file_cache_time{$f} = $st[9];
		}
	}
}

# Check if some address is valid IPv4, returns 1 if so.
sub check_ipaddress
{
return $_[0] =~ /^(\d+)\.(\d+)\.(\d+)\.(\d+)$/ &&
	$1 >= 0 && $1 <= 255 &&
	$2 >= 0 && $2 <= 255 &&
	$3 >= 0 && $3 <= 255 &&
	$4 >= 0 && $4 <= 255;
}

# Check if some IPv6 address is properly formatted, and returns 1 if so.
sub check_ip6address
{
  my @blocks = split(/:/, $_[0]);
  return 0 if (@blocks == 0 || @blocks > 8);
  my $ib = $#blocks;
  my $where = index($blocks[$ib],"/");
  my $m = 0;
  if ($where != -1) {
    my $b = substr($blocks[$ib],0,$where);
    $m = substr($blocks[$ib],$where+1,length($blocks[$ib])-($where+1));
    $blocks[$ib]=$b;
  }
  return 0 if ($m <0 || $m >128); 
  my $b;
  my $empty = 0;
  foreach $b (@blocks) {
	  return 0 if ($b ne "" && $b !~ /^[0-9a-f]{1,4}$/i);
	  $empty++ if ($b eq "");
	  }
  return 0 if ($empty > 1 && !($_[0] =~ /^::/ && $empty == 2));
  return 1;
}

# network_to_address(binary)
# Given a network address in binary IPv4 or v4 format, return the string form
sub network_to_address
{
local ($addr) = @_;
if (length($addr) == 4 || !$use_ipv6) {
	return inet_ntoa($addr);
	}
else {
	return inet_ntop(AF_INET6(), $addr);
	}
}

# redirect_stderr_to_log()
# Re-direct STDERR to error log file
sub redirect_stderr_to_log
{
if ($config{'errorlog'} ne '-') {
	open(STDERR, ">>$config{'errorlog'}") ||
		die "failed to open $config{'errorlog'} : $!";
	if ($config{'logperms'}) {
		chmod(oct($config{'logperms'}), $config{'errorlog'});
		}
	}
select(STDERR); $| = 1; select(STDOUT);
}

# should_gzip_file(filename)
# Returns 1 if some path should be gzipped
sub should_gzip_file
{
my ($path) = @_;
return $path !~ /\.(gif|png|jpg|jpeg|tif|tiff)$/i;
}

# get_expires_time(path)
# Given a URL path, return the client-side expiry time in seconds
sub get_expires_time
{
my ($path) = @_;
foreach my $pe (@expires_paths) {
	if ($path =~ /$pe->[0]/i) {
		return $pe->[1];
		}
	}
return $config{'expires'};
}

sub html_escape
{
my ($tmp) = @_;
$tmp =~ s/&/&amp;/g;
$tmp =~ s/</&lt;/g;
$tmp =~ s/>/&gt;/g;
$tmp =~ s/\"/&quot;/g;
$tmp =~ s/\'/&#39;/g;
$tmp =~ s/=/&#61;/g;
return $tmp;
}

sub html_strip
{
my ($tmp) = @_;
$tmp =~ s/<[^>]*>//g;
return $tmp;
}

# validate_twofactor(username, token)
# Checks if a user's two-factor token is valid or not. Returns undef on success
# or the error message on failure.
sub validate_twofactor
{
my ($user, $token) = @_;
local $uinfo = &get_user_details($user);
$token =~ s/^\s+//;
$token =~ s/\s+$//;
$token || return "No two-factor token entered";
$uinfo->{'twofactor_provider'} || return undef;
pipe(TOKENr, TOKENw);
my $pid = &execute_webmin_command($config{'twofactor_wrapper'},
	[ $user, $uinfo->{'twofactor_provider'}, $uinfo->{'twofactor_id'},
	  $token, $uinfo->{'twofactor_apikey'} ],
	TOKENw);
close(TOKENw);
waitpid($pid, 0);
my $ex = $?;
my $out = <TOKENr>;
close(TOKENr);
if ($ex) {
	return $out || "Unknown two-factor authentication failure";
	}
return undef;
}

# execute_webmin_command(command, &argv, [stdout-fd])
# Run some Webmin script in a sub-process, like webmincron.pl
# Returns the PID of the new process.
sub execute_webmin_command
{
my ($cmd, $argv, $fd) = @_;
my $pid = fork();
if (!$pid) {
	# Run via a wrapper command, which we run like a CGI
	dbmclose(%sessiondb);
	if ($fd) {
		open(STDOUT, ">&$fd");
		}
	else {
		open(STDOUT, ">&STDERR");
		}
	&close_all_sockets();
	&close_all_pipes();
	close(LISTEN);

	# Setup CGI-like environment
	$envtz = $ENV{"TZ"};
	$envuser = $ENV{"USER"};
	$envpath = $ENV{"PATH"};
	$envlang = $ENV{"LANG"};
	$envroot = $ENV{"SystemRoot"};
	$envperllib = $ENV{'PERLLIB'};
	foreach my $k (keys %ENV) {
		delete($ENV{$k});
		}
	$ENV{"PATH"} = $envpath if ($envpath);
	$ENV{"TZ"} = $envtz if ($envtz);
	$ENV{"USER"} = $envuser if ($envuser);
	$ENV{"OLD_LANG"} = $envlang if ($envlang);
	$ENV{"SystemRoot"} = $envroot if ($envroot);
	$ENV{'PERLLIB'} = $envperllib if ($envperllib);
	$ENV{"HOME"} = $user_homedir;
	$ENV{"SERVER_SOFTWARE"} = $config{"server"};
	$ENV{"SERVER_ADMIN"} = $config{"email"};
	$root0 = $roots[0];
	$ENV{"SERVER_ROOT"} = $root0;
	$ENV{"SERVER_REALROOT"} = $root0;
	$ENV{"SERVER_PORT"} = $config{'port'};
	$ENV{"WEBMIN_CRON"} = 1;
	$ENV{"DOCUMENT_ROOT"} = $root0;
	$ENV{"DOCUMENT_REALROOT"} = $root0;
	$ENV{"MINISERV_CONFIG"} = $config_file;
	$ENV{"HTTPS"} = "ON" if ($use_ssl);
	$ENV{"MINISERV_PID"} = $miniserv_main_pid;
	$ENV{"SCRIPT_FILENAME"} = $cmd;
	if ($ENV{"SCRIPT_FILENAME"} =~ /^\Q$root0\E(\/.*)$/) {
		$ENV{"SCRIPT_NAME"} = $1;
		}
	$cmd =~ /^(.*)\//;
	$ENV{"PWD"} = $1;
	foreach $k (keys %config) {
		if ($k =~ /^env_(\S+)$/) {
			$ENV{$1} = $config{$k};
			}
		}
	chdir($ENV{"PWD"});
	$SIG{'CHLD'} = 'DEFAULT';
	eval {
		# Have SOCK closed if the perl exec's something
		use Fcntl;
		fcntl(SOCK, F_SETFD, FD_CLOEXEC);
		};

	# Run the wrapper script by evaling it
	if ($cmd =~ /\/([^\/]+)\/([^\/]+)$/) {
		$pkg = $1;
		}
	$0 = $cmd;
	@ARGV = @$argv;
	$main_process_id = $$;
	eval "
		\%pkg::ENV = \%ENV;
		package $pkg;
		do \"$cmd\";
		die \$@ if (\$@);
		";
	if ($@) {
		print STDERR "Perl failure : $@\n";
		}
	exit(0);
	}
return $pid;
}

# canonicalize_ip6(address)
# Converts an address to its full long form. Ie. 2001:db8:0:f101::20 to
# 2001:0db8:0000:f101:0000:0000:0000:0020
sub canonicalize_ip6
{
my ($addr) = @_;
return $addr if (!&check_ip6address($addr));
my @w = split(/:/, $addr);
my $idx = &indexof("", @w);
if ($idx >= 0) {
	# Expand ::
	my $mis = 8 - scalar(@w);
	my @nw = @w[0..$idx];
	for(my $i=0; $i<$mis; $i++) {
		push(@nw, 0);
		}
	push(@nw, @w[$idx+1 .. $#w]);
	@w = @nw;
	}
foreach my $w (@w) {
	while(length($w) < 4) {
		$w = "0".$w;
		}
	}
return lc(join(":", @w));
}

# expand_ipv6_bytes(address)
# Given a canonical IPv6 address, split it into an array of bytes
sub expand_ipv6_bytes
{
my ($addr) = @_;
my @rv;
foreach my $w (split(/:/, $addr)) {
	$w =~ /^(..)(..)$/ || return ( );
	push(@rv, hex($1), hex($2));
	}
return @rv;
}

sub get_somaxconn
{
return defined(&SOMAXCONN) ? SOMAXCONN : 128;
}

sub is_bad_header
{
my ($value, $name) = @_;
return $value =~ /^\s*\(\s*\)\s*\{/ ? 1 : 0;
}
