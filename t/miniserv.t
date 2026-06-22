#!/usr/bin/perl
# Unit tests for miniserv.pl helper subs.
#
# miniserv.pl is loaded as a module; its top-level script body is skipped
# by the `unless (caller) { ... }` guard, so we only get the sub
# definitions plus a handful of pure-constant globals (@itoa64, @weekday,
# @month, @miniserv_argv). Everything else (%config, @roots, $datestr,
# etc.) we populate ourselves.
#
# Each helper has its own `subtest`. Assertions target the contract
# (status code present, headers present, redaction happened, round-trip
# is identity, ...), not the exact wording, HTML, or formatting — those
# are presentation and may change.

use strict;
use warnings;
use Test::More;
use File::Basename qw(dirname);
use File::Spec;

my $script = File::Spec->rel2abs(
	File::Spec->catfile(dirname(__FILE__), '..', 'miniserv.pl'));
require $script;

# Capture buffers populated by overridden I/O subs.
our @written;
our @errlog;
our @reqlog;

# Replace the subs that would otherwise touch SOCK, STDERR, the log file,
# or read disk. Each capturing override is the minimum needed to keep
# the subs under test runnable. `once` is suppressed because these
# package globals are only ever written from this file.
{
	no warnings qw(redefine once);
	*miniserv::write_data         = sub { push @written, join('', @_); };
	*miniserv::write_keep_alive   = sub { };
	*miniserv::log_error          = sub { push @errlog, join('', @_); };
	*miniserv::log_request        = sub { push @reqlog, [@_]; };
	*miniserv::embed_error_styles = sub { return ''; };
	*miniserv::server_info        = sub { return 'MiniServ/test'; };
	*miniserv::reset_byte_count   = sub { };
	*miniserv::byte_count         = sub { return 0; };
}

{
	no warnings 'once';
	%miniserv::config   = ();
	@miniserv::roots    = ('/tmp');
	@miniserv::preroots = ();
	$miniserv::datestr  = 'Sun, 01 Jan 2026 00:00:00 GMT';
}

# http_error
#
# Call http_error with capture buffers reset. noexit=1 is REQUIRED — the
# real sub calls exit() otherwise. Warnings about SOCK (not a real socket)
# and DEBUG (filehandle never opened in tests) are expected and filtered;
# any other warning fails the test so real regressions stay visible.
sub run_http_error {
	my (%args) = @_;
	@written = ();
	@errlog  = ();
	@reqlog  = ();
	no warnings 'once';
	local $miniserv::reqline  = $args{reqline};
	local $miniserv::loghost  = $args{loghost};
	local $miniserv::authuser = $args{authuser};

	my @warnings;
	local $SIG{__WARN__} = sub { push @warnings, $_[0]; };
	miniserv::http_error(
		$args{code}, $args{msg}, $args{body},
		1,             # noexit
		$args{noerr},
	);

	my @unexpected = grep { !/\b(?:SOCK|DEBUG)\b/ } @warnings;
	is(scalar @unexpected, 0, 'no unexpected warnings from http_error')
		or diag("unexpected warnings:\n", @unexpected);

	return join('', @written);
}

subtest 'http_error' => sub {
	# minimal call: code + message, no body, no reqline
	# Assert on the contract, not the cosmetics: the status code, the
	# presence of required headers, and that the caller's code + message
	# reach the rendered page. Specific wording, header values, decoration
	# (&mdash;), and class names are presentation and may change.
	{
		my $out = run_http_error(code => 404, msg => 'Not Found');

		like($out, qr{^HTTP/1\.0 404\b},                      'status line carries 404');
		like($out, qr{\r\nServer:\s+\S},                      'Server header present and non-empty');
		like($out, qr{\r\nDate:\s+\S},                        'Date header present and non-empty');
		like($out, qr{\r\nContent-type:\s*text/html\b.*\butf-?8\b}i, 'Content-type is HTML with utf-8 charset');
		like($out, qr{<title>[^<]*404[^<]*</title>},          'title surfaces the code');
		like($out, qr{<title>[^<]*Not Found[^<]*</title>},    'title surfaces the message');
		like($out, qr{<h2\b[^>]*>[^<]*Not Found[^<]*</h2>},   'message appears in a heading');
		unlike($out, qr{<p\b},                                'no paragraph emitted when body arg absent');

		is(scalar @errlog, 1,                                 'log_error called once');
		like($errlog[0], qr/Not Found/,                       'log_error received the caller message');
		is(scalar @reqlog, 0,                                 'log_request skipped when reqline empty');
	}

	# body argument renders as a paragraph
	{
		my $out = run_http_error(code => 500, msg => 'Server Error', body => 'something broke');
		like($out, qr{<p\b[^>]*>[^<]*\Qsomething broke\E[^<]*</p>}, 'body argument rendered in a paragraph');
	}

	# reqline triggers log_request
	{
		run_http_error(
			code => 403, msg => 'Forbidden', body => 'no access',
			reqline => 'GET /secret HTTP/1.0',
			loghost => '127.0.0.1', authuser => 'bob',
		);
		is(scalar @reqlog, 1,                                 'log_request called when reqline is set');
		is($reqlog[0][0], '127.0.0.1',                        'log_request host arg');
		is($reqlog[0][1], 'bob',                              'log_request user arg');
		is($reqlog[0][2], 'GET /secret HTTP/1.0',             'log_request request arg');
		is($reqlog[0][3], 403,                                'log_request code arg');
	}

	# noerr suppresses log_error
	{
		run_http_error(code => 401, msg => 'Unauthorized', noerr => 1);
		is(scalar @errlog, 0,                                 'log_error suppressed when noerr is true');
	}

	# error_handler config that points to a missing file falls through
	# This exercises the early branch without triggering `goto rerun` (which
	# only resolves inside handle_request).
	{
		local $miniserv::config{'error_handler'} = 'definitely-not-a-real-file.cgi';
		my $out = run_http_error(code => 500, msg => 'Server Error');
		like($out, qr{^HTTP/1\.0 500\b}, 'falls through to standard path when handler file missing');
	}

	# HTML scaffolding is balanced
	{
		my $out = run_http_error(code => 400, msg => 'Bad Request', body => 'oops');
		for my $tag (qw(html head title body h2 p)) {
			my $open  = () = $out =~ /<$tag\b[^>]*>/g;
			my $close = () = $out =~ /<\/$tag>/g;
			is($open, $close, "<$tag> tags balanced (open=$open, close=$close)");
			cmp_ok($open, '>=', 1, "<$tag> appears at least once");
		}
		# Sanity-check element ordering: head before body, title inside head.
		like($out, qr{<html>.*<head>.*<title>.*</title>.*</head>.*<body[^>]*>.*</body>\s*</html>}s,
		     'top-level elements appear in the expected order');
	}
};

# simplify_path — security-critical path canonicalization
subtest 'simplify_path' => sub {
	my $bogus;

	is(miniserv::simplify_path('/foo/bar', $bogus), '/foo/bar', 'plain path passes through');
	is($bogus, 0,                                                'plain path is not bogus');

	is(miniserv::simplify_path('/foo/./bar', $bogus), '/foo/bar', '. segments collapse');
	is(miniserv::simplify_path('/foo/../bar', $bogus), '/bar',     '.. segments pop');
	is($bogus, 0,                                                  'in-bounds .. is not bogus');

	miniserv::simplify_path('/../etc/passwd', $bogus);
	is($bogus, 1, 'escaping above the root sets the bogus flag');

	miniserv::simplify_path('/foo/../../bar', $bogus);
	is($bogus, 1, 'multiple .. that overshoot set the bogus flag');

	# Null bytes are stripped — relied on to prevent C-string truncation
	# attacks downstream.
	my $clean = miniserv::simplify_path("/foo\0bar/baz", $bogus);
	unlike($clean, qr/\0/, 'null bytes are removed');

	# Backslash separators get normalized to forward slashes.
	is(miniserv::simplify_path('foo\\bar', $bogus), '/foo/bar', 'backslashes become forward slashes');

	# Repeated slashes collapse.
	is(miniserv::simplify_path('//foo///bar//', $bogus), '/foo/bar', 'repeated slashes collapse');
};

# b64encode / b64decode — round-trip is the contract
subtest 'b64encode / b64decode round-trip' => sub {
	for my $s ('a', 'ab', 'abc', 'hello world',
		   "binary\x00\x01\xff bytes", 'x' x 100) {
		is(miniserv::b64decode(miniserv::b64encode($s)), $s,
		   "round-trip preserves ".length($s)." bytes");
	}

	# Output is restricted to the standard alphabet plus padding.
	like(miniserv::b64encode('hello'), qr{^[A-Za-z0-9+/=]+$},
	     'encoded output uses standard base64 alphabet');
};

# urlize — percent-encoding
subtest 'urlize' => sub {
	is(miniserv::urlize('abc123'), 'abc123',     'alphanumerics pass through');
	is(miniserv::urlize(' '),      '%20',        'space percent-encoded');
	is(miniserv::urlize('/'),      '%2F',        'slash percent-encoded');
	like(miniserv::urlize('a b/c'), qr{^a%20b%2Fc$},
	     'mixed string encodes non-alphanumerics, leaves alphanumerics alone');
};

