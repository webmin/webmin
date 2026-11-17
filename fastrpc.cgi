#!/usr/local/bin/perl
# Start a worker for remote_* calls and return its TCP port to the client.
# File transfers use separate sockets. Clients requesting TLS use it on both
# channels, with the same certificate as HTTPS.

BEGIN { push(@INC, "."); };
use WebminCore;
use POSIX;
use Socket;

$main::allow_rpc_only = 1;
$force_lang = $default_lang;
&init_config();

my $DEFAULT_RPC_TIMEOUT = 60;
my $DEFAULT_RPC_IDLE_FACTOR = 6;

print "Content-type: text/plain\n\n";

# Can this user make remote calls?
if (!&webmin_user_can_rpc()) {
	print "0 Invalid user for RPC\n";
	exit;
	}

# Load the settings used by the RPC listeners.
&get_miniserv_config(\%miniserv);
# Remove the local marker so programs started by RPC calls do not inherit it.
my $local_rpc = delete($ENV{'FASTRPC_RUN_LOCAL'});
$use_ipv6 = 0;
# The built-in local client connects only over IPv4 loopback.
if ($miniserv{'ipv6'} && !$local_rpc) {
	eval "use Socket6";
	$use_ipv6 = 1 if (!$@);
	}

# TLS is requested explicitly. Old clients keep their existing TCP protocol.
# Local workers inherit their caller's CGI environment, not a new request.
&ReadParse() if (!$local_rpc);
my $tls = !$local_rpc && $in{'tls'} eq '1';
my ($tls_ctx, $tls_con);
if ($tls) {
	# If a proxy forwards plain HTTP, this request has no TLS key.
	# The RPC sockets need Webmin to handle HTTPS itself.
	if ($ENV{'HTTPS'} ne 'ON' || !$ENV{'MINISERV_KEYFILE'}) {
		print "0 TLS fast RPC requires HTTPS and a TLS key ".
		      "on Webmin itself\n";
		exit;
		}
	# Use the certificate selected for this HTTPS request, including SNI.
	eval {
		$tls_ctx = &rpc_tls_context(\%miniserv,
			$ENV{'MINISERV_KEYFILE'}, $ENV{'MINISERV_CERTFILE'});
		};
	if ($@) {
		# TLS setup errors must not enable a plaintext listener.
		print "0 $@";
		exit;
		}
	}

# Find a free port
$port = $miniserv{'port'} || 10000;
$aerr = &allocate_socket(MAIN, $use_ipv6 ? MAIN6 : undef, \$port);
if ($aerr) {
	print "0 $aerr\n";
	exit;
	}
if ($tls) {
	# TLS tokens must use the system random source, without a weak fallback.
	$sid = &generate_miniserv_websocket_token(1);
	if (!$sid) {
		print "0 Cannot generate a secure RPC session ID\n";
		exit;
		}
	}
elsif (open(RANDOM, "/dev/urandom")) {
	# Keep the existing token generation for older clients.
	my $tmpsid;
	read(RANDOM, $tmpsid, 16);
	$sid = lc(unpack('h*', $tmpsid));
	close RANDOM;
	}
else {
	# Preserve the legacy fallback for clients using the old protocol.
	$sid = time()*$$;
	}
# Advertise TLS only after the listener and its token are ready.
$version = &get_webmin_version();
print "1 $port $sid $version".($tls ? " TLS1" : "")."\n";

# Timeout
my $rpc_idle_factor = $gconfig{'rpc_idle_factor'} || $DEFAULT_RPC_IDLE_FACTOR;
if ($rpc_idle_factor !~ /^\d+$/ || $rpc_idle_factor < 1) {
	$rpc_idle_factor = $DEFAULT_RPC_IDLE_FACTOR;
	}
my $config_rpc_timeout = $gconfig{'rpc_timeout'} || $DEFAULT_RPC_TIMEOUT;
if ($config_rpc_timeout !~ /^\d+$/ || $config_rpc_timeout < 1) {
	$config_rpc_timeout = $DEFAULT_RPC_TIMEOUT;
	}

# Fork and listen for calls ..
$pid = fork();
if ($pid < 0) {
	die "fork() failed : $!";
	}
