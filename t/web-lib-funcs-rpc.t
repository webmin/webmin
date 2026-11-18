#!/usr/bin/perl

use strict;
use warnings;
no warnings qw(once redefine);
use Test::More;
use FindBin;

require "$FindBin::Bin/../web-lib-funcs.pl";
local $main::root_directory = "$FindBin::Bin/..";

# Capture a regular RPC connection without opening a network socket.
my @connect_args;
my @response;
local *main::remote_session_name = sub { return 'remote.example:10000.test'; };
local *main::foreign_config = sub { return ( 'capath' => '/test/ca' ); };
local *main::make_http_connection = sub {
	@connect_args = @_;
	return { 'mock' => 1 };
	};
local *main::write_http_connection = sub { return 1; };
local *main::read_http_connection = sub { return shift(@response); };
local $main::remote_error_handler = sub { die "$_[0]\n"; };

my $reply = main::serialise_variable({ 'status' => 1, 'rv' => 'ok' });
@response = ("HTTP/1.0 200 OK\r\n", "\r\n", $reply, undef);
my $rv = main::remote_rpc_call(
	{ 'host' => 'remote.example', 'ip' => '192.0.2.10', 'port' => 10000,
	  'ssl' => 1, 'checkssl' => 1, 'user' => 'root', 'pass' => 'secret' },
	{ 'action' => 'ping' });

is($rv, 'ok', 'regular RPC response is returned');
is($connect_args[3], 'POST', 'regular RPC uses POST');
is($connect_args[4], '/rpc.cgi', 'regular RPC uses the expected endpoint');
is_deeply($connect_args[7],
	{ 'host' => 'remote.example', 'self' => 1, 'capath' => '/test/ca' },
	'regular RPC applies certificate verification requirements');

# The automatic fast-RPC probe must use the submitted certificate settings.
{
	local $INC{'./servers-lib.pl'} = 1;
	local %main::access = ( edit => 1, add => 1 );
	local *main::ReadParse = sub { };
	local *main::error_setup = sub { };
	local *main::error = sub { die "$_[0]\n" };
	local *main::get_server = sub { { id => 123, host => 'old.example' } };
	local *main::foreign_config = sub { %main::config };
	local *main::can_use_server = sub { 1 };
	local *main::to_ipaddress = sub { '192.0.2.10' };
	local *main::webmin_log = sub { };
	local *main::redirect = sub { };
	local *main::close_http_connection = sub { };
	my ($saved, $writes, $reject);
	local *main::save_server = sub { $saved = { %{$_[0]} } };
	# A failed TLS check returns an error string, never a connection handle.
	local *main::make_http_connection = sub {
		@connect_args = @_;
		return $reject && $_[7]
			? 'Invalid SSL certificate : fixture' : { };
		};
	local *main::write_http_connection = sub { $writes .= $_[1] };
	for my $case (
		[ 'checked with CA path', 1, '/test/ca', 0, 2,
		  { host => 'remote.example', self => 1,
		    capath => '/test/ca' } ],
		[ 'checked without CA path', 1, '', 0, 2,
		  { host => 'remote.example', self => 1 } ],
		[ 'unchecked', 0, '/test/ca', 0, 2, undef ],
		[ 'certificate rejected', 1, '/test/ca', 1, 2,
		  { host => 'remote.example', self => 1,
		    capath => '/test/ca' } ],
		[ 'explicit fast', 1, '/test/ca', 0, 1, undef ],
		[ 'explicit slow', 1, '/test/ca', 0, 0, undef ]) {
		# Reset settings, responses and captured writes for each save.
		my ($name, $checkssl, $capath, $invalid, $fast, $reqs) = @$case;
		local %main::config = ( capath => $capath );
		local %main::in = ( id => 123, host => 'remote.example',
			port => 10000, ssl => 1, checkssl => $checkssl,
			mode => 1, fast => $fast, wuser => 'fixture',
			wpass => 'fixture-password' );
		@connect_args = ();
		@response = ("HTTP/1.0 404 Not Found\r\n");
		($saved, $writes, $reject) = ( undef, '', $invalid );
		do "$FindBin::Bin/../servers/save_serv.cgi";
		my $error = $@;
		is_deeply($connect_args[7], $reqs,
			  "$name: certificate settings");
		is(scalar(@connect_args) ? 1 : 0, $fast == 2 ? 1 : 0,
		   "$name: only automatic mode probes");
		is($writes =~ /Authorization: basic / ? 1 : 0,
		   $fast == 2 && !$invalid ? 1 : 0,
		   "$name: login requires an accepted connection");
		if ($fast == 2) {
			# Failed SSL detection must leave the record untouched.
			like($error, $invalid ? qr/Invalid SSL certificate/ :
				qr/HTTP error/,
				"$name: probe error reaches the caller");
			ok(!defined($saved),
			   "$name: failed probe saves nothing");
			}
		else {
			# Explicit choices do not run an automatic probe.
			is($error, '', "$name: save succeeds");
			is($saved->{'fast'}, $fast,
			   "$name: explicit mode is preserved");
			}
		}
	# Text from the remote server must not reach the error page as markup.
	local %main::config = ( capath => '' );
	local %main::in = ( id => 123, host => 'remote.example',
		port => 10000, ssl => 1, checkssl => 0, mode => 1,
		fast => 2, wuser => 'fixture', wpass => 'fixture-password' );
	@response = ( "HTTP/1.0 200 OK\r\n", "\r\n",
		      "<script>alert(1)</script>\n", undef );
	($saved, $writes, $reject) = ( undef, '', 0 );
	do "$FindBin::Bin/../servers/save_serv.cgi";
	like($@, qr/Bad response.*&lt;script&gt;/,
	     'remote text in a probe error is escaped');
	unlike($@, qr/<script>/, 'probe error carries no remote markup');
	ok(!defined($saved), 'bad probe reply saves nothing');
	}


