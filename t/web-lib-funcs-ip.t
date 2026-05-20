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
# Returns 1 for: 0.x, 10.x, 127.x, 169.254/16, 172.16/12, 192.168/16,
# 100.64/10 (CGNAT), 224+/4 (multicast/reserved); IPv6 loopback, link-local
# (fe80–febf), ULA (fc00/fd00), and ::ffff:N.N.N.N when the wrapped IPv4
# is itself non-public.
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

	# IPv4-mapped (::ffff:N.N.N.N) recurses on the embedded IPv4.
	ok( main::is_non_public_ipaddress('::ffff:10.0.0.1'),
	   '::ffff:<private> recurses → non-public');
	ok( main::is_non_public_ipaddress('::ffff:192.168.1.1'),
	   '::ffff:<rfc1918> recurses → non-public');
	ok(!main::is_non_public_ipaddress('::ffff:8.8.8.8'),
	   '::ffff:<public> reported as public');

	# Plainly public IPv6.
	ok(!main::is_non_public_ipaddress('2001:db8::1'), '2001:db8 is public per classifier');
	ok(!main::is_non_public_ipaddress('2606:4700::1111'),
	   'global unicast address is public');
};

done_testing();
