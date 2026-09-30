# Exercise fragmented messages and EAGAIN with real nonblocking socket pairs.
use strict;
use warnings;
use Test::More;
use FindBin qw($Bin);
use lib "$Bin/../vendor_perl";
use Net::WebSocket::Server::Connection;
use Protocol::WebSocket::Frame;
use IO::Socket::UNIX;
use Socket qw(AF_UNIX SOCK_STREAM PF_UNSPEC SOL_SOCKET SO_SNDBUF);
use Fcntl qw(F_GETFL F_SETFL O_NONBLOCK);

# TestPeer supplies the TCP metadata the connection constructor expects.
{
	package TestPeer;
	our @ISA = ('IO::Socket::UNIX');
	sub peerhost { return '127.0.0.1'; }
	sub peerport { return 1; }
}
my ($reader, $writer);
socketpair($reader, $writer, AF_UNIX, SOCK_STREAM, PF_UNSPEC) || die $!;
bless($reader, 'TestPeer');
fcntl($reader, F_SETFL, fcntl($reader, F_GETFL, 0) | O_NONBLOCK) || die $!;
my $client = Net::WebSocket::Server::Connection->new(socket => $reader, server => {});
delete $client->{'handshake'};
$client->{'parser'} = Protocol::WebSocket::Frame->new(max_payload_size => 200000);
my @messages;
$client->on(utf8 => sub { push(@messages, $_[1]); });
my $frame = Protocol::WebSocket::Frame->new(type => 'text', masked => 1,
	max_payload_size => 200000);
my $payload = 'x' x 100000;
$frame->append($payload);
my $bytes = $frame->to_bytes();
# The first read has a full chunk followed by EAGAIN, not an EOF or fatal warning.
is(syswrite($writer, substr($bytes, 0, 8192)), 8192, 'write one exact read chunk');
ok(eval { $client->recv(); 1 }, 'exact chunk does not block or die on EAGAIN');
is(scalar(@messages), 0, 'partial frame is retained');
ok(eval { $client->recv(); 1 }, 'spurious readiness does not disconnect');
for (my $offset = 8192; $offset < length($bytes); $offset += 8192) {
	my $part = substr($bytes, $offset, 8192);
	is(syswrite($writer, $part), length($part), 'write next fragment');
	$client->recv();
	}
is_deeply(\@messages, ['x' x 100000], 'fragmented message arrives once and intact');
# Model SSL's decrypted cache: pending bytes need no new readiness event.
{
	package TestBufferedPeer;
	our @ISA = ('TestPeer');
	our $buffered = 1;
	sub pending { return $buffered--; }
}
bless($reader, 'TestBufferedPeer');
my $buffered_frame = Protocol::WebSocket::Frame->new(type => 'text', masked => 1,
	max_payload_size => 200000);
$buffered_frame->append('y' x 12000);
my $wire = $buffered_frame->to_bytes();
setsockopt($writer, SOL_SOCKET, SO_SNDBUF, pack('i', 65536)) || die $!;
is(syswrite($writer, $wire), length($wire), 'write frame spanning buffered reads');
$client->recv();
is_deeply(\@messages, ['x' x 100000, 'y' x 12000],
	'decrypted buffered bytes are consumed without waiting for select');
close($reader);
close($writer);
done_testing();