# Reject peers without TLS fast RPC before sending application calls.
{
	local %main::fast_fh_cache;
	local %main::remote_rpc_ssl;
	my (@connections, @writes, $closed);
	# close_http_connection(connection): count released startup connections.
	local *main::close_http_connection = sub { $closed++ };
	# make_http_connection(args): record attempted connections.
	local *main::make_http_connection = sub {
		push(@connections, [ @_ ]);
		return { mock => 1 };
		};
	local *main::write_http_connection = sub { push(@writes, $_[1]); 1 };
	local *main::open_socket = sub { die "Unexpected plaintext socket\n" };
	my $server = { host => 'remote.example', port => 10000, ssl => 1,
		fast => 1, user => 'root', pass => 'fixture' };
	# Cover old greetings and the new TLS setup error.
	for my $case (
		[ "1 10001 token 2.670\n", qr/not supported.*upgrade Webmin/ ],
		[ "0 TLS fast RPC requires HTTPS and a TLS key ".
		  "on Webmin itself\n",
		  qr/requires HTTPS and a TLS key/ ]) {
		for my $throws (0, 1) {
			# remote_error_handler(error): test returning and dying.
			my $error;
			local $main::remote_error_handler = sub {
				$error = $_[0];
				die "$error\n" if ($throws);
				return undef;
				};
			# Keep fast RPC selected even after repeated failures.
			for (1..2) {
				@connections = @writes = ();
				$closed = 0;
				@response = ( "HTTP/1.0 200 OK\r\n",
					      "\r\n", $case->[0] );
				my $result = eval {
					main::remote_rpc_call($server,
						{ action => 'ping' });
					};
				# Failure keeps fast RPC and closes HTTPS.
				like($error, $case->[1],
				     'unsupported fast TLS reports its cause');
				ok(!defined($result), 'no result on failure');
				is_deeply([ map {
					[ $_->[2], $_->[4] ]
					} @connections ],
					[ [ 1, '/fastrpc.cgi?tls=1' ] ],
					'failure never calls regular RPC');
				is($closed, 1, 'failed startup closes HTTPS');
				is($server->{'fast'}, 1, 'fast RPC stays set');
				ok(!%main::fast_fh_cache, 'no session cached');
				}
			}
		}
	# Invalid replies must fail without another connection attempt.
	for my $startup ("0 Invalid user for RPC\n", "garbled\n") {
		@connections = ();
		$closed = 0;
		@response = ("HTTP/1.0 200 OK\r\n", "\r\n", $startup, undef);
		eval { main::remote_rpc_call($server, { action => 'ping' }); };
		ok($@, 'invalid startup fails');
		is($closed, 1, 'invalid startup closes the HTTPS connection');
		is(scalar(@connections), 1, 'invalid startup does not retry over HTTPS');
		}
}

