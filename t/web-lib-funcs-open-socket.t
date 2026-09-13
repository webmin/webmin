#!/usr/bin/perl

use strict;
use warnings;
no warnings qw(once redefine);
use Test::More;
use FindBin;
use Socket;
use Errno qw(ECONNREFUSED);

my (@events, %connect_ok);

# Exercise the real address selection without opening workstation sockets.
BEGIN {
	*CORE::GLOBAL::socket = sub (*$$$) { return 1; };
	*CORE::GLOBAL::connect = sub (*$) {
		my ($fh, $address) = @_;
		my $family = sockaddr_family($address);
		my $ip = $family == AF_INET() ?
			inet_ntoa((unpack_sockaddr_in($address))[1]) :
			inet_ntop(AF_INET6(), (unpack_sockaddr_in6($address))[1]);
		push(@events, "connect $ip");
		$! = ECONNREFUSED unless $connect_ok{$ip};
		return $connect_ok{$ip} ? 1 : 0;
		};
	}

require "$FindBin::Bin/../web-lib-funcs.pl";
*main::callers_package = sub { $_[0] };
*main::supports_ipv6 = sub { 1 };
*main::error = sub { die "$_[0]\n" };

sub run_case
{
my ($v4, $v6, $ok, $without_error_ref) = @_;
@events = ();
%connect_ok = map { $_ => 1 } @$ok;
local %main::gconfig;
local *main::to_ipaddress = sub {
	push(@events, 'lookup IPv4');
	return @$v4;
	};
local *main::to_ip6address = sub {
	push(@events, 'lookup IPv6');
	return @$v6;
	};
my $buffer = '';
open(my $fh, '>', \$buffer) or die $!;
my $error;
my $ip = eval { open_socket('probe.example', 443, $fh,
	$without_error_ref ? undef : \$error) };
my $exception = $@;
close($fh);
return ($ip, $error, $exception);
}

my ($ip, $error, $exception) = run_case(
	['192.0.2.1'], ['2001:db8::1'], ['192.0.2.1']);
is($ip, '192.0.2.1', 'connects over IPv4');
is_deeply(\@events, ['lookup IPv4', 'connect 192.0.2.1'],
	'a working IPv4 connection never waits for IPv6 DNS');
is($error, undef, 'successful connection has no error');
is($exception, '', 'successful connection does not throw');

($ip) = run_case(['192.0.2.1', '192.0.2.2'], ['2001:db8::1'], ['192.0.2.2']);
is($ip, '192.0.2.2', 'tries the next IPv4 address after a connection failure');
is_deeply(\@events, ['lookup IPv4', 'connect 192.0.2.1', 'connect 192.0.2.2'],
	'a later working IPv4 address also avoids IPv6 DNS');

($ip, $error) = run_case(
	['192.0.2.1', '192.0.2.2'], ['2001:db8::1'], ['2001:db8::1']);
is($ip, '2001:db8::1', 'falls back to IPv6 when every IPv4 connection fails');
is_deeply(\@events, ['lookup IPv4', 'connect 192.0.2.1', 'connect 192.0.2.2',
	'lookup IPv6', 'connect 2001:db8::1'], 'resolves IPv6 after the IPv4 attempts');
is($error, undef, 'IPv6 fallback clears earlier connection failures');

($ip) = run_case([], ['2001:db8::1'], ['2001:db8::1']);
is($ip, '2001:db8::1', 'supports an IPv6-only hostname');

($ip, $error) = run_case([], [], []);
is($ip, undef, 'missing DNS records fail');
is($error, 'Failed to lookup IP address for probe.example', 'reports DNS failure');

($ip, $error) = run_case(['192.0.2.1'], [], []);
is($ip, undef, 'an unsuccessful IPv4 connection fails when there is no IPv6');
like($error, qr/^Failed to connect to probe\.example:443 : /,
	'preserves the connection error when IPv6 DNS is empty');

($ip, $error) = run_case(['192.0.2.1'], ['2001:db8::1'], []);
is($ip, undef, 'fails when neither address family connects');
like($error, qr/^Failed to IPv6 connect to probe\.example:443 : /,
	'reports the last connection failure');

(undef, undef, $exception) = run_case([], [], [], 1);
is($exception, "Failed to lookup IP address for probe.example\n",
	'callers without an error reference still receive an exception');

done_testing();
