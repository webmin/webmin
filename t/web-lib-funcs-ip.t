#!/usr/bin/perl
# Unit tests for IP-address validators / classifiers in web-lib-funcs.pl.
#
# Pure subs, no globals to set up. miniserv.pl carries its own copies of
# check_ipaddress / check_ip6address; those have their own tests in
# t/miniserv.t. This file exclusively exercises the web-lib-funcs versions,
# which have a slightly different IPv6 contract — the web-lib-funcs version
# accepts an /N netmask suffix.

use strict;
use warnings;
use Test::More;
use File::Basename qw(dirname);
use File::Spec;

my $script = File::Spec->rel2abs(
	File::Spec->catfile(dirname(__FILE__), '..', 'web-lib-funcs.pl'));
require $script;

my $has_ipv6_packing = eval {
	defined(main::inet_pton(main::AF_INET6(), '::1'));
	};

# check_ipaddress — strict dotted-quad IPv4.
subtest 'check_ipaddress' => sub {
	ok( main::check_ipaddress('1.2.3.4'),         'plain IPv4 accepted');
	ok( main::check_ipaddress('0.0.0.0'),         'all-zero accepted');
	ok( main::check_ipaddress('255.255.255.255'), 'all-ones accepted');

	ok(!main::check_ipaddress('256.0.0.1'),       'octet > 255 rejected');
	ok(!main::check_ipaddress('1.2.3'),           'too-few octets rejected');
	ok(!main::check_ipaddress('1.2.3.4.5'),       'too-many octets rejected');
	ok(!main::check_ipaddress('1.2.3.x'),         'non-numeric octet rejected');
	ok(!main::check_ipaddress(''),                'empty rejected');
	ok(!main::check_ipaddress('not an ip'),       'garbage rejected');
	ok(!main::check_ipaddress(' 1.2.3.4'),        'leading whitespace rejected');
	ok(!main::check_ipaddress('1.2.3.4 '),        'trailing whitespace rejected');
};

# check_ip6address — IPv6, optionally with /N netmask suffix.
#
# Accepts the standard text forms, the "::" shorthand at any position, an
# optional /N netmask, and the IPv4-in-IPv6 dotted-quad tail (RFC 4291
# §2.5.5: "::ffff:N.N.N.N" mapped and "X:X:X:X:X:X:N.N.N.N" compatible).
subtest 'check_ip6address' => sub {
	ok( main::check_ip6address('::'),              'unspecified accepted');
	ok( main::check_ip6address('::1'),             'loopback accepted');
	ok( main::check_ip6address('2001:db8::1'),     'compressed form accepted');
	ok( main::check_ip6address('1:2:3:4:5:6:7:8'), 'full eight-block form accepted');
	ok( main::check_ip6address('2001:db8::'),      'trailing :: accepted (no netmask)');

	# Netmask suffix — both with leading and trailing :: shorthand.
	ok( main::check_ip6address('::1/64'),       'address/netmask accepted with leading ::');
	ok( main::check_ip6address('2001:db8::/32'), 'address/netmask accepted with trailing ::');
	ok( main::check_ip6address('::/0'),         '::/0 default route accepted');
	ok( main::check_ip6address('fe80::/10'),    'fe80::/10 link-local prefix accepted');
	ok(!main::check_ip6address('::1/200'),      'netmask > 128 rejected');

	# IPv4-in-IPv6 tails.
	ok( main::check_ip6address('::ffff:10.0.0.1'),      'IPv4-mapped (::ffff:N.N.N.N) accepted');
	ok( main::check_ip6address('::ffff:0.0.0.0'),       'IPv4-mapped all-zero accepted');
	ok( main::check_ip6address('::1.2.3.4'),            'IPv4-compatible (::N.N.N.N) accepted');
	ok( main::check_ip6address('0:0:0:0:0:ffff:1.2.3.4'),
	    'fully-expanded IPv4-mapped accepted');
	ok(!main::check_ip6address('::ffff:256.0.0.1'),     'IPv4-mapped with octet > 255 rejected');
	ok(!main::check_ip6address('::ffff:1.2.3'),         'IPv4-mapped with too-few octets rejected');

	# Bare IPv4 must be rejected — callers (e.g. ip_match) use this sub
	# as a type discriminator and a true result re-routes IPv4 input
	# through the IPv6 codepath.
	ok(!main::check_ip6address('10.0.0.1'),          'bare IPv4 rejected (type-discriminator contract)');
	ok(!main::check_ip6address('1.2.3.4'),           'bare IPv4 rejected (type-discriminator contract)');

	# Degenerate netmask shapes — stripping "/N" from the input must not
	# let an address that's otherwise just a stray colon (or empty) pass.
	# perl's split() trims trailing empties hard, so e.g. split(":") is
	# () not (""), and our @blocks==0 guard catches it.
	ok(!main::check_ip6address(':/64'),  'bare colon with netmask rejected');
	ok(!main::check_ip6address('/64'),   'netmask without address rejected');
	ok(!main::check_ip6address(':'),     'bare colon rejected');
	ok(!main::check_ip6address('::/'),   'trailing slash with no digits rejected');
	ok(!main::check_ip6address('//64'),  'leading slash with netmask rejected');

	ok(!main::check_ip6address('gggg::1'),           'non-hex rejected');
	ok(!main::check_ip6address('1:2:3:4:5:6:7:8:9'), 'too many groups rejected');
	ok(!main::check_ip6address('::1::2'),            'multiple :: rejected');
	ok(!main::check_ip6address('not an addr'),       'garbage rejected');
};