# A certificate mismatch must stop the client before sending its token.
{
	local %main::fast_fh_cache;
	local *main::close_http_connection = sub { };
	local *main::open_socket = sub { };
	local *main::rpc_tls_fingerprint = sub { 'bootstrap-certificate' };
	local *main::rpc_tls_context = sub { 1 };
	local *Net::SSLeay::CTX_free = sub { };
	my ($writes, $connections) = (0, 0);
	# make_http_connection(args): count startup and any unwanted fallback.
	local *main::make_http_connection = sub {
		$connections++;
		return { mock => 1 };
		};
	# Count writes after start(socket, ...) rejects the certificate.
	local *main::write_ssl_connection = sub { $writes++ };
	local *main::rpc_tls_start = sub {
		die "RPC TLS certificate differs from the HTTPS certificate\n";
		};
	@response = ("HTTP/1.0 200 OK\r\n", "\r\n",
		"1 10001 token 2.671 TLS1\n");
	# A failed handshake must stop before sending any control payload.
	eval { main::remote_rpc_call({ host => 'remote.example', port => 10000,
		ssl => 1, fast => 1, user => 'root', pass => 'fixture' },
		{ action => 'ping' }); };
	like($@, qr/certificate differs/, 'secondary certificate mismatch is fatal');
	is($writes, 0, 'no RPC data is sent before certificate matching');
	is($connections, 1, 'certificate failure cannot select fallback');
}


# A failed transport probe must stop even when the caller's error hook returns.
{
	local %main::remote_rpc_ssl;
	my ($calls, $error);
	local *main::is_readonly_mode = sub { 0 };
	local $main::remote_error_handler = sub { $error = $_[0]; };
	# remote_rpc_call(server, request): fail through a
	# nonthrowing error hook.
	local *main::remote_rpc_call = sub {
		$calls++;
		return $main::remote_error_handler->('probe rejected');
		};
	my $rv = main::remote_write({ host => 'remote.example', port => 10000 },
		'/not-opened', '/not-created');
	is($error, 'probe rejected', 'file transfer reports its failed probe');
	is($calls, 1, 'failed probe does not attempt a file transfer');
	ok(!defined($rv), 'failed probe cannot report a successful filename');
}

