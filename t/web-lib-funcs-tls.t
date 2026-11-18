#!/usr/bin/perl
# Exercise timed TLS I/O without opening network connections.
use strict;
use warnings;
no warnings qw(once redefine);
use Test::More;
use FindBin;
require "$FindBin::Bin/../web-lib-funcs.pl";

my $now = 100;
local *main::ssl_connection_time = sub { $now };
local *Net::SSLeay::ERR_clear_error = sub { };
# Use the default buffer size without reading the workstation's configuration.
local *main::get_miniserv_config = sub { };

subtest 'Timed reads preserve frame boundaries and deadlines' => sub {
	my $h = { ssl_con => 1, timeout => 5 };
	my @input = (undef, 'a', undef, "\n", 'ab', undef, 'cd');
	my (@sizes, @deadlines);
	local *Net::SSLeay::read = sub {
		push(@sizes, $_[1]);
		$now++;
		my $data = shift(@input);
		return ($data, defined($data) ? length($data) : -1);
		};
	local *main::wait_ssl_connection = sub {
		push(@deadlines, $_[2]);
		};
	is(main::read_ssl_connection($h, undef, 1), "a\n",
		'command header waits for its first byte');
	is_deeply(\@deadlines, [ undef, 107 ],
		'partial header uses one deadline after the first byte');
	is(main::read_ssl_connection($h, 4), 'abcd', 'joins partial body reads');
	is_deeply(\@sizes, [ 1, 1, 1, 1, 4, 2, 2 ],
		'reads only remaining frame bytes');
	is($deadlines[2], 110, 'body progress renews the idle deadline');
	is(main::read_ssl_connection($h, 0), '', 'empty body consumes no header');
	is(scalar(@sizes), 7, 'empty body does not read from TLS');
	};

subtest 'Timed reads reject malformed and incomplete frames' => sub {
	my $h = { ssl_con => 1, timeout => 1 };
	local *Net::SSLeay::read = sub { ('x', 1) };
	eval { main::read_ssl_connection($h); };
	like($@, qr/header is too long/, 'oversized header is rejected');
	local *Net::SSLeay::read = sub { (undef, 0) };
	local *Net::SSLeay::get_error = sub { 6 };
	local *Net::SSLeay::ERROR_WANT_READ = sub { 2 };
	local *Net::SSLeay::ERROR_WANT_WRITE = sub { 3 };
	eval { main::read_ssl_connection($h, 4); };
	like($@, qr/connection closed or failed/, 'EOF cannot complete a frame');
	local *Net::SSLeay::get_error = sub { 2 };
	eval { main::wait_ssl_connection($h, -1, $now); };
	like($@, qr/timed out/, 'expired deadline fails before waiting');
	};

subtest 'Timed reads use the configured buffer and preserve the next frame' => sub {
	# get_miniserv_config(config): supply an 8 KiB buffer.
	my $config_reads = 0;
	local *main::get_miniserv_config = sub {
		$config_reads++;
		$_[0]->{'bufsize'} = 8192;
		};
	my $h = { ssl_con => 1, timeout => 5 };
	my $data = 'x' x 70000;
	my $input = $data.'NEXT';
	my @sizes;
	# Net::SSLeay::read(session, size): consume only the requested bytes.
	local *Net::SSLeay::read = sub {
		push(@sizes, $_[1]);
		my $chunk = substr($input, 0, $_[1], '');
		return ($chunk, length($chunk));
		};
	is(main::read_ssl_connection($h, 70000),
		$data, 'reads the complete body across configured buffers');
	is_deeply(\@sizes, [ (8192) x 8, 4464 ],
		'limits reads to the configured buffer and remaining body');
	is($input, 'NEXT', 'leaves the next frame unread');
	is(main::read_ssl_connection($h, 4), 'NEXT', 'reads the next frame');
	is($config_reads, 1, 'reads buffer settings once per connection');
	};

subtest 'Timed writes retry the same bytes and retain partial progress' => sub {
	# get_miniserv_config(config): supply a 64 KiB buffer.
	local *main::get_miniserv_config = sub { $_[0]->{'bufsize'} = 65536 };
	my $h = { ssl_con => 1, timeout => 5 };
	my (@attempts, @waits);
	my $received = '';
	my $call = 0;
	local *Net::SSLeay::write = sub {
		my $chunk = $_[1];
		push(@attempts, $chunk);
		$now++;
		return -1 if (++$call == 1 || $call == 3);
		my $size = $call == 2 ? 7 : bytes::length($chunk);
		$received .= bytes::substr($chunk, 0, $size);
		return $size;
		};
	local *main::wait_ssl_connection = sub { push(@waits, $_[2]); };
	my $data = 'abc' x 100000;
	my $start = $now;
	ok(main::write_ssl_connection($h, $data), 'large write completes');
	is($received, $data, 'partial writes neither drop nor repeat bytes');
	is($attempts[0], $attempts[1], 'initial retry preserves its buffer');
	is($attempts[2], $attempts[3], 'later retry preserves its remainder');
	is(bytes::length($attempts[0]), 65536,
		'uses the configured buffer for each full write');
	ok(!grep(bytes::length($_) > 65536, @attempts), 'writes are bounded');
	is_deeply(\@waits, [ $start+5, $start+7 ],
		'only successful writes renew the deadline');
	};

subtest 'Secure tokens never fall back to a weak random source' => sub {
	# Simulate a short random read in a separate interpreter.
	open(my $child, '-|', $^X, '-e', q{
		BEGIN { *CORE::GLOBAL::read = sub (*\$$;$) { 0 }; }
		require $ARGV[0];
		no warnings 'redefine';
		*seed_random = sub { };
		*substitute_pattern = sub { 'fallback' };
		my $secure = generate_miniserv_websocket_token(1);
		print defined($secure) ? 'unsafe' : 'secure-failure';
		print ' ', generate_miniserv_websocket_token();
		}, "$FindBin::Bin/../web-lib-funcs.pl") or die $!;
	my $output = do { local $/; <$child> };
	close($child);
	is($?, 0, 'random failure simulation completes');
	is($output, 'secure-failure fallback',
		'RPC rejects short randomness while existing token callers retain fallback');
	like(main::generate_miniserv_websocket_token(1), qr/^[a-f0-9]{32}$/,
		'system randomness produces a complete token');
	};

done_testing();