# html_escape / html_strip — XSS-relevant
subtest 'html_escape' => sub {
	my $out = miniserv::html_escape(q{<script>alert("x")</script>'=&});
	# Contract: none of the dangerous characters survive as themselves.
	unlike($out, qr/[<>"'=]/,           'no raw HTML-significant characters remain');
	unlike($out, qr/&(?!(amp|lt|gt|quot|#39|#61);)/,
	     'every & is the start of a known entity');
	# Alphanumerics pass through unchanged.
	like(miniserv::html_escape('abc 123'), qr/\babc\b.*\b123\b/,
	     'alphanumerics pass through unchanged');
};

subtest 'html_strip' => sub {
	is(miniserv::html_strip('<b>foo</b>'),        'foo',     'simple tags removed');
	is(miniserv::html_strip('<a href="x">y</a>'), 'y',       'attribute-bearing tags removed');
	is(miniserv::html_strip('plain text'),        'plain text', 'plain text untouched');
};

# get_type — MIME lookup
subtest 'get_type' => sub {
	no warnings 'once';
	local %miniserv::mime = (html => 'text/html', png => 'image/png');

	is(miniserv::get_type('foo.html'),     'text/html',  'known extension returns its type');
	is(miniserv::get_type('foo.png'),      'image/png',  'second known extension');
	is(miniserv::get_type('foo.unknown'),  'text/plain', 'unknown extension falls back to text/plain');
	is(miniserv::get_type('noextension'),  'text/plain', 'no extension falls back to text/plain');
};

# indexof — array index utility
subtest 'indexof' => sub {
	is(miniserv::indexof('b', 'a', 'b', 'c'), 1,  'returns 0-based index');
	is(miniserv::indexof('a', 'a', 'b', 'c'), 0,  'first element matches');
	is(miniserv::indexof('z', 'a', 'b', 'c'), -1, 'missing returns -1');
	is(miniserv::indexof('x'),                -1, 'empty haystack returns -1');
};

# prefix_to_mask — CIDR prefix → dotted-quad netmask
subtest 'prefix_to_mask' => sub {
	is(miniserv::prefix_to_mask(0),  '0.0.0.0',         '/0 = all zeros');
	is(miniserv::prefix_to_mask(8),  '255.0.0.0',       '/8');
	is(miniserv::prefix_to_mask(16), '255.255.0.0',     '/16');
	is(miniserv::prefix_to_mask(24), '255.255.255.0',   '/24');
	is(miniserv::prefix_to_mask(32), '255.255.255.255', '/32 = all ones');
};

# check_ipaddress / check_ip6address — input validators
subtest 'check_ipaddress' => sub {
	ok( miniserv::check_ipaddress('1.2.3.4'),         'valid IPv4 accepted');
	ok( miniserv::check_ipaddress('0.0.0.0'),         'all-zero IPv4 accepted');
	ok( miniserv::check_ipaddress('255.255.255.255'), 'all-ones IPv4 accepted');
	ok(!miniserv::check_ipaddress('256.0.0.1'),       'octet > 255 rejected');
	ok(!miniserv::check_ipaddress('1.2.3'),           'too-few octets rejected');
	ok(!miniserv::check_ipaddress('1.2.3.4.5'),       'too-many octets rejected');
	ok(!miniserv::check_ipaddress(''),                'empty string rejected');
	ok(!miniserv::check_ipaddress('not an ip'),       'garbage rejected');
};

# Kept in lockstep with t/web-lib-funcs-ip.t's matching subtest, since the
# two copies of check_ip6address must accept and reject the same inputs.
subtest 'check_ip6address' => sub {
	ok( miniserv::check_ip6address('::'),                   'unspecified accepted');
	ok( miniserv::check_ip6address('::1'),                  'loopback accepted');
	ok( miniserv::check_ip6address('2001:db8::1'),          'compressed form accepted');
	ok( miniserv::check_ip6address('1:2:3:4:5:6:7:8'),      'full eight-block form accepted');
	ok( miniserv::check_ip6address('2001:db8::'),           'trailing :: accepted (no netmask)');

	# Netmask suffix — both with leading and trailing :: shorthand.
	ok( miniserv::check_ip6address('::1/64'),               'address/netmask accepted with leading ::');
	ok( miniserv::check_ip6address('2001:db8::/32'),        'address/netmask accepted with trailing ::');
	ok( miniserv::check_ip6address('::/0'),                 '::/0 default route accepted');
	ok( miniserv::check_ip6address('fe80::/10'),            'fe80::/10 link-local prefix accepted');
	ok(!miniserv::check_ip6address('::1/200'),              'netmask > 128 rejected');

	# IPv4-in-IPv6 tails.
	ok( miniserv::check_ip6address('::ffff:10.0.0.1'),      'IPv4-mapped (::ffff:N.N.N.N) accepted');
	ok( miniserv::check_ip6address('::ffff:0.0.0.0'),       'IPv4-mapped all-zero accepted');
	ok( miniserv::check_ip6address('::1.2.3.4'),            'IPv4-compatible (::N.N.N.N) accepted');
	ok( miniserv::check_ip6address('0:0:0:0:0:ffff:1.2.3.4'),
	    'fully-expanded IPv4-mapped accepted');
	ok(!miniserv::check_ip6address('::ffff:256.0.0.1'),     'IPv4-mapped with octet > 255 rejected');
	ok(!miniserv::check_ip6address('::ffff:1.2.3'),         'IPv4-mapped with too-few octets rejected');

	# Bare IPv4 must be rejected — callers (e.g. ip_match) use this sub
	# as a type discriminator and a true result re-routes IPv4 input
	# through the IPv6 codepath.
	ok(!miniserv::check_ip6address('10.0.0.1'),             'bare IPv4 rejected (type-discriminator contract)');
	ok(!miniserv::check_ip6address('1.2.3.4'),              'bare IPv4 rejected (type-discriminator contract)');

	# Degenerate netmask shapes — stripping "/N" from the input must not
	# let an address that's otherwise just a stray colon (or empty) pass.
	# perl's split() trims trailing empties hard, so e.g. split(":") is
	# () not (""), and our @blocks==0 guard catches it.
	ok(!miniserv::check_ip6address(':/64'),                 'bare colon with netmask rejected');
	ok(!miniserv::check_ip6address('/64'),                  'netmask without address rejected');
	ok(!miniserv::check_ip6address(':'),                    'bare colon rejected');
	ok(!miniserv::check_ip6address('::/'),                  'trailing slash with no digits rejected');
	ok(!miniserv::check_ip6address('//64'),                 'leading slash with netmask rejected');

	ok(!miniserv::check_ip6address('gggg::1'),              'non-hex rejected');
	ok(!miniserv::check_ip6address('1:2:3:4:5:6:7:8:9'),    'too many groups rejected');
	ok(!miniserv::check_ip6address('::1::2'),               'multiple :: rejected');
	ok(!miniserv::check_ip6address('not an addr'),          'garbage rejected');
};

# canonicalize_ip6 / expand_ipv6_bytes
subtest 'canonicalize_ip6' => sub {
	my $c = miniserv::canonicalize_ip6('::1');
	is($c, '0000:0000:0000:0000:0000:0000:0000:0001',
	   '::1 expands to 8 zero-padded groups');

	my $c2 = miniserv::canonicalize_ip6('2001:DB8::1');
	is($c2, '2001:0db8:0000:0000:0000:0000:0000:0001',
	   '2001:DB8::1 lower-cased and zero-expanded');

	is(miniserv::canonicalize_ip6('::'),
	   '0000:0000:0000:0000:0000:0000:0000:0000',
	   ':: expands to 8 zero-padded groups');
	is(miniserv::canonicalize_ip6('2001:db8::'),
	   '2001:0db8:0000:0000:0000:0000:0000:0000',
	   'trailing :: expands to 8 zero-padded groups');

	# Idempotency: running canonicalize on canonical input returns the same.
	is(miniserv::canonicalize_ip6($c), $c, 'canonical form is idempotent');
};

subtest 'expand_ipv6_bytes' => sub {
	my @bytes = miniserv::expand_ipv6_bytes(
		miniserv::canonicalize_ip6('::1'));
	is(scalar @bytes, 16, 'IPv6 expands to 16 bytes');
	is($bytes[15],     1, 'low byte is 1 for ::1');
	is($bytes[0],      0, 'high byte is 0 for ::1');
};

subtest 'ip6_prefix_match' => sub {
	ok( miniserv::ip6_prefix_match('2001:db8::1', '::', 0),
	    '/0 matches any IPv6 address');
	ok( miniserv::ip6_prefix_match('2001:dbf::1', '2001:db8::', 29),
	    '/29 accepts address inside non-byte-aligned prefix');
	ok(!miniserv::ip6_prefix_match('2001:dc0::1', '2001:db8::', 29),
	    '/29 rejects address outside non-byte-aligned prefix');
	ok( miniserv::ip6_prefix_match('2001:db8:ffff::1', '2001:db8::', 32),
	    '/32 matches across the third word');
	ok( miniserv::ip6_prefix_match('2001:db8:0:1::1', '2001:db8:0:1::', 63),
	    '/63 accepts address inside partial fourth-word prefix');
	ok(!miniserv::ip6_prefix_match('2001:db8:0:3::1', '2001:db8:0:1::', 63),
	    '/63 rejects address outside partial fourth-word prefix');
	ok( miniserv::ip6_prefix_match('2001:db8:0:1::1', '2001:db8:0:1::', 64),
	    '/64 matches exact first four words');
	ok( miniserv::ip6_prefix_match('2001:db8::2', '2001:db8::2', 127),
	    '/127 accepts low address in two-address subnet');
	ok( miniserv::ip6_prefix_match('2001:db8::3', '2001:db8::2', 127),
	    '/127 accepts high address in two-address subnet');
	ok(!miniserv::ip6_prefix_match('2001:db8::4', '2001:db8::2', 127),
	    '/127 rejects next subnet');
	ok( miniserv::ip6_prefix_match('2001:db8::1', '2001:db8::1', 128),
	    '/128 matches identical host address');
	ok(!miniserv::ip6_prefix_match('2001:db8::2', '2001:db8::1', 128),
	    '/128 rejects neighboring host address');
};

subtest 'ip_match IPv6 CIDR prefixes' => sub {
	ok( miniserv::ip_match('2001:dbf::1', '2001:db8::1', '2001:db8::/29'),
	    'ip_match accepts non-byte-aligned IPv6 CIDR match');
	ok(!miniserv::ip_match('2001:dc0::1', '2001:db8::1', '2001:db8::/29'),
	    'ip_match rejects neighboring non-byte-aligned IPv6 CIDR prefix');
	ok( miniserv::ip_match('2001:db8:0:1::1', '2001:db8::1', '2001:db8:0:1::/63'),
	    'ip_match accepts partial-byte IPv6 prefix');
	ok(!miniserv::ip_match('2001:db8:0:3::1', '2001:db8::1', '2001:db8:0:1::/63'),
	    'ip_match rejects address outside partial-byte IPv6 prefix');
};

# is_bad_header — ShellShock guard
subtest 'is_bad_header' => sub {
	ok( miniserv::is_bad_header('() { :; }; echo pwned'), 'ShellShock-shaped value flagged');
	ok( miniserv::is_bad_header('  () { x'),              'leading whitespace still flagged');
	ok(!miniserv::is_bad_header('Mozilla/5.0'),           'plain value not flagged');
	ok(!miniserv::is_bad_header('text/html'),             'plain value with no parens not flagged');
};

# is_mobile_useragent
subtest 'is_mobile_useragent' => sub {
	no warnings 'once';
	local @miniserv::mobile_agents = ();

	ok( miniserv::is_mobile_useragent('Mozilla/5.0 (iPhone; CPU iPhone OS)'),
	    'iPhone UA detected');
	ok( miniserv::is_mobile_useragent('Nokia6230/2.0'),
	    'Nokia prefix detected');
	ok( miniserv::is_mobile_useragent('Mozilla/5.0 (Linux; Android 10; Mobile)'),
	    'Android-mobile regexp matched');
	ok(!miniserv::is_mobile_useragent('Mozilla/5.0 (X11; Linux x86_64)'),
	    'desktop Linux not flagged');
	ok(!miniserv::is_mobile_useragent('curl/7.88.1'),
	    'curl not flagged');
};

# http_date — RFC 1123 GMT date
subtest 'http_date' => sub {
	my $d = miniserv::http_date(0);
	# 1970-01-01 00:00:00 GMT
	like($d, qr/^Thu,\s+1\s+Jan\s+1970\s+00:00:00\s+GMT$/,
	     'unix epoch formatted as RFC GMT date');

	like(miniserv::http_date(time()),
	     qr/^(?:Sun|Mon|Tue|Wed|Thu|Fri|Sat),\s+\d{1,2}\s+(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+\d{4}\s+\d{2}:\d{2}:\d{2}\s+GMT$/,
	     'current time matches RFC GMT shape');
};

# split_userdb_string — userdb URI parser
subtest 'split_userdb_string' => sub {
	my @r = miniserv::split_userdb_string(
		'mysql://admin:secret@db.example.com/webmin?ssl=1&port=3307');
	is(scalar @r, 6, 'valid URI parses to 6 elements');
	is($r[0], 'mysql',           'protocol');
	is($r[1], 'admin',           'username');
	is($r[2], 'secret',          'password');
	is($r[3], 'db.example.com',  'host');
	is($r[4], 'webmin',          'prefix');
	is(ref($r[5]), 'HASH',       'args is a hashref');
	is($r[5]->{ssl},  '1',       'ssl arg');
	is($r[5]->{port}, '3307',    'port arg');

	is_deeply([miniserv::split_userdb_string('not a url')], [],
		  'unparseable input returns empty list');
};

# get_logged_sensitive_params / sanitise_logged_request
subtest 'get_logged_sensitive_params' => sub {
	no warnings 'once';
	local %miniserv::config = ();

	my @defaults = miniserv::get_logged_sensitive_params();
	# Contract: default list covers the common sensitive param names.
	for my $expected (qw(password pass passwd token api_key secret)) {
		ok((grep { lc($_) eq $expected } @defaults),
		   "default list contains '$expected'");
	}

	local $miniserv::config{'log_redact_params'} = 'mycustom, another';
	my @plus = miniserv::get_logged_sensitive_params();
	ok((grep { $_ eq 'mycustom' } @plus), 'log_redact_params adds custom name');
	ok((grep { $_ eq 'another'  } @plus), 'log_redact_params is comma-separable');

	# Dedup: configuring an existing default name does not duplicate.
	local $miniserv::config{'log_redact_params'} = 'password';
	my @dup = miniserv::get_logged_sensitive_params();
	my @pw  = grep { lc($_) eq 'password' } @dup;
	is(scalar @pw, 1, 'duplicate of default name is deduplicated');
};

subtest 'sanitise_logged_request' => sub {
	no warnings 'once';
	local %miniserv::config = ();

	my $req = 'GET /login?user=alice&password=hunter2 HTTP/1.1';
	my $out = miniserv::sanitise_logged_request($req);

	unlike($out, qr/hunter2/,    'sensitive value removed');
	like  ($out, qr/user=alice/, 'non-sensitive param preserved');
	like  ($out, qr{^GET\s+/login\?.*HTTP/1\.1$}, 'request line shape preserved');

	# Multiple sensitive params on one line.
	my $multi = 'GET /x?token=abc&api_key=def&q=keep HTTP/1.0';
	my $mout  = miniserv::sanitise_logged_request($multi);
	unlike($mout, qr/abc/, 'token value removed');
	unlike($mout, qr/def/, 'api_key value removed');
	like  ($mout, qr/q=keep/, 'non-sensitive value preserved');

	# Custom redacted param from config.
	local $miniserv::config{'log_redact_params'} = 'sessionid';
	my $custom = miniserv::sanitise_logged_request(
		'GET /x?sessionid=zzz HTTP/1.1');
	unlike($custom, qr/zzz/, 'custom-configured param value removed');

	# Undef input survives.
	is(miniserv::sanitise_logged_request(undef), undef,
	   'undef input passes through');

	# Non-request strings pass through unchanged.
	is(miniserv::sanitise_logged_request('not a request line'),
	   'not a request line',
	   'non-request input passes through unchanged');
};

# matches_cron
subtest 'matches_cron' => sub {
	ok( miniserv::matches_cron('*',     5, 0), '* matches anything');
	ok( miniserv::matches_cron('5',     5, 0), 'exact match');
	ok(!miniserv::matches_cron('6',     5, 0), 'mismatch returns false');
	ok( miniserv::matches_cron('1,5,9', 5, 0), 'comma list match');
	ok(!miniserv::matches_cron('1,9',   5, 0), 'comma list miss');
	ok( miniserv::matches_cron('1-10',  5, 0), 'range match');
	ok(!miniserv::matches_cron('1-4',   5, 0), 'range miss');
	ok( miniserv::matches_cron('*/5',  10, 0), 'step match');
	ok(!miniserv::matches_cron('*/5',   7, 0), 'step miss');
};

# ip_match — host-based ACL matching (IPv4 only, no DNS branches)
subtest 'ip_match' => sub {
	no warnings 'once';
	local %miniserv::ip_match_cache = ();

	# ip_match rewrites $_[N] in place when converting CIDR to netmask,
	# so each rule must be passed as a scalar — not a string literal.
	my $check = sub {
		my ($remote, $local, @rules) = @_;
		return miniserv::ip_match($remote, $local, @rules);
	};

	my $exact_match_rule    = '1.2.3.4';
	my $exact_miss_rule     = '1.2.3.5';
	my $cidr_match_rule     = '1.2.3.0/24';
	my $cidr_miss_rule      = '1.2.4.0/24';
	my $netmask_rule        = '10.0.0.0/255.0.0.0';
	my $range_rule          = '1.2.3.5-1.2.3.15';
	my $partial_rule        = '1.2.3';
	my $multi_miss_rule     = '9.9.9.9';
	my $multi_match_rule    = '1.2.3.4';

	# Exact match.
	ok( $check->('1.2.3.4', '5.6.7.8', $exact_match_rule),
	    'exact IPv4 match');
	ok(!$check->('1.2.3.4', '5.6.7.8', $exact_miss_rule),
	    'one-off IPv4 mismatch');

	# CIDR.
	ok( $check->('1.2.3.4', '5.6.7.8', $cidr_match_rule),
	    'CIDR /24 match');
	ok(!$check->('1.2.3.4', '5.6.7.8', $cidr_miss_rule),
	    'CIDR /24 miss');

	# Netmask form.
	ok( $check->('10.0.0.5', '5.6.7.8', $netmask_rule),
	    'netmask form match');

	# Range form.
	ok( $check->('1.2.3.10', '5.6.7.8', $range_rule),
	    'range form match');
	ok(!$check->('1.2.3.20', '5.6.7.8', $range_rule),
	    'range form miss');

	# Partial address.
	ok( $check->('1.2.3.4', '5.6.7.8', $partial_rule),
	    'partial address /24-equivalent match');

	# Multiple rules: any match wins.
	ok( $check->('1.2.3.4', '5.6.7.8', $multi_miss_rule, $multi_match_rule),
	    'second rule matches when first does not');
};

# users_match — user-list matching (username branch only; the range
# branch references a different `@uinfo` global and the group branch
# calls getgrnam, so we test only the contract we'd refactor against).
subtest 'users_match (username branch)' => sub {
	my $uinfo = ['alice', 'x', 1000, 1000];

	ok( miniserv::users_match($uinfo, 'alice'),         'matching username returns true');
	ok( miniserv::users_match($uinfo, 'bob', 'alice'),  'matches against any in the list');
	ok(!miniserv::users_match($uinfo, 'bob', 'carol'),  'no match returns false');
	ok(!miniserv::users_match($uinfo),                  'empty user list returns false');
};

# websocket origin parsing — security-critical for CSWSH prevention
subtest 'normalise_websocket_origin' => sub {
	is(miniserv::normalise_websocket_origin('http',  'example.com', 80),
	   'http://example.com',          'default port 80 dropped for http');
	is(miniserv::normalise_websocket_origin('https', 'example.com', 443),
	   'https://example.com',         'default port 443 dropped for https');
	is(miniserv::normalise_websocket_origin('http',  'example.com', 8080),
	   'http://example.com:8080',     'non-default port kept');
	is(miniserv::normalise_websocket_origin('HTTP',  'Example.COM', 80),
	   'http://example.com',          'scheme and host lower-cased');
	is(miniserv::normalise_websocket_origin('http',  '[::1]',       8080),
	   'http://[::1]:8080',           'bracketed IPv6 host preserved');
	is(miniserv::normalise_websocket_origin('http',  '',            80), undef,
	   'empty host returns undef');
	is(miniserv::normalise_websocket_origin('',      'example.com', 80), undef,
	   'empty scheme returns undef');
};

subtest 'parse_websocket_origin' => sub {
	is(miniserv::parse_websocket_origin('http://example.com'),
	   'http://example.com',           'plain origin');
	is(miniserv::parse_websocket_origin('https://example.com:8443'),
	   'https://example.com:8443',     'origin with port');
	is(miniserv::parse_websocket_origin('http://[2001:db8::1]:80'),
	   'http://[2001:db8::1]',         'IPv6 with default port stripped');
	is(miniserv::parse_websocket_origin(undef),  undef, 'undef rejected');
	is(miniserv::parse_websocket_origin(''),     undef, 'empty rejected');
	is(miniserv::parse_websocket_origin('null'), undef, 'literal "null" rejected');
	is(miniserv::parse_websocket_origin('ftp://example.com'), undef,
	   'non-http(s) scheme rejected');
	is(miniserv::parse_websocket_origin('not a url'), undef,
	   'garbage rejected');
};

subtest 'parse_configured_websocket_origin' => sub {
	is(miniserv::parse_configured_websocket_origin('ws://example.com'),
	   'http://example.com',  'ws:// normalized to http://');
	is(miniserv::parse_configured_websocket_origin('wss://example.com'),
	   'https://example.com', 'wss:// normalized to https://');
	is(miniserv::parse_configured_websocket_origin('http://example.com'),
	   'http://example.com',  'http:// passes through');
};

subtest 'forwarded_websocket_origin' => sub {
	is(miniserv::forwarded_websocket_origin('http', 'example.com', 8080),
	   'http://example.com:8080', 'direct args');

	# Comma-separated forwarded headers: take the first.
	is(miniserv::forwarded_websocket_origin('http, https', 'a.com, b.com', 80),
	   'http://a.com', 'first comma-separated value used');

	# Host header that embeds a port.
	is(miniserv::forwarded_websocket_origin('http', 'example.com:8080', undef),
	   'http://example.com:8080', 'port embedded in host arg extracted');

	# Bracketed IPv6 host with port.
	is(miniserv::forwarded_websocket_origin('http', '[::1]:8080', undef),
	   'http://[::1]:8080', 'bracketed IPv6 host+port handled');

	is(miniserv::forwarded_websocket_origin(undef, 'example.com', 80),
	   undef, 'missing proto returns undef');
	is(miniserv::forwarded_websocket_origin('http', undef, 80),
	   undef, 'missing host returns undef');
};

# ssl_hostname_match — wildcard cert matching
subtest 'ssl_hostname_match' => sub {
	is(miniserv::ssl_hostname_match('example.com',  ['example.com']),    1,
	   'exact match');
	is(miniserv::ssl_hostname_match('Example.COM',  ['example.com']),    1,
	   'case-insensitive');
	is(miniserv::ssl_hostname_match('foo.example.com', ['*.example.com']), 1,
	   'wildcard subdomain match');
	is(miniserv::ssl_hostname_match('example.com',  ['*.example.com']),  1,
	   'wildcard accepts apex too');
	is(miniserv::ssl_hostname_match('other.com',    ['example.com']),    0,
	   'no match returns 0');
	is(miniserv::ssl_hostname_match('anything.tld', ['*']),              2,
	   'bare * returns 2');
	is(miniserv::ssl_hostname_match('example.com:8443', ['example.com']), 1,
	   ':port suffix is stripped before matching');
};

# Capability probes used by the crypto subtests below. miniserv.pl's
# detection logic runs inside its `unless(caller)` block, so when we load
# it as a module the $use_md5 / $use_sha512 / $use_hmac_sha256 globals are
# undef. Recreate them here from the same probes miniserv.pl uses itself.
my $have_md5 = eval {
	require Digest::MD5;
	Digest::MD5->new->add('x');
	'Digest::MD5';
	};
my $have_sha512 = miniserv::unix_crypt_supports_sha512() ? 1 : 0;
my $have_hmac   = eval {
	require Digest::SHA;
	Digest::SHA::hmac_sha256_hex('x', 'y');
	1;
	};

# to64 — itoa64 base64-style encoder used by encrypt_md5
#
# Indexes into @itoa64 ("./0123456789A-Za-z"). Output is exactly $n chars;
# input is processed 6 bits at a time, low bits first.
subtest 'to64' => sub {
	is(miniserv::to64(0,  1), '.', 'index 0 → .');
	is(miniserv::to64(1,  1), '/', 'index 1 → /');
	is(miniserv::to64(2,  1), '0', 'index 2 → 0');
	is(miniserv::to64(63, 1), 'z', 'index 63 → z (last alphabet char)');

	is(length(miniserv::to64(0,        4)), 4, 'output length = requested digits');
	is(length(miniserv::to64(0xffffff, 4)), 4, 'output length is constant, not entropy-dependent');

	like(miniserv::to64(0xabcdef, 4), qr{^[./0-9A-Za-z]{4}$},
	     'output uses only the itoa64 alphabet');

	# 0x3f occupies the low 6 bits → first char z, remaining shifts → dots.
	is(miniserv::to64(0x3f, 4), 'z...', 'low-bits-first ordering');
};

# encrypt_md5 — $1$ MD5-crypt
#
# Security-critical: this hashes user passwords. Contract we pin:
#   - salt is preserved verbatim in the output
#   - hash body is 22 itoa64 chars
#   - deterministic for the same input
#   - passing a full $1$salt$hash form re-extracts the salt (verification)
#   - a different password produces a different hash
subtest 'encrypt_md5' => sub {
	plan skip_all => 'Digest::MD5 not available' if !$have_md5;
	no warnings 'once';
	local $miniserv::use_md5 = $have_md5;

	my $h = miniserv::encrypt_md5('password', 'abcdefgh');
	like($h, qr{^\$1\$abcdefgh\$[./0-9A-Za-z]{22}$},
	     '$1$<salt>$<22-char hash> shape');
	is(miniserv::encrypt_md5('password', 'abcdefgh'), $h, 'deterministic');
	is(miniserv::encrypt_md5('password', $h),         $h,
	   'salt re-extracted from $1$salt$hash form (verification round-trip)');
	isnt(miniserv::encrypt_md5('wrong', $h), $h,
	     'different password → different hash');

	# No-salt form skips the iteration loop and returns just the body.
	my $bare = miniserv::encrypt_md5('password');
	unlike($bare, qr{\$}, 'no-salt form has no $-prefix');
	like  ($bare, qr{^[./0-9A-Za-z]+$}, 'no-salt form uses itoa64 alphabet');
};

# unix_crypt — thin wrapper over libc crypt (or Crypt::UnixCrypt)
subtest 'unix_crypt' => sub {
	no warnings 'once';
	local $miniserv::use_perl_crypt;
	my $h = miniserv::unix_crypt('password', 'xy');
	is(length($h), 13, 'classic DES crypt output is 13 chars');
	like($h, qr{^xy}, 'salt is the prefix of the output');
	is  (miniserv::unix_crypt('password', $h), $h, 'verification round-trip');
	isnt(miniserv::unix_crypt('wrong',    $h), $h, 'wrong password → different hash');
};

# unix_crypt_supports_sha512 — capability probe used at startup
subtest 'unix_crypt_supports_sha512' => sub {
	my $r = miniserv::unix_crypt_supports_sha512();
	ok(defined($r),           'returns a defined value');
	ok($r == 0 || $r == 1,    'returns 0 or 1');
};

# encrypt_sha512 — $6$ SHA512-crypt via libc crypt()
subtest 'encrypt_sha512' => sub {
	plan skip_all => 'crypt() does not support SHA512 on this system'
		if !$have_sha512;

	my $h = miniserv::encrypt_sha512('password', '$6$testtest$');
	like($h, qr{^\$6\$testtest\$}, '$6$<salt>$ prefix preserved');
	cmp_ok(length($h), '>', 50,
	       'SHA512 output is much longer than DES (DES is 13 chars)');

	is  (miniserv::encrypt_sha512('password', $h), $h,
	     'deterministic for same (password, salt) — verification round-trip');
	isnt(miniserv::encrypt_sha512('wrong', $h), $h,
	     'different password → different hash');
	like(miniserv::encrypt_sha512('password'), qr{^\$6\$},
	     'no-salt path synthesises $6$ salt');
};

# password_crypt — verifies a stored hash by recomputing
#
# The salt parameter doubles as the expected output: the caller passes the
# stored hash, and password_crypt returns the recomputed hash. Equality means
# "password matches". A non-$1$/$6$ salt (or unsupported module) falls through
# to plain crypt().
subtest 'password_crypt' => sub {
	no warnings 'once';
	local $miniserv::use_md5    = $have_md5;
	local $miniserv::use_sha512 = $have_sha512;
	local $miniserv::use_perl_crypt;

	SKIP: {
		skip 'Digest::MD5 not available', 2 if !$have_md5;
		my $stored = miniserv::encrypt_md5('hunter2', 'abcdefgh');
		is  (miniserv::password_crypt('hunter2', $stored), $stored,
		     '$1$ stored hash + correct password verifies');
		isnt(miniserv::password_crypt('wrong',   $stored), $stored,
		     '$1$ stored hash + wrong password does not verify');
	}

	SKIP: {
		skip 'SHA512 crypt not available', 2 if !$have_sha512;
		my $stored = miniserv::encrypt_sha512('hunter2', '$6$testtest$');
		is  (miniserv::password_crypt('hunter2', $stored), $stored,
		     '$6$ stored hash + correct password verifies');
		isnt(miniserv::password_crypt('wrong',   $stored), $stored,
		     '$6$ stored hash + wrong password does not verify');
	}

	# 2-char salt → DES fallback (no $1$/$6$ branch taken).
	my $des = miniserv::unix_crypt('hunter2', 'xy');
	is(miniserv::password_crypt('hunter2', $des), $des,
	   'DES stored hash + correct password verifies');
};

# hash_session_id — three independent code paths, picked by which crypto
# globals are set. Each branch gets its own subtest so the cache and globals
# can be reset cleanly via `local`.

subtest 'hash_session_id (HMAC-SHA256 branch)' => sub {
	plan skip_all => 'Digest::SHA hmac_sha256_hex not available' if !$have_hmac;
	no warnings 'once';
	local $miniserv::use_hmac_sha256        = 1;
	local $miniserv::session_hmac_key       = 'a' x 32;
	local %miniserv::hash_session_id_cache  = ();

	my $h = miniserv::hash_session_id('sess123');
	like($h, qr{^[0-9a-f]{64}$}, 'HMAC-SHA256 hex output: 64 hex chars');
	is  (miniserv::hash_session_id('sess123'), $h,
	     'second call for same sid is cached (and stable)');
	isnt(miniserv::hash_session_id('other'), $h,
	     'different sid → different hash');

	# Different key must change the hash for the same input.
	%miniserv::hash_session_id_cache = ();
	local $miniserv::session_hmac_key = 'b' x 32;
	isnt(miniserv::hash_session_id('sess123'), $h,
	     'different HMAC key → different hash for the same sid');
};

subtest 'hash_session_id (MD5 branch)' => sub {
	plan skip_all => 'Digest::MD5 not available' if !$have_md5;
	no warnings 'once';
	local $miniserv::use_hmac_sha256       = 0;
	local $miniserv::session_hmac_key      = undef;
	local $miniserv::use_md5               = $have_md5;
	local %miniserv::hash_session_id_cache = ();

	my $h = miniserv::hash_session_id('sess123');
	like($h, qr{^[./0-9A-Za-z]{22}$},
	     'MD5 (no-salt) form: 22 itoa64 chars');
	is(miniserv::hash_session_id('sess123'), $h, 'cached on second call');
};

subtest 'hash_session_id (unix_crypt fallback)' => sub {
	no warnings 'once';
	local $miniserv::use_hmac_sha256       = 0;
	local $miniserv::session_hmac_key      = undef;
	local $miniserv::use_md5               = undef;
	local %miniserv::hash_session_id_cache = ();

	my $h = miniserv::hash_session_id('sess123');
	is(length($h), 13, 'DES crypt fallback is 13 chars');
	is(miniserv::hash_session_id('sess123'), $h, 'cached on second call');
};

# generate_random_id — session ID generator
#
# Two paths: /dev/urandom (preferred) and a rand()-based fallback. The
# fallback should still produce a 32-char lowercase hex string. With
# force_urandom=1 and /dev/urandom marked bad, the function must return
# undef rather than fall back silently.
subtest 'generate_random_id' => sub {
	no warnings 'once';

	# Fallback path: pretend /dev/urandom is unusable, allow fallback.
	{
		local $miniserv::bad_urandom = 1;
		my $sid = miniserv::generate_random_id();
		like($sid, qr{^[0-9a-f]{32}$}, 'fallback produces 32-char lowercase hex id');
		isnt(miniserv::generate_random_id(), $sid,
		     'two fallback calls produce different ids');
	}

	# /dev/urandom path, when available.
	SKIP: {
		skip '/dev/urandom not readable', 1 if !-r '/dev/urandom';
		local $miniserv::bad_urandom = 0;
		my $sid = miniserv::generate_random_id();
		like($sid, qr{^[0-9a-f]{32}$},
		     '/dev/urandom path produces 32-char lowercase hex id');
	}

	# force_urandom=1 + bad_urandom → no fallback, returns undef.
	{
		local $miniserv::bad_urandom = 1;
		is(miniserv::generate_random_id(1), undef,
		   'force_urandom=1 with bad_urandom returns undef (no silent fallback)');
	}
};

# check_user_time — login allowed by current date/time?
#
# Pure logic over a $uinfo hashref once get_user_details is stubbed. We
# anchor allow-window tests around the current minute-of-day so they pass
# regardless of when the suite runs.
subtest 'check_user_time' => sub {
	no warnings qw(redefine once);
	my $uinfo;
	local *miniserv::get_user_details = sub { $uinfo };

	# Unknown user → allowed (returns 1 early).
	$uinfo = undef;
	ok(miniserv::check_user_time('alice'), 'unknown user → allowed');

	# Known user with no restrictions → allowed.
	$uinfo = { 'name' => 'alice' };
	ok(miniserv::check_user_time('alice'),
	   'user with no allowdays/allowhours → allowed');

	my @tm = localtime(time());
	my $today     = $tm[6];
	my $not_today = ($today + 3) % 7;
	my $now_min   = $tm[2] * 60 + $tm[1];

	$uinfo = { 'allowdays' => [$today] };
	ok(miniserv::check_user_time('alice'), 'current weekday in allowdays → allowed');

	$uinfo = { 'allowdays' => [$not_today] };
	ok(!miniserv::check_user_time('alice'), 'current weekday not in allowdays → denied');

	# Build a window that contains $now_min and is clamped to [0, 1439]
	# so we never depend on negative bounds happening to compare correctly.
	my $in_lo = $now_min >= 5    ? $now_min - 5 : 0;
	my $in_hi = $now_min <= 1434 ? $now_min + 5 : 1439;
	$uinfo = { 'allowhours' => [$in_lo, $in_hi] };
	ok(miniserv::check_user_time('alice'), 'current time inside allowhours window → allowed');

	# A fixed window strictly disjoint from $now_min and entirely within
	# [0, 1439]. Pick the half-day opposite the current time: morning →
	# evening window, afternoon/night → early-morning window. Either way
	# the window cannot contain $now_min, and the bounds stay valid.
	my ($out_lo, $out_hi) = $now_min < 720
				? (1380, 1430)   # 23:00–23:50
				: (10,   60);    # 00:10–01:00
	$uinfo = { 'allowhours' => [$out_lo, $out_hi] };
	ok(!miniserv::check_user_time('alice'),
	   'current time outside allowhours window → denied');
};

# check_user_ip — login allowed from current remote IP?
#
# Same shape as check_user_time: stub get_user_details, set $acptip and
# $localip (package globals that handle_request normally `local`-izes).
subtest 'check_user_ip' => sub {
	no warnings qw(redefine once);
	my $uinfo;
	local *miniserv::get_user_details = sub { $uinfo };
	local %miniserv::ip_match_cache   = ();
	local $miniserv::acptip           = '1.2.3.4';
	local $miniserv::localip          = '5.6.7.8';

	$uinfo = undef;
	ok(miniserv::check_user_ip('alice'), 'unknown user → allowed');

	$uinfo = { 'name' => 'alice' };
	ok(miniserv::check_user_ip('alice'),
	   'no allow or deny list → allowed');

	my $deny_match = '1.2.3.4';
	my $deny_miss  = '9.9.9.9';
	my $allow_match = '1.2.3.4';
	my $allow_miss  = '9.9.9.9';

	$uinfo = { 'name' => 'alice', 'deny' => [ $deny_match ] };
	ok(!miniserv::check_user_ip('alice'), 'deny list matches remote → denied');

	$uinfo = { 'name' => 'alice', 'deny' => [ $deny_miss ] };
	ok(miniserv::check_user_ip('alice'), 'deny list does not match → allowed');

	$uinfo = { 'name' => 'alice', 'allow' => [ $allow_match ] };
	ok(miniserv::check_user_ip('alice'), 'allow list matches remote → allowed');

	$uinfo = { 'name' => 'alice', 'allow' => [ $allow_miss ] };
	ok(!miniserv::check_user_ip('alice'), 'allow list does not match → denied');
};

# is_group_member — primary-gid match OR membership in /etc/group
#
# We pin the contract using the current process's own primary group, which
# is guaranteed to exist on any system that runs the test suite.
subtest 'is_group_member' => sub {
	my @pw = getpwuid($<);
	plan skip_all => 'cannot resolve current user via getpwuid' if !@pw;
	my $primary_gid = $pw[3];
	my @gr = getgrgid($primary_gid);
	plan skip_all => 'cannot resolve current primary gid via getgrgid' if !@gr;
	my $primary_group = $gr[0];

	# uinfo[3] == primary gid → match regardless of group's member list.
	my $uinfo_match = ['test-user', 'x', 99999, $primary_gid];
	ok(miniserv::is_group_member($uinfo_match, $primary_group),
	   'primary gid match → member');

	# Nonexistent group → 0.
	ok(!miniserv::is_group_member($uinfo_match,
	    '__definitely_not_a_real_group_xyzzy__'),
	   'nonexistent group → not a member');

	# A user that's neither in the group's member list nor sharing its gid.
	my $other_group;
	my $other_gid;
	setgrent();
	while (my @g = getgrent()) {
		next if $g[2] == $primary_gid;
		# Skip groups our synthetic user happens to be "in"
		next if $g[3] =~ /\bdefinitely-not-in-this-group-xyzzy\b/;
		$other_group = $g[0];
		$other_gid   = $g[2];
		last;
		}
	endgrent();
	SKIP: {
		skip 'no second group available on this system', 1 if !$other_group;
		my $alien = ['definitely-not-in-this-group-xyzzy', 'x', 99999, 99999];
		ok(!miniserv::is_group_member($alien, $other_group),
		   'gid mismatch + not in member list → not a member');
	}
};

# matches_cron — combined range/step (the `1-10/2` branch is not covered above)
subtest 'matches_cron (range/step)' => sub {
	ok( miniserv::matches_cron('2-10/2',  4, 0), 'inside range, divisible by step → match');
	ok(!miniserv::matches_cron('2-10/2',  3, 0), 'inside range, indivisible → miss');
	ok(!miniserv::matches_cron('2-10/2', 12, 0), 'outside range → miss');
	ok( miniserv::matches_cron('0-30/15', 15, 0), 'step matches at boundary');
};

# indexof — duplicate / undef handling
subtest 'indexof (extras)' => sub {
	# Duplicates: first hit wins.
	is(miniserv::indexof('a', 'a', 'b', 'a'), 0,
	   'duplicate needle returns first index');
	# Numeric needle compared with `eq` to a string element.
	is(miniserv::indexof(1, '0', '1', '2'), 1,
	   'numeric needle matches stringwise');
};

# get_type — the regex is /\.([A-z0-9]+)$/ — `[A-z]` covers more than letters.
subtest 'get_type (extras)' => sub {
	no warnings 'once';
	local %miniserv::mime = (HTML => 'text/html-upper');
	# Extension lookup is case-sensitive (the hash key wins or loses literally).
	is(miniserv::get_type('foo.HTML'), 'text/html-upper',
	   'extension hash lookup is case-sensitive');
	is(miniserv::get_type('foo.html'), 'text/plain',
	   'differently-cased miss falls back to text/plain');
	# Empty extension — pattern needs at least one char after the dot.
	is(miniserv::get_type('foo.'), 'text/plain',
	   'empty extension falls through');
};

# is_mobile_useragent — config-driven `@mobile_agents` extension list
subtest 'is_mobile_useragent (config-driven extras)' => sub {
	no warnings 'once';
	local @miniserv::mobile_agents = ('MyCustomBrowser');

	ok( miniserv::is_mobile_useragent('Foo MyCustomBrowser/1.0'),
	    'config-supplied substring matches');
	ok(!miniserv::is_mobile_useragent('Foo OtherBrowser/1.0'),
	    'unrelated UA still not flagged');
	# Text-mode browsers (Lynx, Links) are in the hard-coded prefix list.
	ok(miniserv::is_mobile_useragent('Lynx/2.8.9rel.1'), 'Lynx prefix flagged');
	ok(miniserv::is_mobile_useragent('Links (2.21; Linux)'), 'Links prefix flagged');
};

# urlize — high-bit / control-character behaviour
subtest 'urlize (extras)' => sub {
	# Non-ASCII bytes — must be percent-encoded.
	my $out = miniserv::urlize("\xc3\xa9");        # UTF-8 'é'
	like($out, qr/^%[0-9A-Fa-f]{2}%[0-9A-Fa-f]{2}$/,
	     'high-bit UTF-8 bytes are percent-encoded');
	# Control characters.
	is(miniserv::urlize("\n"), '%0A', 'newline encoded');
	is(miniserv::urlize("\t"), '%09', 'tab encoded');
};

# simplify_path — additional adversarial inputs
subtest 'simplify_path (extras)' => sub {
	my $bogus;
	# An empty string normalises to a bare slash.
	is(miniserv::simplify_path('', $bogus), '/', 'empty string → /');
	# A trailing slash is preserved? Run it and pin whatever the contract is.
	is(miniserv::simplify_path('/foo/', $bogus), '/foo',
	   'trailing slash collapses');
	# ".." mixed with concrete segments collapses correctly.
	is(miniserv::simplify_path('/a/b/c/../../d', $bogus), '/a/d',
	   'multiple .. pop the right number of segments');
	is($bogus, 0, '.. that stays in-bounds is not bogus');
};

# make_datestr — log timestamp format
subtest 'make_datestr' => sub {
	no warnings 'once';
	local @miniserv::month = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
	local $miniserv::timezone = '+0000';

	my $d = miniserv::make_datestr();
	# Format: DD/Mon/YYYY:HH:MM:SS +0000 (Apache combined-log shape).
	like($d, qr{^\d{2}/(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)/\d{4}:\d{2}:\d{2}:\d{2}\s\+0000$},
	     'datestr matches Apache combined-log shape');
};

# getenv — case-insensitive env var lookup
subtest 'getenv' => sub {
	local %ENV = (FOO => 'upper', bar => 'lower');
	is(miniserv::getenv('foo'), 'upper', 'lc lookup finds uc-set var');
	is(miniserv::getenv('FOO'), 'upper', 'uc lookup finds uc-set var');
	is(miniserv::getenv('BAR'), 'lower', 'uc lookup falls through to lc-set var');
	is(miniserv::getenv('bar'), 'lower', 'lc lookup finds lc-set var');
	is(miniserv::getenv('missing'), undef, 'missing var returns undef');
};

# should_gzip_file — content-type-class allow/deny
subtest 'should_gzip_file' => sub {
	ok( miniserv::should_gzip_file('foo.html'), 'html → gzip ok');
	ok( miniserv::should_gzip_file('foo.css'),  'css → gzip ok');
	ok( miniserv::should_gzip_file('foo.js'),   'js → gzip ok');
	ok( miniserv::should_gzip_file('noext'),    'no extension → gzip ok');
	ok(!miniserv::should_gzip_file('foo.png'),  'png skipped');
	ok(!miniserv::should_gzip_file('foo.jpg'),  'jpg skipped');
	ok(!miniserv::should_gzip_file('foo.JPEG'), 'JPEG (uppercase) skipped');
	ok(!miniserv::should_gzip_file('foo.tif'),  'tif skipped');
};

# get_expires_time — per-path expiry table with default fallback
subtest 'get_expires_time' => sub {
	no warnings 'once';
	local @miniserv::expires_paths = (
		[ '\.css$', 3600  ],
		[ '\.js$',  86400 ],
		);
	local %miniserv::config = ('expires' => 60);

	is(miniserv::get_expires_time('/x.css'), 3600,
	   'matching regexp → its expiry');
	is(miniserv::get_expires_time('/x.js'),  86400,
	   'second matching regexp → its expiry');
	is(miniserv::get_expires_time('/x.html'), 60,
	   'no match → falls back to config{expires}');
	# Case-insensitivity is part of the contract (path !~ /$re/i).
	is(miniserv::get_expires_time('/X.CSS'), 3600,
	   'regexp match is case-insensitive');
};

# network_to_address — inet_ntoa / inet_ntop dispatch
subtest 'network_to_address' => sub {
	no warnings 'once';

	# 4-byte input always uses inet_ntoa, regardless of $use_ipv6.
	{
		local $miniserv::use_ipv6 = 0;
		is(miniserv::network_to_address(pack("CCCC", 1, 2, 3, 4)),
		   '1.2.3.4', 'IPv4 bytes formatted via inet_ntoa');
	}

	# 16-byte input with IPv6 enabled → inet_ntop. miniserv.pl normally
	# imports inet_ntop via Socket6 (loaded under `eval` at startup); in the
	# module-load path it may not be bound, so glob it in for the test.
	SKIP: {
		eval { require Socket; Socket->import(qw(AF_INET6 inet_ntop inet_pton)); };
		skip 'Socket lacks IPv6 helpers', 1 if $@;
		no warnings 'redefine';
		local *miniserv::inet_ntop = \&Socket::inet_ntop;
		local $miniserv::use_ipv6 = 1;
		my $packed = Socket::inet_pton(Socket::AF_INET6(), '::1');
		is(miniserv::network_to_address($packed), '::1',
		   'IPv6 bytes formatted via inet_ntop');
	}
};

# to_ipaddress — pattern shortcuts that skip DNS
subtest 'to_ipaddress (pattern shortcuts)' => sub {
	# IPv4 literal: returned verbatim.
	is(miniserv::to_ipaddress('1.2.3.4'), '1.2.3.4',
	   'IPv4 literal short-circuits');
	# Hostname-glob pattern: returned verbatim.
	is(miniserv::to_ipaddress('*.example.com'), '*.example.com',
	   'wildcard hostname pattern short-circuits');
	# 'LOCAL' literal: returned verbatim.
	is(miniserv::to_ipaddress('LOCAL'), 'LOCAL',
	   'LOCAL keyword short-circuits');
	# CIDR pattern: returned verbatim.
	is(miniserv::to_ipaddress('10.0.0.0/8'), '10.0.0.0/8',
	   'CIDR pattern short-circuits');
};

# ip_match — additional branches: LOCAL, IPv6 exact, IPv6 CIDR, hostname-glob miss
subtest 'ip_match (extra branches)' => sub {
	no warnings 'once';
	local %miniserv::ip_match_cache = ();

	# LOCAL keyword expands to a class-derived prefix of the local IP.
	my $local_rule = 'LOCAL';
	ok( miniserv::ip_match('10.1.2.3', '10.9.9.9', $local_rule),
	    'LOCAL: class-A remote in same /8 as local matches');
	ok(!miniserv::ip_match('11.1.2.3', '10.9.9.9', $local_rule),
	    'LOCAL: different /8 does not match');

	# 192.x.x.x is class C → /24 comparison.
	my $local_rule2 = 'LOCAL';
	ok( miniserv::ip_match('192.168.1.5', '192.168.1.1', $local_rule2),
	    'LOCAL: class-C remote in same /24 as local matches');
	ok(!miniserv::ip_match('192.168.2.5', '192.168.1.1', $local_rule2),
	    'LOCAL: different /24 does not match');

	# IPv6 exact match.
	my $v6_exact = '2001:db8::1';
	ok( miniserv::ip_match('2001:db8::1', '::1', $v6_exact),
	    'IPv6 exact match (canonicalized)');
	ok( miniserv::ip_match('2001:DB8::1', '::1', $v6_exact),
	    'IPv6 exact match is case-insensitive after canonicalization');

	# IPv6 CIDR — /32 covers the leading 4 bytes (2001:0db8:...).
	my $v6_cidr = '2001:db8::/32';
	ok( miniserv::ip_match('2001:db8:1234::5', '::1', $v6_cidr),
	    'IPv6 CIDR /32 covers a host inside the prefix');
	ok(!miniserv::ip_match('2002:db8:1234::5', '::1', $v6_cidr),
	    'IPv6 CIDR /32 does not cover a host outside the prefix');
};

# users_match — group (@-prefix) branch
subtest 'users_match (group branch)' => sub {
	# Pick the current user's primary group, guaranteed to resolve.
	my @pw = getpwuid($<);
	plan skip_all => 'cannot resolve current user via getpwuid' if !@pw;
	my $gid = $pw[3];
	my @gr  = getgrgid($gid);
	plan skip_all => 'cannot resolve primary gid via getgrgid' if !@gr;
	my $group = $gr[0];

	# uinfo[3] == primary gid → is_group_member returns true → users_match matches.
	my $uinfo = ['someuser', 'x', 99999, $gid];
	ok( miniserv::users_match($uinfo, '@'.$group),
	    '@<group> matches when uinfo primary gid matches');
	ok(!miniserv::users_match($uinfo,
				 '@__definitely_not_a_real_group_xyzzy__'),
	    '@<nonexistent-group> does not match');
};

# read_config_file — KEY=VAL parser used at startup
subtest 'read_config_file' => sub {
	require File::Temp;
	my ($fh, $path) = File::Temp::tempfile(UNLINK => 1);
	print $fh <<'EOF';
# this is a comment

  key1 = value1
key2=value2
  key3   =   has  spaces
empty=
EOF
	close($fh);

	my %got = miniserv::read_config_file($path);
	is($got{key1},  'value1',         'leading/trailing whitespace trimmed');
	is($got{key2},  'value2',         'tight key=val parsed');
	is($got{key3},  'has  spaces',    'interior whitespace preserved');
	is($got{empty}, '',               'empty value yields empty string');
	ok(!exists $got{'# this is a comment'}, 'comment lines skipped');
};

# read_any_file — basic file reader; returns undef on open failure
subtest 'read_any_file' => sub {
	require File::Temp;
	my ($fh, $path) = File::Temp::tempfile(UNLINK => 1);
	print $fh "line1\nline2\n";
	close($fh);

	is(miniserv::read_any_file($path), "line1\nline2\n",
	   'returns the entire file contents');
	is(miniserv::read_any_file('/definitely/not/a/real/path/xyzzy'), undef,
	   'open failure returns undef');
};

# read_mime_types — populates %mime from file + addtype_* config
subtest 'read_mime_types' => sub {
	no warnings 'once';
	require File::Temp;
	my ($fh, $path) = File::Temp::tempfile(UNLINK => 1);
	print $fh <<'EOF';
# comment line
text/html	html htm
image/png	png
EOF
	close($fh);

	local %miniserv::config = (
		'mimetypes'        => $path,
		'addtype_custom'   => 'application/x-custom',
		);
	local %miniserv::mime = ();

	miniserv::read_mime_types();
	is($miniserv::mime{html},   'text/html',          'first extension from file mapped');
	is($miniserv::mime{htm},    'text/html',          'second extension on same line mapped');
	is($miniserv::mime{png},    'image/png',          'second line mapped');
	is($miniserv::mime{custom}, 'application/x-custom', 'addtype_* config overrides file');
};

# parse_websockets_config — turns websockets_<path> config lines into structs
subtest 'parse_websockets_config' => sub {
	no warnings 'once';
	local %miniserv::config = (
		'websockets_/chat' => 'host=back.example.com port=9000 proto=ws ssl=1 checkssl=1 backend_session=abc123',
		'unrelated_key'    => 'ignored',
		);
	local @miniserv::websocket_paths = ();

	miniserv::parse_websockets_config();
	is(scalar @miniserv::websocket_paths, 1, 'one websocket entry produced');
	my $ws = $miniserv::websocket_paths[0];
	is($ws->{path},  '/chat',             'path captured from key suffix');
	is($ws->{host},  'back.example.com',  'host kv parsed');
	is($ws->{port},  '9000',              'port kv parsed');
	is($ws->{proto}, 'ws',                'proto kv parsed');
	is($ws->{ssl},   '1',                 'ssl kv parsed');
	is($ws->{checkssl}, '1',              'SSL check kv parsed');
	is($ws->{backend_session}, 'abc123',  'backend session kv parsed');
};

# find_websocket_config
subtest 'find_websocket_config' => sub {
	no warnings 'once';
	local %miniserv::config = ( 'redirect_prefix' => '/prefix' );
	local @miniserv::websocket_paths = (
		{ 'path' => '/chat' },
		);

	my ($ws, $simple) = miniserv::find_websocket_config('/prefix/chat');
	is($ws->{path}, '/chat', 'matches after redirect prefix stripping');
	is($simple, '/chat', 'returns canonical websocket path');
	($ws, $simple) = miniserv::find_websocket_config('/prefix/chat?token=abc');
	is($ws->{path}, '/chat', 'matches request path with query string');
	is($simple, '/chat', 'drops query string from canonical path');
	ok(!miniserv::find_websocket_config('/missing'), 'unknown path rejected');
};

# get_user_details — local-files branch (skips the userdb code path entirely)
subtest 'get_user_details (local files)' => sub {
	no warnings 'once';
	local %miniserv::config       = ();   # no userdb → file path only
	local %miniserv::users        = ('alice' => 'hashedpass');
	local %miniserv::certs        = ('alice' => 'CN=Alice');
	local %miniserv::allow        = ('alice' => ['1.2.3.4']);
	local %miniserv::deny         = ('alice' => ['9.9.9.9']);
	local %miniserv::allowdays    = ('alice' => [0, 1, 2]);
	local %miniserv::allowhours   = ('alice' => [540, 1020]);
	local %miniserv::lastchanges  = ('alice' => '1700000000');
	local %miniserv::nochange     = ('alice' => 1);
	local %miniserv::temppass     = ('alice' => 0);
	local %miniserv::twofactor    = ('alice' => {
		'provider' => 'totp', 'id' => 'aliceid', 'apikey' => 'secret' });

	my $u = miniserv::get_user_details('alice');
	is(ref($u), 'HASH',                       'returns a hashref');
	is($u->{name},     'alice',               'name field');
	is($u->{pass},     'hashedpass',          'pass field comes from %users');
	is($u->{certs},    'CN=Alice',            'certs field');
	is_deeply($u->{allow}, ['1.2.3.4'],       'allow list');
	is_deeply($u->{deny},  ['9.9.9.9'],       'deny list');
	is($u->{twofactor_provider}, 'totp',      'twofactor provider lifted');
	is($u->{twofactor_id},       'aliceid',   'twofactor id lifted');
	is($u->{twofactor_apikey},   'secret',    'twofactor apikey lifted');

	is(miniserv::get_user_details('nobody'), undef,
	   'unknown user with no userdb returns undef');

	# origusername falls back to username for twofactor lookup.
	local %miniserv::twofactor = (
		'bob_orig' => { 'provider' => 'duo', 'id' => 'bid', 'apikey' => 'bk' });
	local %miniserv::users = ('bob_local' => 'hash');
	my $u2 = miniserv::get_user_details('bob_local', 'bob_orig');
	is($u2->{twofactor_provider}, 'duo',
	   'twofactor looked up by origusername when present');
};

# find_user_by_cert — local-files branch (matches against %certs)
subtest 'find_user_by_cert (local files)' => sub {
	no warnings 'once';
	local %miniserv::config = ();   # no userdb
	local %miniserv::certs  = (
		'alice' => 'CN=Alice,Email=alice@example.com',
		'bob'   => 'CN=Bob,emailAddress=bob@example.com',
		);

	is(miniserv::find_user_by_cert('CN=Alice,Email=alice@example.com'),
	   'alice', 'exact match returns username');
	# emailAddress=/Email= are swapped before comparison.
	is(miniserv::find_user_by_cert('CN=Alice,emailAddress=alice@example.com'),
	   'alice', 'Email/emailAddress form aliasing matches');
	is(miniserv::find_user_by_cert('CN=Bob,Email=bob@example.com'),
	   'bob',   'reverse aliasing also matches');
	is(miniserv::find_user_by_cert('CN=Nobody'), undef,
	   'unknown peer name returns undef');
};

# get_logout_time — per-user / per-group / default rules
subtest 'get_logout_time' => sub {
	no warnings 'once';
	local %miniserv::logout_time_cache = ();

	# Username branch beats the default.
	local @miniserv::logouttimes = (
		[ 'alice', 30 ],
		[ undef,   10 ],
		);
	is(miniserv::get_logout_time('alice', 'sid1'), 30,
	   'username-specific rule wins');
	is(miniserv::get_logout_time('alice', 'sid1'), 30,
	   'second call returns cached value');

	is(miniserv::get_logout_time('charlie', 'sid2'), 10,
	   'user with no specific rule falls through to default (undef key)');

	# Group rule (@-prefix) — requires that the user resolves via getpwnam,
	# so use the current process user.
	my @pw = getpwuid($<);
	SKIP: {
		skip 'cannot resolve current user', 1 if !@pw;
		my @gr = getgrgid($pw[3]);
		skip 'cannot resolve primary group', 1 if !@gr;
		local %miniserv::logout_time_cache = ();
		local @miniserv::logouttimes = (
			[ '@'.$gr[0], 99 ],
			[ undef,      10 ],
			);
		is(miniserv::get_logout_time($pw[0], 'sid3'), 99,
		   '@group rule matches via primary gid');
	}
};

# build_config_mappings — turns flat %config keys into structured globals
subtest 'build_config_mappings' => sub {
	no warnings qw(once redefine);
	# Stub open_debug_to_log — it touches DEBUG (an unopened fh in tests).
	local *miniserv::open_debug_to_log = sub { };
	local *miniserv::to_ipaddress      = sub { return @_; };

	local %miniserv::config = (
		'anonymous'         => '/pub=guest /api=apiuser',
		'ipaccess'          => '/admin=10.0.0.0/8',
		'unauth'            => '^/public/ ^/robots.txt$',
		'unauthcgi'         => '^/login.cgi$',
		'redirect'          => '/old=/new',
		'strip_prefix'      => '/virt',
		'deny'              => '9.9.9.9 8.8.8.8',
		'allow'             => '1.2.3.4',
		'allowusers'        => 'alice bob',
		'unixauth'          => 'admin=root *=apache',
		'sessiononly'       => '/api /webhooks',
		'logouttimes'       => 'alice=15 @wheel=60',
		'logouttime'        => 5,
		'davpaths'          => '/dav1 /dav2',
		'dav_users'         => 'eve',
		'mobile_agents'     => "Foo\tBar",
		'mobile_prefixes'   => 'XYZ ABC',
		'expires_paths'     => "\\.css\$=3600\t\\.js\$=86400",
		'alwaysresolve'     => 1,   # keep deny/allow as-is (no DNS)
		);

	# Reset every output global.
	local %miniserv::anonymous   = ();
	local %miniserv::ipaccess    = ();
	local @miniserv::unauth      = ();
	local @miniserv::unauthcgi   = ();
	local %miniserv::redirect    = ();
	local @miniserv::strip_prefix = ();
	local @miniserv::deny        = ();
	local @miniserv::allow       = ();
	local @miniserv::allowusers  = ();
	local @miniserv::denyusers   = ();
	local %miniserv::unixauth    = ();
	local %miniserv::sessiononly = ();
	local @miniserv::logouttimes = ();
	local @miniserv::davpaths    = ();
	local @miniserv::davusers    = ();
	local @miniserv::mobile_agents   = ();
	local @miniserv::mobile_prefixes = ();
	local @miniserv::expires_paths   = ();
	local %miniserv::sudocache       = ();
	local %miniserv::cert_names_cache = ();

	miniserv::build_config_mappings();

	is($miniserv::anonymous{'/pub'}, 'guest',         'anonymous map parsed');
	is($miniserv::ipaccess{'/admin'}, '10.0.0.0/8',   'ipaccess map parsed');
	is_deeply(\@miniserv::unauth,    ['^/public/', '^/robots.txt$'], 'unauth list parsed');
	is_deeply(\@miniserv::unauthcgi, ['^/login.cgi$'],                'unauthcgi list parsed');
	is($miniserv::redirect{'/old'},  '/new',                          'redirect map parsed');
	is_deeply(\@miniserv::strip_prefix, ['/virt'],                    'strip_prefix parsed');
	is_deeply(\@miniserv::allowusers,  ['alice', 'bob'],              'allowusers parsed');
	is(scalar @miniserv::denyusers, 0,
	   'denyusers stays empty when allowusers is set (mutually exclusive)');
	is($miniserv::unixauth{admin}, 'root',                            'specific unixauth parsed');
	is($miniserv::unixauth{'*'},   'apache',                          'default unixauth parsed');
	ok($miniserv::sessiononly{'/api'},                                'sessiononly entry set');
	is_deeply(\@miniserv::davpaths,    ['/dav1', '/dav2'],            'davpaths parsed');
	is_deeply(\@miniserv::davusers,    ['eve'],                       'davusers parsed');
	is_deeply(\@miniserv::mobile_agents, ['Foo', 'Bar'],
	          'mobile_agents tab-split');

	# logouttimes: configured rules + an always-match default appended.
	is(scalar @miniserv::logouttimes, 3, 'two configured + one default');
	is($miniserv::logouttimes[-1][0], undef, 'last entry is the default rule');
	is($miniserv::logouttimes[-1][1], 5,     'default uses logouttime');

	# expires_paths: each tab-separated entry becomes [regex, secs].
	is(scalar @miniserv::expires_paths, 2, 'two expires entries');
	is_deeply($miniserv::expires_paths[0], ['\.css$', '3600'],
	          'first expires entry split on =');
};

# lock_user_password — local-file branch rewrites the users file in place
subtest 'lock_user_password (local file)' => sub {
	no warnings qw(once redefine);
	require File::Temp;
	my ($fh, $path) = File::Temp::tempfile(UNLINK => 1);
	# Standard 5-field users line (user:pass:lastchange:certs:opts...).
	print $fh "alice:hashedpass:0::\n";
	print $fh "bob:bobhash:0::\n";
	close($fh);

	local %miniserv::config = ('userfile' => $path);
	local %miniserv::users  = (
		'alice' => 'hashedpass',
		'bob'   => 'bobhash',
		);
	# get_user_details would normally do %users → hashref; stub it.
	local *miniserv::get_user_details = sub {
		my ($u) = @_;
		return undef if !exists $miniserv::users{$u};
		return { 'name' => $u, 'pass' => $miniserv::users{$u} };
		};

	is(miniserv::lock_user_password('nobody'), -1,
	   'unknown user returns -1');

	is(miniserv::lock_user_password('alice'), 0, 'lock succeeds');
	is($miniserv::users{alice}, '!hashedpass',
	   'in-memory pass is prefixed with !');

	# File on disk reflects the change.
	open(my $rh, '<', $path) or die "reopen: $!";
	my $content = do { local $/; <$rh> };
	close($rh);
	like  ($content, qr/^alice:!hashedpass:/m,  'alice line rewritten with !');
	like  ($content, qr/^bob:bobhash:/m,        'bob line untouched');

	# Locking an already-locked user is a no-op (returns 0 but no double-!).
	is(miniserv::lock_user_password('alice'), 0,
	   'already-locked user → 0 (no-op)');
	is($miniserv::users{alice}, '!hashedpass',
	   'no double-bang prefix on second lock');
};

done_testing();
