#!/usr/local/bin/perl
# A very simple perl web server used by Webmin

package miniserv;

use FindBin;
use lib $FindBin::Bin;
BEGIN {
	require 'miniserv-lib.pl';
	}

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
$ENV{'LIBROOT'} = $config{'root'};
if ($config{'perllib'}) {
	push(@INC, split(/:/, $config{'perllib'}));
	push(@INC, "$config{'root'}/vendor_perl");
	$ENV{'PERLLIB'} .= ':'.$config{'perllib'};
	$ENV{'PERLLIB'} .= ':'."$config{'root'}/vendor_perl";
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
eval "use Socket6";
$socket6err = $@;
if ($config{'ipv6'}) {
	if (!$socket6err) {
		push(@startup_msg, "IPv6 support enabled");
		$use_ipv6 = 1;
		}
	else {
		push(@startup_msg, "IPv6 support cannot be enabled without ".
				   "the Socket6 perl module");
		}
	}

# Check if the syslog module is available to log hacking attempts
if ($config{'syslog'}) {
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

# Check if the crypt function supports SHA512
if (&unix_crypt_supports_sha512()) {
	$use_sha512 = 1;
	push(@startup_msg, "Using SHA512 via crypt() function");
	}

# Check if Digest::SHA with hmac_sha256_hex is available, for keying
# the session-ID lookup table.
eval "use Digest::SHA qw(hmac_sha256_hex); hmac_sha256_hex('x', 'y');";
if (!$@) {
	$use_hmac_sha256 = 1;
	push(@startup_msg, "Using HMAC-SHA256 for session ID hashing");
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

# Check vital config options
&update_vital_config();

# Check if already running via the PID file. In foreground mode, systemd or
# the socket bind owns duplicate-start detection.
if (!$config{'nofork'} && !$nofork_argv && open(PIDFILE, $config{'pidfile'})) {
	my $already = <PIDFILE>;
	close(PIDFILE);
	chomp($already);
	$already =~ s/^\s+|\s+$//g;
	if ($already =~ /^\d+$/ && $already != $$ && kill(0, $already)) {
		die "Webmin is already running with PID $already\n";
		}
	}

$sidname = $config{'sidname'};

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
			my $pam_ret = $pamh->pam_authenticate();
			if ($pam_conv_func_called ||
			    $pam_ret == PAM_SUCCESS()) {
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
	}
if ($config{'pam_only'} && !$use_pam) {
	foreach $msg (@startup_msg) {
		&log_error($msg);
		}
	&log_error("PAM use is mandatory, but could not be enabled!");
	&log_error("no_pam and pam_only both are set!") if ($config{no_pam});
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
local $rand1 = &generate_random_id(1);
local $rand2 = &generate_random_id(1);
if ($rand1 eq $rand2) {
	$bad_urandom = 1;
	push(@startup_msg,
	     "Random number generator file /dev/urandom is not reliable");
	}

# Check if we can call sudo
if ($config{'sudo'} && &has_command("sudo")) {
	$use_sudo = 1;
	}

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
		&log_error("SSL key file $config{'keyfile'} does not exist");
		}
	$use_ssl = 0;
	}
elsif ($config{'certfile'} && !-r $config{'certfile'}) {
	# Cert file doesn't exist!
	&log_error("SSL cert file $config{'certfile'} does not exist");
	$use_ssl = 0;
	}
if ($use_ssl) {
	$client_certs = 0 if (!-r $config{'ca'} || !%certs);
	$err = &setup_ssl_contexts();
	die $err if ($err);
	}

# Load gzip library if enabled
if ($config{'gzip'} eq '1') {
	eval "use Compress::Zlib";
	if (!$@) {
		$use_gzip = 1;
		}
	}

# Read websockets configs
&parse_websockets_config();

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
		local $msg = ucfirst($config{'pam'});
		$msg .= $ENV{'STARTED'}++ ?
		    " reloaded configuration" : " starting";
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
foreach $pl (split(/\s+/, $config{'preload'})) {
	($pkg, $lib) = split(/=/, $pl);
	$pkg =~ s/[^A-Za-z0-9]/_/g;
	eval "package $pkg; do '$config{'root'}/$lib'";
	if ($@) {
		&log_error("Failed to pre-load $lib in $pkg : $@");
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
		&log_error("Failed to pre-load $mod : $@");
		}
	}
foreach $mod (split(/\s+/, $config{'preuse'})) {
	eval "use $mod;";
	if ($@) {
		&log_error("Failed to pre-load $mod : $@");
		}
	}

# Open debug log if set
&open_debug_to_log("miniserv.pl starting ..\n");

# Write out (empty) blocked hosts file
&write_blocked_file();

# Initially read webmin cron functions and last execution times
&read_webmin_crons();
%webmincron_last = ( );
&read_file($config{'webmincron_last'}, \%webmincron_last);

# Pre-cache lang files
&precache_files();

# Clear any flag files to prevent restart loops
unlink($config{'restartflag'}) if ($config{'restartflag'});
unlink($config{'reloadflag'}) if ($config{'reloadflag'});
unlink($config{'stopflag'}) if ($config{'stopflag'});

# Build list of sockets to listen on
@listening_on_ports = ();
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
		push(@listening_on_ports, $sockets[$i]->[1]);
		$ipv6fhs{$fh} = $sockets[$i]->[2] eq PF_INET() ? 0 : 1;
		}
	}