elsif ($pid) {
	exit;
	}
untie(*STDIN);
untie(*STDOUT);

# Accept the TCP connection
my $rmask;
vec($rmask, fileno(MAIN), 1) = 1;
if ($use_ipv6) {
	vec($rmask, fileno(MAIN6), 1) = 1;
	}
$sel = select($rmask, undef, undef, $config_rpc_timeout);
if ($sel <= 0) {
	print STDERR "fastrpc[$$]: accept timed out\n"
		if ($gconfig{'rpcdebug'});
	exit;
	}
if (vec($rmask, fileno(MAIN), 1)) {
	$acptaddr = accept(SOCK, MAIN);
	}
elsif ($use_ipv6 && vec($rmask, fileno(MAIN6), 1)) {
	$acptaddr = accept(SOCK, MAIN6);
	}
else {
	die "No connection on any socket!";
	}
die "accept failed : $!" if (!$acptaddr);
my $oldsel = select(SOCK);
$| = 1;
select($oldsel);

if ($tls) {
	# Complete the handshake before reading a session token or request.
	$tls_con = &rpc_tls_start(\*SOCK, $tls_ctx, 1,
		$config_rpc_timeout);
	}

my $rcount = 0;
my %xfer_kids;
while(1) {
	# Clean up the list of waiting sub-processes
	foreach my $p (keys %xfer_kids) {
		my $waited_pid = waitpid($p, POSIX::WNOHANG());
		delete($xfer_kids{$p}) if ($waited_pid > 0 || $waited_pid == -1);
		}

	# Wait for the request. Wait longer if this isn't the first one
	my $rmask;
	vec($rmask, fileno(SOCK), 1) = 1;
	my $timeout = $rcount
			? $config_rpc_timeout * $rpc_idle_factor
			: $config_rpc_timeout;
	# Check buffered TLS data before waiting for another socket event.
	my $sel = $tls && Net::SSLeay::pending($tls_con->{'ssl_con'})
		? 1 : select($rmask, undef, undef, $timeout);
	if ($sel <= 0) {
		# Don't kill the control session while a tcpwrite/tcpread is
		# running
		my $nk = scalar(keys %xfer_kids);
		if ($nk) {
			print STDERR "fastrpc[$$]: idle timeout, but $nk ".
				     "transfer(s) active: ".
				     join(",", sort keys %xfer_kids)."\n"
				if ($gconfig{'rpcdebug'});
			next;
			}
		print STDERR "fastrpc[$$]: session timed out\n"
			if ($gconfig{'rpcdebug'});
		last;
		}

	my ($line, $rawarg);
	if ($tls) {
		# Stop the worker if reading the TLS header fails or times out.
		my $ok = eval {
			$line = &read_ssl_connection($tls_con);
			1;
			};
		last if (!$ok);
		if ($line !~ /^(\d+) (\S+)\n$/) {
			# A malformed header cannot start an RPC request.
			last;
			}
		my ($len, $auth) = ($1, $2);
		if ($auth ne $sid) {
			# Reject the token before reading the request body.
			last;
			}
		# Read the authenticated body, stopping on TLS or timeout errors.
		$ok = eval {
			$rawarg = &read_ssl_connection($tls_con, $len);
			1;
			};
		last if (!$ok);
		}
	else {
		# Preserve the wire protocol used by older and non-SSL clients.
		$line = <SOCK>;
		last if (!$line);
		my ($len, $auth) = split(/\s+/, $line);
		die "Invalid session ID" if ($auth ne $sid);
		while(length($rawarg) < $len) {
			my $got;
			my $rv = read(SOCK, $got, $len - length($rawarg));
			exit if ($rv <= 0);
			$rawarg .= $got;
			}
		}
	print STDERR "fastrpc[$$]: raw $rawarg\n" if ($gconfig{'rpcdebug'});

	# Mirror the request's wire format in the response
	my $dumper = substr($rawarg, 0, 5) eq '$VAR1' ? 1 : 0;
	my $arg = &unserialise_variable($rawarg);

	# Process it
	my $rv;
	if ($arg->{'action'} eq 'ping') {
		# Just respond with an OK
		print STDERR "fastrpc[$$]: ping\n" if ($gconfig{'rpcdebug'});
		$rv = { 'status' => 1 };
		}
	elsif ($arg->{'action'} eq 'check') {
		# Check if some module is supported
		print STDERR "fastrpc[$$]: check $arg->{'module'}\n" if ($gconfig{'rpcdebug'});
		$rv = { 'status' => 1,
			'rv' => &foreign_check($arg->{'module'}, undef, undef,
					       $arg->{'api'}) };
		}
	elsif ($arg->{'action'} eq 'config') {
		# Get the config for some module
		print STDERR "fastrpc[$$]: config $arg->{'module'}\n" if ($gconfig{'rpcdebug'});
		my %config = &foreign_config($arg->{'module'});
		$rv = { 'status' => 1, 'rv' => \%config };
		}
	elsif ($arg->{'action'} eq 'write') {
		# Transfer data to a my temp file
		my $file = $arg->{'file'} ? $arg->{'file'} :
			      $arg->{'name'} ? &tempname($arg->{'name'}) :
					       &tempname();
		print STDERR "fastrpc[$$]: write $file\n" if ($gconfig{'rpcdebug'});
		open(FILE, ">$file");
		binmode(FILE);
		print FILE $arg->{'data'};
		close(FILE);
		$rv = { 'status' => 1, 'rv' => $file };
		}
	elsif ($tls && ($arg->{'action'} eq 'tcpwrite' ||
			$arg->{'action'} eq 'tcpread')) {
		# Every secondary socket uses the control session's TLS
		# identity.
		$rv = &tls_transfer($arg);
		}
	elsif ($arg->{'action'} eq 'tcpwrite') {
		# Transfer data to a my temp file over TCP connection
		my $file = $arg->{'file'} ? $arg->{'file'} :
			      $arg->{'name'} ? &tempname($arg->{'name'}) :
					       &tempname();
		print STDERR "fastrpc[$$]: tcpwrite $file\n" if ($gconfig{'rpcdebug'});
		my $tsock = time().$$;
		my $tsock6 = $use_ipv6 ? time().$$."v6" : undef;
		my $tport = $port + 1;
		&allocate_socket($tsock, $tsock6, \$tport);
		my $cpid = fork();
		if (!defined($cpid)) {
			$rv = { 'status' => 0, 'rv' => "fork() failed : $!" };
			}
		elsif ($cpid == 0) {
			close(SOCK);
			close(MAIN);
			close(MAIN6) if ($use_ipv6);
			# Accept connection in separate process
			print STDERR "fastrpc[$$]: tcpwrite $file port $tport\n"
				if ($gconfig{'rpcdebug'});
			my $rmask;
			vec($rmask, fileno($tsock), 1) = 1;
			if ($use_ipv6) {
				vec($rmask, fileno($tsock6), 1) = 1;
				}
			my $sel = select($rmask, undef, undef, 30);
			exit if ($sel <= 0);
			if (vec($rmask, fileno($tsock), 1)) {
				accept(TRANS, $tsock) || exit;
				}
			elsif ($use_ipv6 && vec($rmask, fileno($tsock6), 1)) {
				accept(TRANS, $tsock6) || exit;
				}
			if ($arg->{'xferauth'}) {
				my $auth = <TRANS>;
				exit if (!defined($auth));
				chomp($auth);
				exit if ($auth ne $sid);
				}
			print STDERR "fastrpc[$$]: tcpwrite $file accepted\n" if ($gconfig{'rpcdebug'});
			my $buf;
			my $err;
			if (open(FILE, ">$file")) {
				binmode(FILE);
				print STDERR "fastrpc[$$]: tcpwrite $file writing\n" if ($gconfig{'rpcdebug'});
				my $bs = &get_buffer_size();
				while(read(TRANS, $buf, $bs) > 0) {
					my $ok = (print FILE $buf);
					if (!$ok) {
						$err = "Write to $file failed : $!";
						last;
						}
					}
				close(FILE);
				print STDERR "fastrpc[$$]: tcpwrite $file written\n" if ($gconfig{'rpcdebug'});
				}
			else {
				print STDERR "fastrpc[$$]: tcpwrite $file open failed $!\n" if ($gconfig{'rpcdebug'});
				$err = "Failed to open $file : $!";
				}
			print TRANS $err ? "$err\n" : "OK\n";
			close(TRANS);
			exit;
			}
		else {
			$xfer_kids{$cpid} = 1;
			print STDERR "fastrpc[$$]: tcpwrite $file started\n"
				if ($gconfig{'rpcdebug'});
			$rv = { 'status' => 1,
				'rv' => [ $file, $tport,
					  $arg->{'xferauth'} ? $sid : undef ] };
			}
		close($tsock);
		close($tsock6) if ($use_ipv6);
		}
	elsif ($arg->{'action'} eq 'read') {
		# Transfer data from a file
		print STDERR "fastrpc[$$]: read $arg->{'file'}\n" if ($gconfig{'rpcdebug'});
		my ($data, $got);
		open(FILE, "<$arg->{'file'}");
		binmode(FILE);
		my $bs = &get_buffer_size();
		while(read(FILE, $got, $bs) > 0) {
			$data .= $got;
			}
		close(FILE);
		$rv = { 'status' => 1, 'rv' => $data };
		}
	elsif ($arg->{'action'} eq 'tcpread') {
		# Transfer data from a file over TCP connection
		print STDERR "fastrpc[$$]: tcpread $arg->{'file'}\n" if ($gconfig{'rpcdebug'});
		if (-d $arg->{'file'}) {
			$rv = { 'status' => 1, 'rv' => [ undef, "$arg->{'file'} is a directory" ] };
			}
		elsif (!open(FILE, "<$arg->{'file'}")) {
			$rv = { 'status' => 1, 'rv' => [ undef, "Failed to open $arg->{'file'} : $!" ] };
			}
		else {
			binmode(FILE);
			my $tsock = time().$$;
			my $tsock6 = $use_ipv6 ? time().$$."v6" : undef;
			my $tport = $port + 1;
			&allocate_socket($tsock, $tsock6, \$tport);
			my $cpid = fork();
			if (!defined($cpid)) {
				$rv = { 'status' => 0, 'rv' => "fork() failed : $!" };
				}
			elsif ($cpid == 0) {
				close(SOCK);
				close(MAIN);
				close(MAIN6) if ($use_ipv6);
				# Accept connection in separate process
				my $rmask;
				vec($rmask, fileno($tsock), 1) = 1;
				if ($use_ipv6) {
					vec($rmask, fileno($tsock6), 1) = 1;
					}
				my $sel = select($rmask, undef, undef, 30);
				exit if ($sel <= 0);
				if (vec($rmask, fileno($tsock), 1)) {
					accept(TRANS, $tsock) || exit;
					}
				elsif (vec($rmask, fileno($tsock6), 1)) {
					accept(TRANS, $tsock6) || exit;
					}
				if ($arg->{'xferauth'}) {
					my $auth = <TRANS>;
					exit if (!defined($auth));
					chomp($auth);
					exit if ($auth ne $sid);
					}
				my $buf;
				while(read(FILE, $buf, 1024) > 0) {
					print TRANS $buf;
					}
				close(FILE);
				close(TRANS);
				exit;
				}
			else {
				$xfer_kids{$cpid} = 1;
				print STDERR "fastrpc[$$]: tcpread $arg->{'file'} ".
					     "started\n"
					     	if ($gconfig{'rpcdebug'});
				$rv = { 'status' => 1,
					'rv' => [ $arg->{'file'}, $tport,
						  $arg->{'xferauth'} ? $sid : undef ] };
				}
			close(FILE);
			close($tsock);
			close($tsock6) if ($use_ipv6);
			}
		}
	elsif ($arg->{'action'} eq 'require') {
		# require a library
		print STDERR "fastrpc[$$]: require $arg->{'module'}/$arg->{'file'}\n" if ($gconfig{'rpcdebug'});
		eval {
			&foreign_require($arg->{'module'},
					 $arg->{'file'});
			};
		if ($@) {
			print STDERR "fastrpc[$$]: require error $@\n" if ($gconfig{'rpcdebug'});
			$rv = { 'status' => 0, 'rv' => $@ };
			}
		else {
			print STDERR "fastrpc[$$]: require done\n" if ($gconfig{'rpcdebug'});
			$rv = { 'status' => 1 };
			}
		}
	elsif ($arg->{'action'} eq 'call') {
		# execute a function
		print STDERR "fastrpc[$$]: call $arg->{'module'}::$arg->{'func'}(",join(",", @{$arg->{'args'}}),")\n" if ($gconfig{'rpcdebug'});
		my @rv;
		eval {
			local $main::error_must_die = 1;
			@rv = &foreign_call($arg->{'module'},
					    $arg->{'func'},
					    @{$arg->{'args'}});
			};
		if ($@) {
			print STDERR "fastrpc[$$]: call error $@\n" if ($gconfig{'rpcdebug'});
			$rv = { 'status' => 0, 'rv' => $@ };
			}
		elsif (@rv == 1) {
			$rv = { 'status' => 1, 'rv' => $rv[0] };
			}
		else {
			$rv = { 'status' => 1, 'arv' => \@rv };
			}
		print STDERR "fastrpc[$$]: call $arg->{'module'}::$arg->{'func'} done = ",join(",", @rv),"\n" if ($gconfig{'rpcdebug'});
		}
	elsif ($arg->{'action'} eq 'eval') {
		# eval some perl code
		print STDERR "fastrpc[$$]: eval $arg->{'module'} $arg->{'code'}\n" if ($gconfig{'rpcdebug'});
		my $erv;
		if ($arg->{'module'}) {
			my $pkg = $arg->{'module'};
			$pkg =~ s/[^A-Za-z0-9]/_/g;
			$erv = eval "package $pkg;\n".
				   $arg->{'code'}."\n";
			}
		else {
			$erv = eval $arg->{'code'};
			}
		print STDERR "fastrpc[$$]: eval $arg->{'module'} $arg->{'code'} done = $rv error = $@\n" if ($gconfig{'rpcdebug'});
		if ($@) {
			$rv = { 'status' => 0, 'rv' => $@ };
			}
		else {
			$rv = { 'status' => 1, 'rv' => $erv };
			}
		}
	elsif ($arg->{'action'} eq 'quit') {
		print STDERR "fastrpc[$$]: quit\n" if ($gconfig{'rpcdebug'});
		$rv = { 'status' => 1 };
		}
	else {
		print STDERR "fastrpc[$$]: unknown $arg->{'action'}\n" if ($gconfig{'rpcdebug'});
		$rv = { 'status' => 0 };
		}
	$rawrv = &serialise_variable($rv, $dumper);

	# Send the response using the transport negotiated at startup.
	if ($tls) {
		# Length prefixes separate replies on the TLS stream.
		&write_ssl_connection($tls_con, length($rawrv)."\n".$rawrv);
		}
	else {
		# Retain the plaintext framing expected by older clients.
		print SOCK length($rawrv),"\n";
		print SOCK $rawrv;
		}
	last if ($arg->{'action'} eq 'quit');
	$rcount++;
	}

