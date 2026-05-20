#!/usr/bin/perl
# Unit tests for path / URL / shell-quote helpers in web-lib-funcs.pl.
#
# Bare `require` loads the library; subs covered here either touch no
# globals or use ones we set up locally ($gconfig{os_type} for quote_path,
# %month_to_number_map / %number_to_month_map for the month helpers).
# In production those maps are populated by web-lib.pl; we set them by hand
# to keep tests independent of that initialiser.

use strict;
use warnings;
use Test::More;
use File::Basename qw(dirname);
use File::Spec;

my $script = File::Spec->rel2abs(
	File::Spec->catfile(dirname(__FILE__), '..', 'web-lib-funcs.pl'));
require $script;

# simplify_path — strip ./ and resolve ../, refusing to escape root.
#
# Contract:
#   - returns an absolute path (always leading "/")
#   - returns undef when .. would pop above the root
#   - "." and "" inputs both return "/"
#   - a relative input ("foo") is promoted to "/foo"
#
# This is the web-lib-funcs version; miniserv.pl ships an independent
# implementation (`miniserv::simplify_path`) with a different signature
# (bogus-flag via aliased arg). Both are exercised by their own tests.
subtest 'simplify_path' => sub {
	is(main::simplify_path('/foo/bar'),     '/foo/bar', 'plain path');
	is(main::simplify_path('/foo/./bar'),   '/foo/bar', '. collapses');
	is(main::simplify_path('/foo/../bar'),  '/bar',     '.. pops');
	is(main::simplify_path('/a/b/c/../../d'), '/a/d',
	   'multiple .. pop the right number of segments');
	is(main::simplify_path('//foo///bar//'), '/foo/bar', 'repeated slashes collapse');
	is(main::simplify_path('/foo/'),         '/foo',    'trailing slash dropped');

	# Adversarial: escaping root must fail closed.
	is(main::simplify_path('/../etc/passwd'), undef, '.. above root → undef');
	is(main::simplify_path('/foo/../../bar'), undef, 'overshoot → undef');

	# Surprising-but-current behaviour: empty / root / relative inputs.
	is(main::simplify_path(''),    '/',    'empty input → /');
	is(main::simplify_path('/'),   '/',    'root passes through');
	is(main::simplify_path('foo'), '/foo', 'relative input is promoted to absolute');
};

# parse_http_url — absolute and base-relative URL parsing.
#
# Contract on success: returns (host, port, page, ssl, [user], [pass]).
# SSL mode 0=http, 1=https, 2=ftp.
subtest 'parse_http_url' => sub {
	my @abs = main::parse_http_url('http://example.com/foo');
	is_deeply([@abs[0..3]], ['example.com', 80, '/foo', 0],
		  'plain http URL');

	my @https = main::parse_http_url('https://example.com:8443/bar');
	is_deeply([@https[0..3]], ['example.com', 8443, '/bar', 1],
		  'https with explicit port and ssl=1');

	my @ftp = main::parse_http_url('ftp://host/x');
	is_deeply([@ftp[0..3]], ['host', 21, '/x', 2],
		  'ftp scheme → port 21 and ssl=2');

	# Userinfo is captured as elements 4 and 5.
	my @auth = main::parse_http_url('http://user:pass@example.com:81/foo');
	is_deeply(\@auth, ['example.com', 81, '/foo', 0, 'user', 'pass'],
		  'user:pass extracted from authority');

	# Bracketed IPv6 host.
	my @v6 = main::parse_http_url('http://[2001:db8::1]:8080/foo');
	is_deeply([@v6[0..3]], ['2001:db8::1', 8080, '/foo', 0],
		  'bracketed IPv6 host parsed, brackets stripped');

	# Missing path defaults to "/".
	my @noslash = main::parse_http_url('http://example.com');
	is($noslash[2], '/', 'missing path defaults to /');

	# no_default_port suppresses 80/443/21 substitution.
	my @nd = main::parse_http_url('http://example.com/x', undef, undef,
				     undef, undef, undef, undef, 1);
	is($nd[1], undef, 'no_default_port leaves port undef');

	# Relative URL with a base.
	my @rs = main::parse_http_url('/page', 'host', 80, '/old/', 0);
	is_deeply([@rs[0..3]], ['host', 80, '/page', 0],
		  'server-absolute relative URL uses base host/port');

	my @rd = main::parse_http_url('rel.html', 'host', 80, '/base/cur.html', 0);
	is_deeply([@rd[0..3]], ['host', 80, '/base/rel.html', 0],
		  'directory-relative URL resolves against base page directory');

	# Unparseable input with no base → undef.
	is(main::parse_http_url('not a url'), undef,
	   'garbage with no base → undef');
};

