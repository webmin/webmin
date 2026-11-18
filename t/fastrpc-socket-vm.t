#!/usr/bin/perl
# Reproduce RPC listener collisions and closed TLS peers on a disposable VM.
use strict;
use warnings;
use Test::More;
use FindBin;
use Socket;
use Symbol qw(gensym);
use IO::Socket::INET;
use POSIX ();

plan skip_all => 'Set WEBMIN_RPC_TLS_VM_TEST=1 on a disposable Linux VM'
	unless ($ENV{'WEBMIN_RPC_TLS_VM_TEST'} || '') eq '1';
$^O eq 'linux' && $< == 0 or die 'Disposable root Linux VM required';
require Socket6;
Socket6->import();
my $root = $ENV{'WEBMIN_RPC_TLS_SOURCE'} || "$FindBin::Bin/..";
require "$root/web-lib-funcs.pl";

# Load the listener allocator without starting the CGI worker.
open(my $script, '<', "$root/fastrpc.cgi") or die $!;
my $source = do { local $/; <$script> };
close($script);
my ($allocator) = $source =~ /^(sub allocate_socket\n\{.*?^\})/ms;
die 'Cannot find allocate_socket' if (!$allocator);
my $local_rpc = 0;
our ($pack, $pack6);
eval $allocator;
die $@ if ($@);

# Occupy IPv6 only, so the first candidate binds IPv4 before IPv6 fails.
socket(my $busy, Socket6::PF_INET6(), SOCK_STREAM, 0) or die $!;
setsockopt($busy, 41, 26, pack('i', 1)) or die $!;
bind($busy, Socket6::pack_sockaddr_in6(0, Socket6::in6addr_any())) or die $!;
listen($busy, 1) or die $!;
my ($busy_port) = Socket6::unpack_sockaddr_in6(getsockname($busy));
my $port = $busy_port - 1;
my ($v4, $v6) = (gensym(), gensym());
my $error = allocate_socket($v4, $v6, \$port);
ok(!defined($error), 'skips an occupied IPv6 port') or diag($error);
SKIP: {
	# Both listeners must use the same new port and accept connections.
	skip 'Listener allocation failed', 4 if (defined($error));
	cmp_ok($port, '>', $busy_port, 'chooses a later port');
	my ($port4) = unpack_sockaddr_in(getsockname($v4));
	my ($port6) = Socket6::unpack_sockaddr_in6(getsockname($v6));
	is_deeply([ $port4, $port6 ], [ $port, $port ],
		'IPv4 and IPv6 listen on the advertised port');
	my $client4 = IO::Socket::INET->new(PeerAddr => '127.0.0.1',
		PeerPort => $port, Timeout => 2);
	ok($client4, 'IPv4 listener accepts connections');
	socket(my $client6, Socket6::PF_INET6(), SOCK_STREAM, 0) or die $!;
	ok(connect($client6, Socket6::pack_sockaddr_in6($port,
		Socket6::inet_pton(Socket6::AF_INET6(), '::1'))),
		'IPv6 listener accepts connections');
	}
close($v4);
close($v6);
close($busy);

# Keep the test runner alive if the TLS client is killed by SIGPIPE.
my $listener = IO::Socket::INET->new(LocalAddr => '127.0.0.1',
	LocalPort => 0, Listen => 1, ReuseAddr => 1) or die $!;
my $listen_port = $listener->sockport();
my $pid = open(my $output, '-|');
die "fork failed: $!" if (!defined($pid));
if (!$pid) {
	# Match miniserv's CGI signal handling and bound any unexpected hang.
	$| = 1;
	$SIG{'PIPE'} = 'DEFAULT';
	alarm(10);
	close($listener);
	my $socket = IO::Socket::INET->new(PeerAddr => '127.0.0.1',
		PeerPort => $listen_port, Timeout => 2) or die $!;
	# Wait for the peer's close before starting TLS, without a timing race.
	my $n = sysread($socket, my $data, 1);
	die 'Expected peer EOF' if (!defined($n) || $n != 0);
	my $ctx = main::rpc_tls_context();
	eval { main::rpc_tls_start($socket, $ctx, 0, 2, 'unused'); };
	my $error = $@;
	Net::SSLeay::CTX_free($ctx);
	print $error;
	print "PIPE handler restored\n" if ($SIG{'PIPE'} eq 'DEFAULT');
	POSIX::_exit(0);
	}
# Close immediately; the client's TLS handshake must report an error.
my $peer = $listener->accept() or die $!;
close($peer);
close($listener);
my $result = do { local $/; <$output> };
close($output);
is($?, 0, 'closed TLS peer does not kill the caller');
like($result, qr/TLS connection closed or failed/,
	'handshake failure reaches the error handler');
like($result, qr/PIPE handler restored/,
	'handshake preserves the caller\'s signal handler');

done_testing();