# is_non_public_ipaddress — RFC1918 + reserved-range classifier.
#
# Returns 1 for private, local, link-local, documentation, benchmarking,
# translation, reserved and multicast ranges in IPv4 and IPv6, including
# IPv4-mapped IPv6 addresses when the wrapped IPv4 is itself non-public.
subtest 'is_non_public_ipaddress (IPv4)' => sub {
	# Private / reserved.
	ok( main::is_non_public_ipaddress('10.0.0.1'),     '10/8 private');
	ok( main::is_non_public_ipaddress('172.16.0.1'),   '172.16/12 low bound');
	ok( main::is_non_public_ipaddress('172.31.255.255'), '172.16/12 high bound');
	ok( main::is_non_public_ipaddress('192.168.1.1'),  '192.168/16 private');
	ok( main::is_non_public_ipaddress('127.0.0.1'),    '127/8 loopback');
	ok( main::is_non_public_ipaddress('169.254.1.1'),  '169.254/16 link-local');
	ok( main::is_non_public_ipaddress('0.1.2.3'),      '0/8 reserved');
	ok( main::is_non_public_ipaddress('100.64.0.1'),   'CGNAT 100.64/10 low');
	ok( main::is_non_public_ipaddress('100.127.255.255'), 'CGNAT 100.64/10 high');
	ok( main::is_non_public_ipaddress('192.0.2.1'),   'documentation network');
	ok( main::is_non_public_ipaddress('198.18.0.1'),  'benchmarking network');
	ok( main::is_non_public_ipaddress('198.51.100.1'), 'documentation network');
	ok( main::is_non_public_ipaddress('203.0.113.1'), 'documentation network');
	ok( main::is_non_public_ipaddress('224.0.0.1'),    '224+ multicast / reserved');
	ok( main::is_non_public_ipaddress('255.255.255.255'), '255+ reserved');

	# Just-outside boundaries.
	ok(!main::is_non_public_ipaddress('11.0.0.1'),     '11/8 is public');
	ok(!main::is_non_public_ipaddress('172.15.255.255'), '172.15 below private block');
	ok(!main::is_non_public_ipaddress('172.32.0.0'),   '172.32 above private block');
	ok(!main::is_non_public_ipaddress('192.167.0.0'),  '192.167 is public');
	ok(!main::is_non_public_ipaddress('169.253.0.0'),  '169.253 is public');
	ok(!main::is_non_public_ipaddress('100.63.255.255'), 'just below CGNAT');
	ok(!main::is_non_public_ipaddress('100.128.0.0'),  'just above CGNAT');

	# Plainly public.
	ok(!main::is_non_public_ipaddress('8.8.8.8'),      'public DNS resolver');
	ok(!main::is_non_public_ipaddress('1.1.1.1'),      'public DNS resolver');
};

