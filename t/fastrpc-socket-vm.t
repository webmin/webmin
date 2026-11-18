#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use FindBin;
use IO::Socket::INET;
use POSIX ();

plan skip_all => 'Set WEBMIN_RPC_TLS_VM_TEST=1 on a disposable Linux VM'
	unless ($ENV{'WEBMIN_RPC_TLS_VM_TEST'} || '') eq '1';
$^O eq 'linux' && $< == 0 or die 'Disposable root Linux VM required';
my $root = $ENV{'WEBMIN_RPC_TLS_SOURCE'} || "$FindBin::Bin/..";
require "$root/web-lib-funcs.pl";

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