foreach $se (@sockerrs) {
	&log_error($se);
	}

# If all binds failed, try binding to any address
if (!@socketfhs && !$tried_inaddr_any) {
	&log_error("Falling back to listening on any address");
	$fh = "MAIN";
	socket($fh, PF_INET(), SOCK_STREAM, $proto) ||
		die "Failed to open socket : $!";
	setsockopt($fh, SOL_SOCKET, SO_REUSEADDR, pack("l", 1));
	if (!bind($fh, pack_sockaddr_in($sockets[0]->[1], INADDR_ANY))) {
		&log_error("Failed to bind to port $sockets[0]->[1] : $!");
		exit(1);
		}
	listen($fh, &get_somaxconn());
	push(@socketfhs, $fh);
	}
elsif (!@socketfhs && $tried_inaddr_any) {
	&log_error("Could not listen on any ports");
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
					unlink($config{'errorlog'})
						if ($config{'errorlog'} &&
						    $config{'errorlog'} ne '-');
					unlink($config{'debuglog'})
						if ($config{'debuglog'});
					}
				}
			else {
				$write_logtime = 1;
				}
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
	&open_session_db();
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
	# Periodically re-open error and debug logs if deleted via regular
	# log clearing
	if ($config{'errorlog'} && $config{'errorlog'} ne '-' &&
	    !-e $config{'errorlog'}) {
		&redirect_stderr_to_log();
		}
	if ($config{'debuglog'} && !-e $config{'debuglog'}) {
		&open_debug_to_log();
		}

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
	local $sel = select($rmask, undef, undef, 2);

	# Check the flag files
	if ($config{'restartflag'} && -r $config{'restartflag'}) {
		unlink($config{'restartflag'});
		$need_restart = 1;
		}
	if ($config{'reloadflag'} && -r $config{'reloadflag'}) {
		unlink($config{'reloadflag'});
		$need_reload = 1;
		}
	if ($config{'stopflag'} && -r $config{'stopflag'}) {
		unlink($config{'stopflag'});
		$need_stop = 1;
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
	if ($need_stop) {
		# Stop flag file created
		&term_handler();
		}
	local $time_now = time();

	# Clean up processes that have been idle for too long, if configured
	if ($config{'maxlifetime'}) {
		foreach my $c (@childpids) {
			my $age = time() - $childstarts{$c};
			if ($childstarts{$c} &&
			    $age > $config{'maxlifetime'}) {
				kill(9, $c);
				&log_error("Killing long-running process $c after $age seconds");
				delete($childstarts{$c});
				}
			}
		}

	# Clean up finished processes
	local $pid;
	do {	$pid = waitpid(-1, WNOHANG);
		@childpids = grep { $_ != $pid } @childpids;
		} while($pid != 0 && $pid != -1);
	@childpids = grep { kill(0, $_) } @childpids;
	my %childpids = map { $_, 1 } @childpids;
	foreach my $s (keys %childstarts) {
		delete($childstarts{$s}) if (!$childpids{$s});
		}

	# Clean up connection counts from IPs that are no longer in use
	foreach my $ip (keys %ipconnmap) {
		$ipconnmap{$ip} = [ grep { $childpids{$_} } @{$ipconnmap{$ip}}];
		}
	foreach my $net (keys %netconnmap) {
		$netconnmap{$net} = [ grep { $childpids{$_} } @{$netconnmap{$net}}];
		}

	# run the unblocking procedure to check if enough time has passed to
	# unblock hosts that never been blocked because of password failures
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
			if ($ltime && $time_now - $ltime > 7*24*60*60) {
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
			print DEBUG "accept returned ",length($acptaddr),"\n";
			next if (!$acptaddr);
			binmode(SOCK);

			# Work out IP and port of client
			local ($peerb, $peera, $peerp) =
				&get_address_ip($acptaddr, $ipv6fhs{$s});
			print DEBUG "peera=$peera peerp=$peerp\n";

			# Check the number of connections from this IP
			$ipconnmap{$peera} ||= [ ];
			$ipconns = $ipconnmap{$peera};
			if ($config{'maxconns_per_ip'} >= 0 &&
			    @$ipconns > $config{'maxconns_per_ip'}) {
				&log_error("Too many connections (",scalar(@$ipconns),") from IP $peera");
				close(SOCK);
				next;
				}

			# Also check the number of connections from the network
			($peernet = $peera) =~ s/\.\d+$/\.0/;
			$netconnmap{$peernet} ||= [ ];
			$netconns = $netconnmap{$peernet};
			if ($config{'maxconns_per_net'} >= 0 &&
			    @$netconns > $config{'maxconns_per_net'}) {
				&log_error("Too many connections (",scalar(@$netconns),") from network $peernet");
				close(SOCK);
				next;
				}

			# create pipes
			local ($PASSINr, $PASSINw, $PASSOUTr, $PASSOUTw);
			if ($need_pipes) {
				($PASSINr, $PASSINw, $PASSOUTr, $PASSOUTw) =
					&allocate_pipes();
				}

			# Work out the local IP
			(undef, $locala) = &get_socket_ip(SOCK, $ipv6fhs{$s});
			print DEBUG "locala=$locala\n";

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
				&log_error(
				    "Failed to get local socket name : $!");
				close(SOCK);
				next;
				}
			$port = $sockets[$sn]->[1];

			# fork the subprocess
			local $handpid;
			if (!($handpid = fork())) {
				# setup signal handlers
				print DEBUG "in subprocess\n";
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
					my $byte = '';
					# Look at the first byte of the socket
					# buffer but don't consume it
					recv(SOCK, $byte, 1, MSG_PEEK);
					if (length($byte) &&
					    # Check if the first byte is a TLS
					    (ord($byte) == 0x16 ||
					    # Check if the first byte is SSL
					    (ord($byte) & 0x80))) {
						($ssl_con,
						 $ssl_certfile,
						 $ssl_keyfile,
						 $ssl_cn,
						 $ssl_alts) =
							&ssl_connection_for_ip(
							    SOCK, $ipv6fhs{$s});
						print DEBUG "ssl_con returned ".
							"$ssl_con\n";
						$ssl_con || exit;
						}
					else {
						$use_ssl = 0;
						}
					}

				print DEBUG
				  "main: Starting handle_request loop pid=$$\n";
				while(&handle_request($peera, $locala,
						      $ipv6fhs{$s})) {
					# Loop until keepalive stops
					}
				print DEBUG
				  "main: Done handle_request loop pid=$$\n";
				if ($use_ssl) {
					Net::SSLeay::shutdown($ssl_con);
					}
				shutdown(SOCK, 1);
				close(SOCK);
				close($PASSINw); close($PASSOUTw);
				exit;
				}
			push(@childpids, $handpid);
			$childstarts{$handpid} = time();
			push(@$ipconns, $handpid);
			push(@$netconns, $handpid);
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

		# Check for any rate limits
		my $ratelimit = 0;
		if ($last_udp{$fromip} &&
		    time() - $last_udp{$fromip} < $config{'listen_delay'}) {
			$ratelimit = 1;
			}
		else {
			$last_udp{$fromip} = time();
			}

		if (!$ratelimit &&
		    (!@deny || !&ip_match($fromip, $toip, @deny)) &&
		    (!@allow || &ip_match($fromip, $toip, @allow))) {
			local $listenhost = &get_socket_name(LISTEN, 0);
			send(LISTEN, "$listenhost:$config{'port'}:".
				 ($use_ssl ? 1 : 0).":".
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
			local $inline = &sysread_line($infd);
			if ($inline) {
				print DEBUG "main: inline $inline";
				}
			else {
				print DEBUG "main: inline EOF\n";
				}

			# Search for two-factor authentication flag
			# being passed, to mark the call as safe
			$inline =~ /^delay\s+(\S+)\s+(\S+)\s+(\d+)\s+(nolog)/;
			local $nolog = $4;

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
					# Login failed..
					$hostfail{$2}++ if (!$nolog);
					$userfail{$1}++ if (!$nolog && $1 ne "-");
					$blocked = 0;

					# Add the host to the block list,
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

					# Add the user to the user block list,
					# if configured
 					if ($1 ne "-" &&
					    $config{'blockuser_failures'} &&
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
					if ($1 ne "-" &&
					    $config{'blocklock'} &&
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
				local $vip = $2;
				local $uptime = $3;
				local $skey = $sessiondb{$session_id} ?
						$session_id : 
						&hash_session_id($session_id);
				if (!defined($sessiondb{$skey})) {
					# Session doesn't exist
					print $outfd "0 0\n";
					}
				else {
					local ($user, $ltime, $ip, $lifetime) =
					  split(/\s+/, $sessiondb{$skey});
					local $lot = &get_logout_time($user, $session_id);
					if ($lot &&
					    $time_now - $ltime > $lot*60) {
						# Session has timed out due to
						# idle time being hit
						print $outfd "1 ",($time_now - $ltime),"\n";
						#delete($sessiondb{$skey});
						}
					elsif ($lifetime && $time_now - $ltime > $lifetime) {
						# Session has timed out due to
						# lifetime exceeded
						print $outfd "1 ",($time_now - $ltime),"\n";
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
						# Session is OK, update last time
						# and remote IP
						print $outfd "2 $user\n";
						if ($uptime) {
							$sessiondb{$skey} = "$user $time_now $vip";
							}
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
						&validate_user_caseless(
							$conv->{'user'},
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
				&log_error("Unknown line from pipe $inline");
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