subtest 'is_non_public_ipaddress (IPv6)' => sub {
	ok( main::is_non_public_ipaddress('::1'),     'loopback');
	ok( main::is_non_public_ipaddress('::'),      'unspecified');
	ok( main::is_non_public_ipaddress('fe80::1'), 'link-local (fe80)');
	ok( main::is_non_public_ipaddress('feb0::1'), 'link-local (feb0)');
	ok( main::is_non_public_ipaddress('fc00::1'), 'ULA (fc00)');
	ok( main::is_non_public_ipaddress('fd12::1'), 'ULA (fd12)');
	ok( main::is_non_public_ipaddress('ff02::1'), 'IPv6 multicast');
	SKIP: {
		skip 'IPv6 binary conversion unavailable', 10
			if (!$has_ipv6_packing);
		ok( main::is_non_public_ipaddress('64:ff9b::a9fe:a9fe'),
		   'NAT64 translation of link-local IPv4');
		ok(!main::is_non_public_ipaddress('64:ff9b::808:808'),
		   'NAT64 translation of public IPv4 remains public');
		ok( main::is_non_public_ipaddress('100::1'),
		   'discard-only prefix');
		ok( main::is_non_public_ipaddress('2001:db8::1'),
		   'IPv6 documentation prefix');
		ok( main::is_non_public_ipaddress('2002:7f00:1::'),
		   '6to4 translation of loopback IPv4');
		ok(!main::is_non_public_ipaddress('2002:808:808::'),
		   '6to4 translation of public IPv4 remains public');

		# IPv4-mapped addresses recurse on the embedded IPv4.
		ok( main::is_non_public_ipaddress('::ffff:10.0.0.1'),
		   '::ffff:<private> recurses → non-public');
		ok( main::is_non_public_ipaddress('::ffff:192.168.1.1'),
		   '::ffff:<rfc1918> recurses → non-public');
		ok( main::is_non_public_ipaddress('0:0:0:0:0:ffff:7f00:1'),
		   'expanded mapped loopback recurses → non-public');
		ok(!main::is_non_public_ipaddress('::ffff:8.8.8.8'),
		   '::ffff:<public> reported as public');
		}

	# Plainly public IPv6.
	ok(!main::is_non_public_ipaddress('2606:4700::1111'),
	   'global unicast address is public');
};

subtest 'ipaddress_matches_network' => sub {
	ok( main::ipaddress_matches_network('10.1.2.3', '10.0.0.0/8'),
	   'IPv4 address matches CIDR');
	ok(!main::ipaddress_matches_network('11.1.2.3', '10.0.0.0/8'),
	   'IPv4 address outside CIDR does not match');
	ok( main::ipaddress_matches_network('192.168.1.2', '192.168.1.2'),
	   'exact IPv4 address matches');
	SKIP: {
		skip 'IPv6 binary conversion unavailable', 3
			if (!$has_ipv6_packing);
		ok( main::ipaddress_matches_network(
			'fd00:1234::20', 'fd00:1234::/48'),
		   'IPv6 address matches CIDR');
		ok(!main::ipaddress_matches_network(
			'fd00:1235::20', 'fd00:1234::/48'),
		   'IPv6 address outside CIDR does not match');
		ok( main::ipaddress_matches_network(
			'::ffff:10.1.2.3', '10.0.0.0/8'),
		   'IPv4 exception matches mapped IPv6 destination');
		}
	ok(!main::ipaddress_matches_network('10.1.2.3', 'bad-network'),
	   'invalid exception does not match');
};

