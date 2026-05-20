#!/usr/bin/perl
# Unit tests for the pure string helpers in web-lib-funcs.pl.
#
# web-lib-funcs.pl is a pure library (no `unless(caller)` guard), so a bare
# `require` loads it without side effects. Helpers covered here touch no
# globals beyond their args, so no stubbing or %gconfig setup is needed.
#
# Assertions pin the current contract — encoded byte shape, round-trip
# identity, structural invariants — not the prettiest possible output.

use strict;
use warnings;
use Test::More;
use File::Basename qw(dirname);
use File::Spec;

my $script = File::Spec->rel2abs(
	File::Spec->catfile(dirname(__FILE__), '..', 'web-lib-funcs.pl'));
require $script;

# html_escape
#
# Always escapes &, <, >, ", ', =. The optional $nodblamp flag uses a
# lookahead so existing entity references survive untouched; without it,
# every & becomes &amp;, including already-escaped input.
subtest 'html_escape' => sub {
	is(main::html_escape('<b>&"\'='),
	   '&lt;b&gt;&amp;&quot;&#39;&#61;',
	   'all six dangerous characters are escaped');

	is(main::html_escape(undef), '', 'undef input → empty string');
	is(main::html_escape(''),    '', 'empty input → empty string');
	is(main::html_escape('plain text 123'), 'plain text 123',
	   'whitespace and alphanumerics pass through');

	# Default mode double-escapes existing entities — this is the current
	# contract; the nodblamp flag opts into the smarter behaviour.
	is(main::html_escape('&amp;'),    '&amp;amp;', 'default mode double-escapes &amp;');
	is(main::html_escape('&amp;', 1), '&amp;',     'nodblamp preserves existing &amp;');
	is(main::html_escape('&#65;', 1), '&#65;',     'nodblamp preserves numeric entity');
	# Note: nodblamp's lookahead matches any &<letters>; as an entity, so
	# made-up names like &x; are treated as entities and not re-escaped.
	is(main::html_escape('&x;',   1), '&x;',       'nodblamp preserves arbitrary &word; shape');
	is(main::html_escape('& ',    1), '&amp; ',   'nodblamp escapes lone &');

	# Adversarial XSS payload — none of the dangerous chars survive raw.
	my $xss = main::html_escape(q{<script>alert("x")</script>'=&});
	unlike($xss, qr/[<>"'=]/, 'no raw HTML-significant characters remain');
	unlike($xss, qr/&(?!(amp|lt|gt|quot|#39|#61);)/,
	       'every & starts a known entity');
};

# html_unescape — inverse of html_escape for the canonical entity set.
subtest 'html_unescape' => sub {
	is(main::html_unescape('&lt;b&gt;&amp;&quot;&#39;&#61;'),
	   '<b>&"\'=', 'canonical entity set round-trips');
	is(main::html_unescape('a&nbsp;b'), 'a b',
	   '&nbsp; decodes to a regular space');
	is(main::html_unescape(undef), '', 'undef → empty');
	is(main::html_unescape(''),    '', 'empty → empty');
	is(main::html_unescape('no entities here'), 'no entities here',
	   'plain text passes through unchanged');
};

# html_strip — remove tags, optionally replacing with a sentinel.
subtest 'html_strip' => sub {
	is(main::html_strip('<b>hello</b>'),         'hello',
	   'simple tags removed');
	is(main::html_strip('<a href="x">y</a>'),    'y',
	   'attribute-bearing tag removed');
	# Quoted attribute that contains a >, which would otherwise break a
	# naive regexp — the implementation accounts for this.
	is(main::html_strip('<a href=">">y</a>'),    'y',
	   'quoted > inside attribute does not end tag early');
	is(main::html_strip('plain text'),           'plain text',
	   'plain text untouched');
	is(main::html_strip('<b>x</b>', '|'),        '|x|',
	   'replacement string substituted for each tag');
};

# quote_escape — only ' and " (and lone &) are escaped; existing entities
# (&xxx; or &#NN;) are preserved.
subtest 'quote_escape' => sub {
	is(main::quote_escape(undef), '', 'undef → empty');

	is(main::quote_escape('a&b'),      'a&amp;b', 'lone & escaped');
	is(main::quote_escape('a&'),       'a&amp;',  'trailing & escaped');
	is(main::quote_escape('a&amp;b'),  'a&amp;b', 'existing &amp; preserved');
	is(main::quote_escape('a&#39;b'),  'a&#39;b', 'numeric entity preserved');

	is(main::quote_escape(q{a"b'c}),        'a&quot;b&#39;c',
	   'both quote styles escaped by default');
	is(main::quote_escape(q{a"b'c}, q{"}),  q{a&quot;b'c},
	   'only-quote="\"" escapes only double quotes');
	is(main::quote_escape(q{a"b'c}, q{'}),  q{a"b&#39;c},
	   'only-quote="\'" escapes only single quotes');
};

# quote_literal_escape — escape for inclusion in a Perl string literal.
subtest 'quote_literal_escape' => sub {
	is(main::quote_literal_escape(undef), '', 'undef → empty');
	is(main::quote_literal_escape(''),    '', 'empty → empty');

	# Default (single-quoted target): only \ and ' need escaping.
	is(main::quote_literal_escape(q{it's}),   q{it\'s},      'single quote escaped');
	is(main::quote_literal_escape(q{a\\b}),   q{a\\\\b},     'backslash doubled');
	is(main::quote_literal_escape(q{a"b$c@d}), q{a"b$c@d},
	   'double-quote / sigils NOT escaped in single-quoted target');

	# Double-quoted target: also escape ", $, @ (because they interpolate).
	is(main::quote_literal_escape(q{a"b$c@d}, q{"}),
	   q{a\"b\$c\@d},
	   '" $ @ all escaped in double-quoted target');
	is(main::quote_literal_escape(q{a\\b}, q{"}), q{a\\\\b},
	   'backslash doubled in double-quoted target too');
};

# quote_javascript — hex-escape the unsafe characters for a JS string literal.
subtest 'quote_javascript' => sub {
	is(main::quote_javascript(q{a"b}),  'a\x22b',  'double quote → \x22');
	is(main::quote_javascript(q{a'b}),  'a\x27b',  'single quote → \x27');
	is(main::quote_javascript('a<b>c'), 'a\x3cb\x3ec', '< and > escaped');
	is(main::quote_javascript('a&b'),   'a\x26b',  '& escaped');
	is(main::quote_javascript('a\\b'),  'a\x5cb',  'backslash escaped');
	is(main::quote_javascript('plain text 123'), 'plain text 123',
	   'safe characters pass through');
};

# urlize / un_urlize — percent-encoding round-trip.
subtest 'urlize / un_urlize' => sub {
	# urlize encodes anything that is not [A-Za-z0-9].
	is(main::urlize('abc123'),  'abc123',  'alphanumerics pass through');
	is(main::urlize(' '),       '%20',     'space encoded');
	is(main::urlize('/'),       '%2F',     'slash encoded');
	is(main::urlize("\n"),      '%0A',     'newline encoded');
	is(main::urlize(chr(0xff)), '%FF',     'high-bit byte encoded');
	is(main::urlize('a b/c'),   'a%20b%2Fc', 'mixed input');

	# un_urlize: by default, '+' becomes ' ' (form-encoded). Pass the
	# second arg true to preserve '+' literally.
	is(main::un_urlize('a+b'),    'a b', '+ decoded as space by default');
	is(main::un_urlize('a+b', 1), 'a+b', '+ preserved with plus-literal flag');
	is(main::un_urlize('%20'),    ' ',   '%20 decoded');
	is(main::un_urlize('%c3%a9'), "\xc3\xa9",
	   'lowercase hex decoded (UTF-8 bytes for é)');

	# Round-trip through a binary string.
	for my $s ('plain', 'a b/c', "binary\x00\x01\xff",
		   '<script>alert(1)</script>') {
		# urlize never emits +, so the no-plus mode is safe here.
		is(main::un_urlize(main::urlize($s), 1), $s,
		   "round-trip preserves ".length($s)." bytes");
		}
};

# trim — symmetric or asymmetric whitespace stripping.
#
# Second arg controls which end:
#   undef/0 → both
#       -1  → right only
#        1  → left only
subtest 'trim' => sub {
	is(main::trim('  hi  '),     'hi',     'both ends by default');
	is(main::trim('  hi  ', -1), '  hi',   '-1 strips trailing only');
	is(main::trim('  hi  ',  1), 'hi  ',   '1 strips leading only');
	is(main::trim('nochange'),   'nochange', 'no-op on tidy input');
	is(main::trim(''),           '',       'empty stays empty');
	is(main::trim("\t\nhi\r\n"), 'hi',     'tabs and newlines counted as whitespace');
};

# trunc — truncate to a "whole word" within a max length.
#
# The implementation cuts at maxlen, then pops one char unconditionally
# and continues popping only while the popped char is whitespace; trailing
# whitespace is then trimmed. This pins current behaviour, which has two
# notable edge cases worth flagging:
#
#   * `trunc("hello world foo", 11)` returns "hello worl", losing the
#     final 'd' even though substr(0, 11) cleanly ends on a word boundary.
#   * `trunc("hello world", 5)` returns "hell" rather than "hello".
#
# These pass today; a future fix to trunc will break these and prompt
# re-review.
subtest 'trunc' => sub {
	# Early-exit when input already fits.
	is(main::trunc('short',  99), 'short', 'no-op when input shorter than max');
	is(main::trunc('exact5',  6), 'exact5', 'no-op when input equals max');

	# Truncation lands at a partial word — pops the partial word back to
	# whitespace, then trims trailing whitespace.
	is(main::trunc('a b c',  4),  'a',      'cuts back through partial word');
	# substr(0,8) = "foo bar ", pop one (always), pop "r" — non-ws so stop.
	# Result: "foo ba" (last word "baz" partial → chopped one char short).
	is(main::trunc('foo bar baz', 8), 'foo ba',
	   'partial word loses one extra char (current behaviour)');

	# Edge case: substr cleanly ends on a word boundary. Current behaviour
	# still pops one char; pin it.
	is(main::trunc('hello world foo', 11), 'hello worl',
	   'always pops at least one char even at word boundary (current behaviour)');
	is(main::trunc('hello world',      5), 'hell',
	   'always pops at least one char (current behaviour)');

	# Truncating to 1 leaves nothing after the mandatory pop.
	is(main::trunc('abc', 1), '', 'maxlen=1 returns empty');
};

# indexof — first-index lookup with `eq`.
subtest 'indexof' => sub {
	is(main::indexof('b', 'a', 'b', 'c'),  1, 'returns 0-based index');
	is(main::indexof('a', 'a', 'b', 'c'),  0, 'first element');
	is(main::indexof('z', 'a', 'b', 'c'), -1, 'missing → -1');
	is(main::indexof('a'),                -1, 'empty haystack → -1');
	is(main::indexof('b', 'a', 'b', 'b'),  1, 'duplicates: first hit wins');
	# Numeric needle compared stringwise (eq).
	is(main::indexof(1, '0', '1', '2'),    1, 'numeric needle matches stringwise');
};

# indexoflc — case-insensitive variant.
subtest 'indexoflc' => sub {
	is(main::indexoflc('B', 'a', 'b', 'c'),  1, 'uppercase needle, lowercase haystack');
	is(main::indexoflc('a', 'A', 'B', 'C'),  0, 'lowercase needle, uppercase haystack');
	is(main::indexoflc('z', 'a', 'b', 'c'), -1, 'missing → -1');
};

# uniquelc — dedupe by lowercase comparison, preserving first-seen case.
subtest 'uniquelc' => sub {
	is_deeply([main::uniquelc('Foo', 'foo', 'FOO', 'Bar')],
		  ['Foo', 'Bar'],
		  'first-seen case preserved, later case-variants dropped');
	is_deeply([main::uniquelc()], [], 'empty input → empty list');
	is_deeply([main::uniquelc('x')], ['x'], 'single element passes through');
};

done_testing();
