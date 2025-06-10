#!/usr/local/bin/perl
# Handles remote_* function calls by a faster method. When first called
# as a CGI, forks and starts listening on a port which is returned to the
# client. From then on, direct TCP connections can be made to this port
# to send requests and get replies.

BEGIN { push(@INC, "."); };
use WebminCore;
use POSIX;
use Socket;
$force_lang = $default_lang;
&init_config();
print "Content-type: text/plain\n\n";

# Can this user make remote calls?
if (!&webmin_user_can_rpc()) {
	print "0 Invalid user for RPC\n";
	exit;
	}

# Will IPv6 work?
&get_miniserv_config(\%miniserv);
$use_ipv6 = 0;
if ($miniserv{'ipv6'}) {
	eval "use Socket6";
	$use_ipv6 = 1 if (!$@);
	}

# Find a free port
$port = $miniserv{'port'} || 10000;
$aerr = &allocate_socket(MAIN, $use_ipv6 ? MAIN6 : undef, \$port);
if ($aerr) {
	print "0 $aerr\n";
	exit;
	}
if (open(RANDOM, "/dev/urandom")) {
	local $tmpsid;
	read(RANDOM, $tmpsid, 16);
	$sid = lc(unpack('h*', $tmpsid));
	close RANDOM;
	}
else {
	$sid = time()*$$;
	}
$version = &get_webmin_version();
print "1 $port $sid $version\n";

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
local $rmask;
vec($rmask, fileno(MAIN), 1) = 1;
if ($use_ipv6) {
	vec($rmask, fileno(MAIN6), 1) = 1;
	}