# tls_transfer(request)
# Start a file transfer child for a tcpwrite or tcpread request hash.
# Return an RPC result containing the filename, port and session token.
sub tls_transfer
{
my ($arg) = @_;
my $writing = $arg->{'action'} eq 'tcpwrite';
my $file = $arg->{'file'} ? $arg->{'file'} :
	   $arg->{'name'} ? &tempname($arg->{'name'}) : &tempname();
my $source;
if (!$writing) {
	# Report missing or unreadable sources before the client opens its
	# output.
	return { status => 0, rv => "$file is a directory" } if (-d $file);
	open($source, '<', $file) or
		return { status => 0, rv => "Failed to open $file : $!" };
	binmode($source);
	}
# Give this transfer its own listener so control requests can continue.
my $tport = $port + 1;
local (*TLSLISTEN, *TLSLISTEN6);
my $listener = \*TLSLISTEN;
my $listener6 = $use_ipv6 ? \*TLSLISTEN6 : undef;
my $err = &allocate_socket($listener, $listener6, \$tport);
return { status => 0, rv => $err } if ($err);
my $pid = fork();
if (!defined($pid)) {
	# No child owns these listeners if the fork fails.
	close($listener);
	close($listener6) if ($listener6);
	return { status => 0, rv => "fork() failed : $!" };
	}
if (!$pid) {
	# Do not send TLS shutdown on the parent's inherited control connection.
	&rpc_tls_close($tls_con);
	close(MAIN);
	close(MAIN6) if ($use_ipv6);
	my $con;
	my $ok = eval {
		# Wait for a file connection on either enabled address family.
		my $mask = '';
		vec($mask, fileno($listener), 1) = 1;
		vec($mask, fileno($listener6), 1) = 1 if ($listener6);
		select($mask, undef, undef, $config_rpc_timeout) > 0 or
			die "RPC transfer accept timed out\n";
		my $ready = vec($mask, fileno($listener), 1)
			? $listener : $listener6;
		accept(my $socket, $ready) or die "RPC accept failed : $!\n";
		# Require TLS and the token before transferring file contents.
		$con = &rpc_tls_start($socket, $tls_ctx, 1,
			$config_rpc_timeout);
		&read_ssl_connection($con) eq "$sid\n" or
			die "Invalid transfer session ID\n";
		if ($writing) {
			# Only an authenticated transfer may create or truncate
			# a file.
			open(my $fh, '>', $file) or
				die "Failed to open $file : $!\n";
			binmode($fh);
			# Report open failures before the client starts sending
			# file data.
			&write_ssl_connection($con, "OK\n");
			&rpc_tls_receive_file($con, $fh);
			}
		else {
			# The source is already open and ready to send.
			&rpc_tls_send_file($con, $source);
			}
		# Confirm that the transfer and file close succeeded.
		&write_ssl_connection($con, "OK\n");
		1;
		};
	if (!$ok && $con) {
		# Send one error line when the TLS connection is still usable.
		my $error = $@;
		$error =~ s/[\r\n]+/ /g;
		eval { &write_ssl_connection($con, "ERROR $error\n"); };
		}
	# Close only this child's file connection.
	&rpc_tls_close($con) if ($con);
	exit;
	}
# Track the child while releasing the parent's copies of its handles.
$xfer_kids{$pid} = 1;
close($source) if ($source);
close($listener);
close($listener6) if ($listener6);
return { status => 1, rv => [ $file, $tport, $sid ] };
}

