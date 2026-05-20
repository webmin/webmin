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
# Unlike the docstring, this sub also accepts an address/netmask form, but
# only when the `::` shorthand is at the *start* of the address — see the
# bug notes below. Pin current behaviour so a future fix shows up loudly.
subtest 'check_ip6address' => sub {
	ok( main::check_ip6address('::'),              'unspecified accepted');
	ok( main::check_ip6address('::1'),             'loopback accepted');
	ok( main::check_ip6address('2001:db8::1'),     'compressed form accepted');
	ok( main::check_ip6address('1:2:3:4:5:6:7:8'), 'full eight-block form accepted');
	ok( main::check_ip6address('2001:db8::'),      'trailing :: accepted (no netmask)');

	# Netmask suffix.
	ok( main::check_ip6address('::1/64'),  'address/netmask accepted when :: is at start');
	ok(!main::check_ip6address('::1/200'), 'netmask > 128 rejected');

	# BUG: a netmask suffix combined with a trailing `::` shorthand
	# fails. The validator's empty-block accounting is thrown off because
	# split() no longer trims trailing empties when the final element is
	# the netmask. Real-world example: "2001:db8::/32" — a perfectly
	# valid CIDR — is rejected.
	ok(!main::check_ip6address('2001:db8::/32'),
	   'BUG: valid CIDR with trailing :: rejected by validator');

	# BUG: IPv4-mapped IPv6 (RFC 4291 §2.5.5.2) is rejected because the
	# per-block regex requires hex digits. Notably, is_non_public_ipaddress
	# has an unreachable ::ffff:N.N.N.N branch downstream of this check.
	ok(!main::check_ip6address('::ffff:10.0.0.1'),
	   'BUG: IPv4-mapped IPv6 rejected by validator');

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

	# IPv4-mapped (::ffff:N.N.N.N) is meant to recurse on the embedded
	# IPv4, but the branch is unreachable: check_ip6address rejects all
	# ::ffff:N.N.N.N inputs (see BUG note in check_ip6address subtest).
	# Both calls below currently return 0 — pin that.
	ok(!main::is_non_public_ipaddress('::ffff:10.0.0.1'),
	   'BUG: ::ffff:<private> falsely reported as public (validator rejects input)');
	ok(!main::is_non_public_ipaddress('::ffff:8.8.8.8'),
	   '::ffff:<public> reported as public');

	# Plainly public IPv6.
	ok(!main::is_non_public_ipaddress('2001:db8::1'), '2001:db8 is public per classifier');
	ok(!main::is_non_public_ipaddress('2606:4700::1111'),
	   'global unicast address is public');
};

done_testing();