$sel = select($rmask, undef, undef, 60);
if ($sel <= 0) {
	print STDERR "fastrpc: accept timed out\n"
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
$oldsel = select(SOCK);
$| = 1;
select($oldsel);

$rcount = 0;
while(1) {
	# Wait for the request. Wait longer if this isn't the first one
	local $rmask;
	vec($rmask, fileno(SOCK), 1) = 1;
	local $sel = select($rmask, undef, undef, $rcount ? 360 : 60);
	if ($sel <= 0) {
		print STDERR "fastrpc: session timed out\n"
			if ($gconfig{'rpcdebug'});
		last;
		}

	local $line = <SOCK>;
	last if (!$line);
	local ($len, $auth) = split(/\s+/, $line);
	die "Invalid session ID" if ($auth ne $sid);
	local $rawarg;
	while(length($rawarg) < $len) {
		local $got;
		local $rv = read(SOCK, $got, $len - length($rawarg));
		exit if ($rv <= 0);
		$rawarg .= $got;
		}
	print STDERR "fastrpc: raw $rawarg\n" if ($gconfig{'rpcdebug'});
	local $dumper = substr($rawarg, 0, 5) eq '$VAR1' ? 1 : 0;
	local $arg = &unserialise_variable($rawarg);

	# Process it
	local $rv;
	if ($arg->{'action'} eq 'ping') {
		# Just respond with an OK
		print STDERR "fastrpc: ping\n" if ($gconfig{'rpcdebug'});
		$rv = { 'status' => 1 };
		}
	elsif ($arg->{'action'} eq 'check') {
		# Check if some module is supported
		print STDERR "fastrpc: check $arg->{'module'}\n" if ($gconfig{'rpcdebug'});
		$rv = { 'status' => 1,
			'rv' => &foreign_check($arg->{'module'}, undef, undef,
					       $arg->{'api'}) };
		}
	elsif ($arg->{'action'} eq 'config') {
		# Get the config for some module
		print STDERR "fastrpc: config $arg->{'module'}\n" if ($gconfig{'rpcdebug'});
		local %config = &foreign_config($arg->{'module'});
		$rv = { 'status' => 1, 'rv' => \%config };
		}
	elsif ($arg->{'action'} eq 'write') {
		# Transfer data to a local temp file
		local $file = $arg->{'file'} ? $arg->{'file'} :
			      $arg->{'name'} ? &tempname($arg->{'name'}) :
					       &tempname();
		print STDERR "fastrpc: write $file\n" if ($gconfig{'rpcdebug'});
		open(FILE, ">$file");
		binmode(FILE);
		print FILE $arg->{'data'};
		close(FILE);
		$rv = { 'status' => 1, 'rv' => $file };
		}
	elsif ($arg->{'action'} eq 'tcpwrite') {
		# Transfer data to a local temp file over TCP connection
		local $file = $arg->{'file'} ? $arg->{'file'} :
			      $arg->{'name'} ? &tempname($arg->{'name'}) :
					       &tempname();
		print STDERR "fastrpc: tcpwrite $file\n" if ($gconfig{'rpcdebug'});
		local $tsock = time().$$;
		local $tsock6 = $use_ipv6 ? time().$$."v6" : undef;
		local $tport = $port + 1;
		&allocate_socket($tsock, $tsock6, \$tport);
		if (!fork()) {
			# Accept connection in separate process
			print STDERR "fastrpc: tcpwrite $file port $tport\n" if ($gconfig{'rpcdebug'});
			local $rmask;
			vec($rmask, fileno($tsock), 1) = 1;
			if ($use_ipv6) {
				vec($rmask, fileno($tsock6), 1) = 1;
				}
			local $sel = select($rmask, undef, undef, 30);
			exit if ($sel <= 0);
			if (vec($rmask, fileno($tsock), 1)) {
				accept(TRANS, $tsock) || exit;
				}
			elsif ($use_ipv6 && vec($rmask, fileno($tsock6), 1)) {
				accept(TRANS, $tsock6) || exit;
				}
			print STDERR "fastrpc: tcpwrite $file accepted\n" if ($gconfig{'rpcdebug'});
			local $buf;
			local $err;
			if (open(FILE, ">$file")) {
				binmode(FILE);
				print STDERR "fastrpc: tcpwrite $file writing\n" if ($gconfig{'rpcdebug'});
				my $bs = &get_buffer_size();
				while(read(TRANS, $buf, $bs) > 0) {
					local $ok = (print FILE $buf);
					if (!$ok) {
						$err = "Write to $file failed : $!";
						last;
						}
					}
				close(FILE);
				print STDERR "fastrpc: tcpwrite $file written\n" if ($gconfig{'rpcdebug'});
				}
			else {
				print STDERR "fastrpc: tcpwrite $file open failed $!\n" if ($gconfig{'rpcdebug'});
				$err = "Failed to open $file : $!";
				}
			print TRANS $err ? "$err\n" : "OK\n";
			close(TRANS);
			exit;
			}
		close($tsock);
		close($tsock6);
		print STDERR "fastrpc: tcpwrite $file done\n" if ($gconfig{'rpcdebug'});
		$rv = { 'status' => 1, 'rv' => [ $file, $tport ] };
		}
	elsif ($arg->{'action'} eq 'read') {
		# Transfer data from a file
		print STDERR "fastrpc: read $arg->{'file'}\n" if ($gconfig{'rpcdebug'});
		local ($data, $got);
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
		print STDERR "fastrpc: tcpread $arg->{'file'}\n" if ($gconfig{'rpcdebug'});
		if (-d $arg->{'file'}) {
			$rv = { 'status' => 1, 'rv' => [ undef, "$arg->{'file'} is a directory" ] };
			}
		elsif (!open(FILE, "<$arg->{'file'}")) {
			$rv = { 'status' => 1, 'rv' => [ undef, "Failed to open $arg->{'file'} : $!" ] };
			}
		else {
			binmode(FILE);
			local $tsock = time().$$;
			local $tsock6 = $use_ipv6 ? time().$$."v6" : undef;
			local $tport = $port + 1;
			&allocate_socket($tsock, $tsock6, \$tport);
			if (!fork()) {
				# Accept connection in separate process
				local $rmask;
				vec($rmask, fileno($tsock), 1) = 1;
				if ($use_ipv6) {
					vec($rmask, fileno($tsock6), 1) = 1;
					}
				local $sel = select($rmask, undef, undef, 30);
				exit if ($sel <= 0);
				if (vec($rmask, fileno($tsock), 1)) {
					accept(TRANS, $tsock) || exit;
					}
				elsif (vec($rmask, fileno($tsock6), 1)) {
					accept(TRANS, $tsock6) || exit;
					}
				local $buf;
				while(read(FILE, $buf, 1024) > 0) {
					print TRANS $buf;
					}
				close(FILE);
				close(TRANS);
				exit;
				}
			close(FILE);
			close($tsock);
			close($tsock6);
			print STDERR "fastrpc: tcpread $arg->{'file'} done\n" if ($gconfig{'rpcdebug'});
			$rv = { 'status' => 1, 'rv' => [ $arg->{'file'}, $tport ] };
			}
		}
	elsif ($arg->{'action'} eq 'require') {
		# require a library
		print STDERR "fastrpc: require $arg->{'module'}/$arg->{'file'}\n" if ($gconfig{'rpcdebug'});
		eval {
			&foreign_require($arg->{'module'},
					 $arg->{'file'});
			};
		if ($@) {
			print STDERR "fastrpc: require error $@\n" if ($gconfig{'rpcdebug'});
			$rv = { 'status' => 0, 'rv' => $@ };
			}
		else {
			print STDERR "fastrpc: require done\n" if ($gconfig{'rpcdebug'});
			$rv = { 'status' => 1 };
			}
		}
	elsif ($arg->{'action'} eq 'call') {
		# execute a function
		print STDERR "fastrpc: call $arg->{'module'}::$arg->{'func'}(",join(",", @{$arg->{'args'}}),")\n" if ($gconfig{'rpcdebug'});
		local @rv;
		eval {
			local $main::error_must_die = 1;
			@rv = &foreign_call($arg->{'module'},
					    $arg->{'func'},
					    @{$arg->{'args'}});
			};
		if ($@) {
			print STDERR "fastrpc: call error $@\n" if ($gconfig{'rpcdebug'});
			$rv = { 'status' => 0, 'rv' => $@ };
			}
		elsif (@rv == 1) {
			$rv = { 'status' => 1, 'rv' => $rv[0] };
			}
		else {
			$rv = { 'status' => 1, 'arv' => \@rv };
			}
		print STDERR "fastrpc: call $arg->{'module'}::$arg->{'func'} done = ",join(",", @rv),"\n" if ($gconfig{'rpcdebug'});
		}
	elsif ($arg->{'action'} eq 'eval') {
		# eval some perl code
		print STDERR "fastrpc: eval $arg->{'module'} $arg->{'code'}\n" if ($gconfig{'rpcdebug'});
		local $erv;
		if ($arg->{'module'}) {
			local $pkg = $arg->{'module'};
			$pkg =~ s/[^A-Za-z0-9]/_/g;
			$erv = eval "package $pkg;\n".
				   $arg->{'code'}."\n";
			}
		else {
			$erv = eval $arg->{'code'};
			}
		print STDERR "fastrpc: eval $arg->{'module'} $arg->{'code'} done = $rv error = $@\n" if ($gconfig{'rpcdebug'});
		if ($@) {
			$rv = { 'status' => 0, 'rv' => $@ };
			}
		else {
			$rv = { 'status' => 1, 'rv' => $erv };
			}
		}
	elsif ($arg->{'action'} eq 'quit') {
		print STDERR "fastrpc: quit\n" if ($gconfig{'rpcdebug'});
		$rv = { 'status' => 1 };
		}
	else {
		print STDERR "fastrpc: unknown $arg->{'action'}\n" if ($gconfig{'rpcdebug'});
		$rv = { 'status' => 0 };
		}
	$rawrv = &serialise_variable($rv, $dumper);

	# Send back to the client
	print SOCK length($rawrv),"\n";
	print SOCK $rawrv;
	last if ($arg->{'action'} eq 'quit');
	$rcount++;
	}

# allocate_socket(handle, ipv6-handle, &port)
sub allocate_socket
{
local ($fh, $fh6, $port) = @_;
local $proto = getprotobyname('tcp');
if (!socket($fh, PF_INET, SOCK_STREAM, $proto)) {
	return "socket failed : $!";
	}
setsockopt($fh, SOL_SOCKET, SO_REUSEADDR, pack("l", 1));
if ($fh6) {
	if (!socket($fh6, PF_INET6(), SOCK_STREAM, $proto)) {
		return "socket6 failed : $!";
		}
	setsockopt($fh6, SOL_SOCKET, SO_REUSEADDR, pack("l", 1));
	setsockopt($fh6, 41, 26, pack("l", 1));	# IPv6 only
	}
while(1) {
	$$port++;
	if ($$port < 0 || $$port > 65535) {
		return "Failed to allocate a free port number: $$port";
		}
	$pack = pack_sockaddr_in($$port, INADDR_ANY);
	next if (!bind($fh, $pack));
	if ($fh6) {
		$pack6 = pack_sockaddr_in6($$port, in6addr_any());
		next if (!bind($fh6, $pack6));
		}
	last;
	}
listen($fh, SOMAXCONN) || return "listen failed : $!";
if ($fh6) {
	listen($fh6, SOMAXCONN) || return "listen6 failed : $!";
	}
return undef;
}