# allocate_socket(handle, ipv6-handle, &port)
# Bind listening sockets at the next free port and update port in place.
# Pass undef for ipv6-handle to use IPv4 only. Return an error or undef.
sub allocate_socket
{
my ($fh, $fh6, $port) = @_;
my $proto = getprotobyname('tcp');
if (!socket($fh, PF_INET, SOCK_STREAM, $proto)) {
	# Every listener needs IPv4, including built-in local RPC.
	return "socket failed : $!";
	}
setsockopt($fh, SOL_SOCKET, SO_REUSEADDR, pack("l", 1));
if ($fh6) {
	# A separate IPv6-only socket shares the chosen port with IPv4.
	if (!socket($fh6, PF_INET6(), SOCK_STREAM, $proto)) {
		# Do not advertise IPv6 when its socket cannot be created.
		return "socket6 failed : $!";
		}
	setsockopt($fh6, SOL_SOCKET, SO_REUSEADDR, pack("l", 1));
	setsockopt($fh6, 41, 26, pack("l", 1));	# IPv6 only
	}
while(1) {
	# Try ports after the supplied one, staying within the TCP port range.
	$$port++;
	if ($$port < 0 || $$port > 65535) {
		# Report exhaustion instead of wrapping around to another port.
		return "Failed to allocate a free port number: $$port";
		}
	# Only the built-in local path may bind exclusively to loopback.
	$pack = pack_sockaddr_in($$port,
		$local_rpc ? inet_aton('127.0.0.1') : INADDR_ANY);
	next if (!bind($fh, $pack));
	if ($fh6) {
		# Remote IPv6 clients must reach the same advertised port.
		$pack6 = pack_sockaddr_in6($$port, in6addr_any());
		next if (!bind($fh6, $pack6));
		}
	last;
	}
# Both sockets must be listening before the caller advertises the port.
listen($fh, SOMAXCONN) || return "listen failed : $!";
if ($fh6) {
	# Enable the second address family when requested.
	listen($fh6, SOMAXCONN) || return "listen6 failed : $!";
	}
return undef;
}