subtest 'check_download_address' => sub {
	my $resolved;
	is(main::check_download_address('8.8.8.8', 'public'), undef,
	   'public destination is allowed in public mode');
	is(main::check_download_address('8.8.8.8', 'public', undef,
					  \$resolved), undef,
	   'public destination resolves for a restricted proxy');
	is($resolved, '8.8.8.8', 'policy-checked proxy address is returned');
	like(main::check_download_address('127.0.0.1', 'public'),
	     qr/non-public IP address 127\.0\.0\.1/,
	     'loopback destination is blocked in public mode');
	like(main::check_download_address('169.254.169.254', 'public'),
	     qr/non-public IP address 169\.254\.169\.254/,
	     'cloud metadata destination is blocked in public mode');
	is(main::check_download_address('10.1.2.3', 'listed', '10.0.0.0/8'),
	   undef, 'listed CIDR permits a private destination');
	like(main::check_download_address('192.168.1.2', 'listed', '10.0.0.0/8'),
	     qr/not allowed/, 'unlisted private destination remains blocked');
	is(main::check_download_address('127.0.0.1', 'all'), undef,
	   'all mode permits loopback');
	is(main::check_download_address('127.0.0.1', undef), undef,
	   'unspecified policy preserves compatibility for existing callers');
	{
		no warnings qw(once redefine);
		local *main::to_ipaddress = sub { return; };
		local *main::to_ip6address = sub { return; };
		like(main::check_download_address('unresolved.example', 'public'),
		     qr/Failed to lookup IP address/,
		     'restricted policy fails closed when DNS cannot resolve');
		}
};

subtest 'restricted download cache isolation' => sub {
	no warnings qw(once redefine);
	my $cache_checks = 0;
	local *main::check_in_http_cache = sub { $cache_checks++; return; };
	local *main::make_http_connection = sub { return 'test connection stopped'; };
	my ($dest, $err);
	main::http_download('8.8.8.8', 80, '/', \$dest, \$err, undef, 0,
			    undef, undef, 0, undef, undef, undef, undef,
			    'public', undef);
	is($cache_checks, 0, 'restricted download does not consult shared cache');
	is($err, 'test connection stopped', 'download reached mocked connection');
};

subtest 'redirect destination policy' => sub {
	no warnings qw(once redefine);
	my @lines = (
		"HTTP/1.0 302 Found\r\n",
		"Location: http://127.0.0.1/private\r\n",
		"\r\n",
		);
	local *main::read_http_connection = sub { return shift(@lines); };
	local *main::close_http_connection = sub { return 1; };
	my ($dest, $err);
	main::complete_http_download({}, \$dest, \$err, undef, undef,
				     '8.8.8.8', 80, {}, 0, 1, 0, undef,
				     'public', undef);
	like($err, qr/non-public IP address 127\.0\.0\.1/,
	     'redirect to loopback is blocked before connecting');
};

subtest 'restricted HTTP proxy pins checked address' => sub {
	no warnings qw(once redefine);
	local %main::gconfig = (http_proxy => 'http://proxy.test:3128');
	local *main::is_readonly_mode = sub { return 0; };
	local *main::no_proxy = sub { return 0; };
	my $wire = '';
	local *main::open_socket = sub {
		my $name = $_[2];
		no strict 'refs';
		open(*{"main::$name"}, '>', \$wire) || die $!;
		return 1;
		};
	my $h = main::make_http_connection(
		'origin.test', 80, 0, 'GET', '/path',
		[ [ 'Host', 'origin.test' ] ], undef, undef,
		'public', undef, '93.184.216.34');
	main::close_http_connection($h);
	like($wire, qr{^GET http://93\.184\.216\.34:80/path HTTP/1\.0\r\n},
	     'proxy request targets the policy-checked IP');
	like($wire, qr/Host: origin\.test\r\n/,
	     'proxy request preserves the original Host header');
};

done_testing();
