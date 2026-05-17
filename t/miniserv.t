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

subtest 'check_ip6address' => sub {
	ok( miniserv::check_ip6address('::1'),                  'loopback accepted');
	ok( miniserv::check_ip6address('2001:db8::1'),          'compressed form accepted');
	ok( miniserv::check_ip6address('1:2:3:4:5:6:7:8'),      'full form accepted');
	ok(!miniserv::check_ip6address('not an addr'),          'garbage rejected');
	ok(!miniserv::check_ip6address('1:2:3:4:5:6:7:8:9'),    'too many groups rejected');
	ok(!miniserv::check_ip6address('gggg::1'),              'non-hex rejected');
};

# canonicalize_ip6 / expand_ipv6_bytes
subtest 'canonicalize_ip6' => sub {
	my $c = miniserv::canonicalize_ip6('::1');
	is($c, '0000:0000:0000:0000:0000:0000:0000:0001',
	   '::1 expands to 8 zero-padded groups');

	my $c2 = miniserv::canonicalize_ip6('2001:DB8::1');
	is($c2, '2001:0db8:0000:0000:0000:0000:0000:0001',
	   '2001:DB8::1 lower-cased and zero-expanded');

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

done_testing();