# Regular RPC cannot transfer files, with or without SSL.
for my $transfer (\&main::remote_write, \&main::remote_read) {
	for my $ssl (0, 1) {
		for my $throws (0, 1) {
			local %main::fast_fh_cache;
			local %main::remote_rpc_ssl;
			# is_readonly_mode(): allow uploads for this test.
			local *main::is_readonly_mode = sub { 0 };
			# close_http_connection(con): no real handle to close.
			local *main::close_http_connection = sub { };
			my ($error, $sockets, $writes);
			# remote_error_handler(error): test returning and dying.
			local $main::remote_error_handler = sub {
				$error = $_[0];
				die "$error\n" if ($throws);
				return 'error hook returned';
				};
			# open_socket(args): count unwanted file connections.
			local *main::open_socket = sub { $sockets++ };
			# write_http_connection(con, data...): record writes.
			local *main::write_http_connection = sub {
				$writes .= join('', @_[1..$#_]);
				};
			# A successful regular-RPC ping creates no fast session.
			@response = ("HTTP/1.0 200 OK\r\n", "\r\n",
				$reply, undef);
			my $result = eval {
				$transfer->({ host => 'remote.example',
					port => 10000, ssl => $ssl,
					fast => 0, user => 'fixture' },
					'/not-opened', '/not-created');
				};
			# Reject transfers before sending a file command.
			is($error, 'File transfers require fast RPC',
				'regular RPC reports the unsupported transfer');
			ok(!defined($result), 'no filename after rejection');
			ok(!$sockets, 'regular RPC opens no file socket');
			unlike($writes, qr/tcpwrite|tcpread/,
				'regular RPC receives no transfer command');
			}
		}
}

# A first file operation connects once; later transfers reuse that connection.
for my $transfer (\&main::remote_write, \&main::remote_read) {
	local %main::fast_fh_cache;
	local %main::remote_rpc_ssl;
	# is_readonly_mode(): allow uploads in this fixture.
	local *main::is_readonly_mode = sub { 0 };
	my $pings = 0;
	# remote_rpc_call(server, request): model TLS setup and count probes.
	local *main::remote_rpc_call = sub {
		# File requests must use the encrypted transfer helper below.
		die "Unexpected transfer request\n" if ($_[1]->{'action'} ne 'ping');
		$pings++;
		$main::remote_rpc_ssl{'remote.example:10000.test'} = 1;
		$main::fast_fh_cache{'remote.example:10000.test'} = [ 'sid' ];
		return 1;
		};
	# remote_rpc_transfer(server, localfile, [remotefile], [basename],
	#                     writing): identify the encrypted path without I/O.
	local *main::remote_rpc_transfer = sub { 'encrypted' };
	# The first transfer sets up the session; the second must reuse it.
	my $server = { host => 'remote.example', port => 10000, ssl => 1 };
	is($transfer->($server, '/unused', '/unused'), 'encrypted',
		'first file operation selects the encrypted transport');
	is($pings, 1, 'first file operation establishes its connection');
	is($transfer->($server, '/unused', '/unused'), 'encrypted',
		'later file operation keeps the encrypted transport');
	is($pings, 1, 'existing fast connection needs no extra ping');
}

# Failed transfer requests must stop even when the error hook returns.
for my $transfer (\&main::remote_write, \&main::remote_read) {
	# Reuse an open connection so the transfer needs no setup ping.
	local %main::fast_fh_cache = (
		'remote.example:10000.test' => [ 'sid', '2.670' ]);
	local %main::remote_rpc_ssl = ( 'remote.example:10000.test' => 0 );
	# is_readonly_mode(): allow uploads in this fixture.
	local *main::is_readonly_mode = sub { 0 };
	my ($error, $sockets);
	# remote_error_handler(message): save the error without throwing.
	local $main::remote_error_handler = sub { $error = $_[0] };
	# remote_rpc_call(server, request): reject the file transfer request.
	local *main::remote_rpc_call = sub {
		return $main::remote_error_handler->('transfer rejected');
		};
	# open_socket(host, port, handle, [&error], [bind-ip],
	#             [address-family]):
	# Count file connections that should never be attempted after failure.
	local *main::open_socket = sub { $sockets++ };
	# A rejected request must not open a file or a transfer socket.
	my $rv = $transfer->({ host => 'remote.example', port => 10000,
		ssl => 0, fast => 1, user => 'root', pass => 'fixture' },
		'/not-opened', '/not-created');
	is($error, 'transfer rejected', 'transfer reports the RPC error');
	ok(!defined($rv), 'returning error handler cannot report success');
	ok(!$sockets, 'failed transfer request opens no file socket');
}

# Missing Net::SSLeay must be reported clearly.
{
	local @INC;
	local %INC = %INC;
	delete($INC{'Net/SSLeay.pm'});
	eval { main::rpc_tls_context(); };
	like($@, qr/requires the Net::SSLeay Perl module/,
		'missing TLS module is reported clearly');
}

# Loading through a relative path must survive chdir and optional modules.
for my $without_hires (0, 1) {
	open(my $child, '-|', $^X, '-e', q{
		BEGIN {
			# @INC hook(self, module): reject Time::HiRes
			# only in the missing-module case.
			unshift(@INC, sub {
				die "Time::HiRes unavailable\n"
					if ($ARGV[1] && $_[1] eq 'Time/HiRes.pm');
				return;
				});
			}
		# Load relatively, then move away before the first RPC call.
		our $root_directory = $ARGV[0];
		chdir("$root_directory/t") or die $!;
		require '../web-lib-funcs.pl';
		chdir('/tmp') or die $!;
		# Stub HTTP I/O to test library loading without a network.
		our $remote_error_handler = sub { die $_[0]; };
		*make_http_connection = sub { { } };
		*write_http_connection = sub { };
		*close_http_connection = sub { };
		my @reply = ("HTTP/1.0 200 OK\r\n", "\r\n",
			serialise_variable({ status => 1, rv => 'ok' }));
		*read_http_connection = sub { shift(@reply) };
		# The TLS clock must also work without the optional module.
		die "TLS clock unavailable" unless ssl_connection_time() > 0;
		# Plain RPC must work regardless of Time::HiRes availability.
		print remote_rpc_call({ host => 'fixture', port => 10000,
			user => 'fixture', fast => 0 }, { action => 'ping' });
		}, "$FindBin::Bin/..", $without_hires) or die $!;
	my $output = do { local $/; <$child> };
	close($child);
	is($?, 0, "RPC loads after chdir, Time::HiRes hidden=$without_hires");
	is($output, 'ok', 'plain RPC still returns its response');
	}

# A ping must be answered within a bounded time. Other commands wait as before.
{
	local %main::fast_fh_cache;
	local %main::remote_rpc_ssl;
	local *main::close_http_connection = sub { };
	local *main::open_socket = sub { };
	local *main::rpc_tls_fingerprint = sub { 'certificate' };
	local *main::rpc_tls_context = sub { 1 };
	local *Net::SSLeay::CTX_free = sub { };
	my $con = { timeout => 60 };
	local *main::rpc_tls_start = sub { $con };
	local *main::write_ssl_connection = sub { };
	my @waits;
	# read_ssl_connection(connection, bytes, wait): record the timeout.
	local *main::read_ssl_connection = sub {
		return $reply if (defined($_[1]));
		push(@waits, [ $_[2] ? 1 : 0, $_[0]->{'timeout'} ]);
		return length($reply)."\n";
		};
	@response = ("HTTP/1.0 200 OK\r\n", "\r\n",
		"1 10001 token 2.671 TLS1\n");
	my $server = { host => 'remote.example', port => 10000, ssl => 1,
		fast => 1, user => 'root', pass => 'fixture' };
	# A ping's shorter deadline must not leak into the following command.
	main::remote_rpc_call($server, { action => 'ping' });
	main::remote_rpc_call($server, { action => 'check', module => 'webmin' });
	is_deeply(\@waits, [ [ 0, 30 ], [ 1, 60 ] ],
		'only a ping has a bounded wait for its reply');
	is($con->{'timeout'}, 60, 'the shorter ping deadline ends with the ping');
	# Password rotation leaves an authenticated session usable.
	$server->{'pass'} = 'rotated';
	is(main::remote_rpc_call($server, { action => 'check', module => 'webmin' }),
		'ok', 'password changes preserve the authenticated session');
	# Small configured timeouts must also shorten the ping wait.
	$con->{'timeout'} = 3;
	main::remote_rpc_call($server, { action => 'ping' });
	is($waits[-1]->[1], 1, 'a short RPC timeout shortens the ping deadline');
}

# File transfers report each chunk, so the caller can ping its control session.
{
	my ($sent, $received) = (0, 0);
	local *main::write_ssl_connection = sub { };
	open(my $in, '<', \('x' x 150000)) or die $!;
	main::rpc_tls_send_file({ }, $in, sub { $sent++ });
	is($sent, 3, 'upload progress is reported after each chunk');
	# Feed two data frames and an end marker to the real receiver.
	my @frames = ("5\n", 'hello', "3\n", 'abc', "0\n");
	local *main::read_ssl_connection = sub { shift(@frames) };
	open(my $out, '>', \my $copy) or die $!;
	main::rpc_tls_receive_file({ }, $out, sub { $received++ });
	is($received, 2, 'download progress is reported after each chunk');
	is($copy, 'helloabc', 'reported chunks are still written');
}

# A long TLS transfer pings the idle control session, so NAT keeps it open.
for my $lost_session (0, 1) {
	open(my $child, '-|', $^X, '-e', q{
		# Advance a fake clock to avoid waiting for keepalives.
		our $now = 1000;
		BEGIN { *CORE::GLOBAL::time = sub { $main::now }; }
		our $root_directory = $ARGV[0];
		require "$root_directory/web-lib-funcs.pl";
		our $remote_error_handler = sub { die $_[0]; };
		# Create a TLS session entry to reuse in both transfer cases.
		my $server = { host => 'fixture', port => 10000, ssl => 1,
			fast => 1, user => 'fixture' };
		my $sn = remote_session_name($server);
		our %remote_rpc_ssl = ( $sn => 1 );
		our %fast_fh_cache = ( $sn => [ 'sid', '2.700',
			{ host => '192.0.2.1', peer => 'p', sni => 'fixture' } ] );
		my $entry = $fast_fh_cache{$sn};
		my $pings = 0;
		no warnings 'redefine';
		*is_readonly_mode = sub { 0 };
		*open_socket = sub { };
		# remote_rpc_call(server, request): count pings or
		# return a file port.
		*remote_rpc_call = sub {
			if ($_[1]->{'action'} eq 'ping') {
				# Count pings before simulating a timeout.
				$pings++;
				# Model a timeout closing the original control session.
				if ($ARGV[1]) {
					delete($fast_fh_cache{$sn});
					die "RPC TLS connection timed out\n";
					}
				return 1;
				}
			return [ '/remote', 10003, 'sid' ];
			};
		# Stub TLS I/O while testing the real transfer code.
		*Net::SSLeay::CTX_free = sub { };
		*main::rpc_tls_context = sub { 1 };
		*main::rpc_tls_start = sub { { } };
		*main::rpc_tls_close = sub { };
		*main::write_ssl_connection = sub { };
		*main::read_ssl_connection = sub { "OK\n" };
		# send_file/receive_file(connection, file,
		#                       progress)
		# Report four chunks, with delays before the second and fourth.
		*main::rpc_tls_send_file = *main::rpc_tls_receive_file = sub {
			my $progress = $_[2];
			&$progress();
			$now += 31;
			&$progress();
			&$progress();
			$now += 31;
			&$progress();
			};
		# Start both transfers with the same session state.
		remote_write($server, "$root_directory/version", '/remote');
		my $upload = $pings;
		$fast_fh_cache{$sn} = $entry;
		remote_read($server, '/dev/null', '/remote');
		print "$upload ", $pings - $upload;
		}, "$FindBin::Bin/..", $lost_session) or die $!;
	my $output = do { local $/; <$child> };
	close($child);
	is($?, 0, 'TLS transfers with progress reports finish');
	is($output, $lost_session ? '1 1' : '2 2', $lost_session
		? 'transfers stop keepalives after losing the control session'
		: 'control session is pinged every 30 seconds');
}

done_testing();