# split_quoted_string — shell-ish tokenizer.
#
# Each iteration matches one of:
#   "..." | '...' | \S+
# followed by trailing whitespace, then loops on the remainder.
subtest 'split_quoted_string' => sub {
	is_deeply([main::split_quoted_string('one two three')],
		  ['one', 'two', 'three'],
		  'bare words');

	is_deeply([main::split_quoted_string('"hello world" foo "bar baz" qux')],
		  ['hello world', 'foo', 'bar baz', 'qux'],
		  'double-quoted segments preserve internal spaces');

	is_deeply([main::split_quoted_string(q{'a b' c 'd e'})],
		  ['a b', 'c', 'd e'],
		  'single-quoted segments work the same way');

	is_deeply([main::split_quoted_string('')], [],
		  'empty input → empty list');

	# Unbalanced quote: the implementation falls through to the \S+
	# branch and emits the leftover with the quote attached. Pin this.
	is_deeply([main::split_quoted_string('unbalanced "quote')],
		  ['unbalanced', '"quote'],
		  'unterminated quote is taken as a bare token');

	# Pure-whitespace input drops everything because no branch tolerates
	# a leading-whitespace prefix. Surface this as current behaviour —
	# arguably a bug, but documenting it here protects us from a silent
	# behaviour change.
	is_deeply([main::split_quoted_string('   spaces   between   ')], [],
		  'leading whitespace short-circuits the tokenizer (current behaviour)');
};

# quote_path — OS-dependent shell quoting.
#
# On Windows or for Windows-style absolute paths, wraps in double quotes.
# Everywhere else, uses quotemeta (which escapes every non-word char).
subtest 'quote_path' => sub {
	no warnings 'once';
	local %main::gconfig = ('os_type' => 'linux');

	# quotemeta escapes /, space, etc.
	is(main::quote_path('/a b/c'), '\\/a\\ b\\/c',
	   'unix path uses quotemeta');
	is(main::quote_path('plain'),  'plain',
	   'all-word characters need no escaping');

	# Windows-style path → "" wrapping, even when os_type isn't windows.
	is(main::quote_path('c:/Users/x'), '"c:/Users/x"',
	   'drive-letter prefix wraps in double quotes');

	# os_type=windows forces double-quote wrap.
	local %main::gconfig = ('os_type' => 'windows');
	is(main::quote_path('/etc/passwd'), '"/etc/passwd"',
	   'os_type=windows wraps in double quotes regardless of path shape');
};

# month_to_number / number_to_month — three-letter month name <-> 0-based index.
#
# In production these maps are populated by web-lib.pl; in tests we set
# them up locally so the suite doesn't depend on web-lib.pl loading.
subtest 'month_to_number / number_to_month' => sub {
	no warnings 'once';
	local %main::month_to_number_map = (
		'jan' => 0,  'feb' => 1,  'mar' => 2,  'apr' => 3,
		'may' => 4,  'jun' => 5,  'jul' => 6,  'aug' => 7,
		'sep' => 8,  'oct' => 9,  'nov' => 10, 'dec' => 11,
		);
	local %main::number_to_month_map = reverse %main::month_to_number_map;

	is(main::month_to_number('Jan'),     0,  'Jan → 0');
	is(main::month_to_number('December'), 11, 'first three chars taken');
	is(main::month_to_number('FEB'),     1,  'case-insensitive');
	is(main::month_to_number('xyz'),     undef, 'unknown returns undef');

	is(main::number_to_month(0),  'Jan', '0 → Jan (ucfirst applied)');
	is(main::number_to_month(11), 'Dec', '11 → Dec');

	# Round-trip every month.
	for my $m (qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)) {
		is(main::number_to_month(main::month_to_number($m)), $m,
		   "round-trip $m");
		}
};

done_testing();
