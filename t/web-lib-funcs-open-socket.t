#!/usr/bin/perl

use strict;
use warnings;
no warnings qw(once redefine);
use Test::More;
use FindBin;
# Import IPv6 helpers even when the optional Socket6 module is absent.
use Socket qw(:DEFAULT inet_pton inet_ntop);
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
my ($v4, $v6, $ok, $without_error_ref, $family) = @_;
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
	$without_error_ref ? undef : \$error, undef, $family) };
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

($ip) = run_case(['192.0.2.1'], ['2001:db8::1'], ['192.0.2.1', '2001:db8::1'],
	undef, 6);
is($ip, '2001:db8::1', 'forced IPv6 ignores a working IPv4 address');
is_deeply(\@events, ['lookup IPv6', 'connect 2001:db8::1'],
	'forced IPv6 skips the IPv4 resolver');

($ip, $error) = run_case(['192.0.2.1'], ['2001:db8::1'], ['2001:db8::1'],
	undef, 4);
is($ip, undef, 'forced IPv4 does not fall back to IPv6');
is_deeply(\@events, ['lookup IPv4', 'connect 192.0.2.1'],
	'forced IPv4 skips the IPv6 resolver');

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

subtest 'HTTP download forwards the address family' => sub {
	my (@connection_args, @download_args);
	local %main::gconfig;
	local *main::check_in_http_cache = sub { return undef; };
	local *main::make_http_connection = sub {
		@connection_args = @_;
		return { 'ip' => '2001:db8::1' };
		};
	local *main::complete_http_download = sub { @download_args = @_; };
	my ($body, $error);
	http_download('probe.example', 443, '/', \$body, \$error, undef, 1,
		undef, undef, 5, 0, 1, {}, undef, 6);
	is($connection_args[8], 6,
		'connection creation receives the requested family');
	is($download_args[12], 6,
		'download completion receives the requested family');
	};

subtest 'HTTP redirect preserves the address family' => sub {
	my @lines = ("HTTP/1.0 302 Found\r\n",
		"Location: https://redirect.example/\r\n", "\r\n");
	my @redirect_args;
	local *main::read_http_connection = sub { return shift(@lines); };
	local *main::close_http_connection = sub { };
	local *main::http_download = sub { @redirect_args = @_; };
	my ($body, $error);
	complete_http_download({}, \$body, \$error, undef, 0,
		'probe.example', 443, {}, 1, 1, 5, undef, 6);
	is($redirect_args[14], 6,
		'redirected request receives the requested family');
	};

done_testing();
