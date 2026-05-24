#!/usr/bin/perl
# Unit tests for the encoding / serialization helpers in web-lib-funcs.pl:
# base64, base32, serialise_variable / unserialise_variable, JSON wrappers.
#
# Pure transforms — no globals beyond MIME::Base64 / JSON::* probes done by
# the subs themselves. A bare `require` is enough.

use strict;
use warnings;
use Test::More;
use File::Basename qw(dirname);
use File::Spec;

my $script = File::Spec->rel2abs(
	File::Spec->catfile(dirname(__FILE__), '..', 'web-lib-funcs.pl'));
require $script;

# encode_base64 / decode_base64
#
# Two implementations live behind these wrappers — MIME::Base64 if it loads,
# otherwise a pack/unpack pure-Perl fallback. We test the contract both
# share: RFC 4648 vectors, round-trip identity, and the optional "noeol"
# flag suppressing trailing newlines.
subtest 'encode_base64 / decode_base64' => sub {
	# RFC 4648 §10 test vectors.
	my %vec = (
		''       => '',
		'f'      => 'Zg==',
		'fo'     => 'Zm8=',
		'foo'    => 'Zm9v',
		'foob'   => 'Zm9vYg==',
		'fooba'  => 'Zm9vYmE=',
		'foobar' => 'Zm9vYmFy',
		);
	for my $in (sort keys %vec) {
		is(main::encode_base64($in, 'noeol'), $vec{$in},
		   "RFC vector: '$in'");
		is(main::decode_base64($vec{$in}), $in,
		   "RFC vector decode: '$vec{$in}'");
		}

	# Default mode appends a newline; noeol suppresses it.
	like(main::encode_base64('hello'),         qr/\n\z/, 'default mode ends in newline');
	unlike(main::encode_base64('hello', 'noeol'), qr/\n/, 'noeol omits newline');

	# Round-trip a wide byte-range, including embedded NULs.
	my $bin = join('', map { chr } 0..255);
	is(main::decode_base64(main::encode_base64($bin, 'noeol')), $bin,
	   'round-trips all 256 byte values');

	# Decoder tolerates embedded whitespace in the encoded form (MIME::Base64
	# behaviour; the fallback uses uudecode under the hood and is similarly
	# tolerant after the tr/cd strip).
	is(main::decode_base64("aGVs\nbG8="), 'hello',
	   'embedded newline in encoded input tolerated');
};

# encode_base32 / decode_base32
#
# Pure-Perl implementation. RFC 4648 §10 specifies "=" padding on
# unaligned outputs; this encoder omits padding. Pinning that as the
# current contract — decoder accepts both forms so round-trips are safe.
subtest 'encode_base32 / decode_base32' => sub {
	# Round-trip the RFC 4648 §10 vectors.
	for my $in ('', 'f', 'fo', 'foo', 'foob', 'fooba', 'foobar') {
		is(main::decode_base32(main::encode_base32($in)), $in,
		   "round-trip '$in'");
		}

	# Encoder emits the RFC alphabet (uppercase A-Z and digits 2-7).
	# Output should never contain "=" (padding is dropped).
	like(main::encode_base32('foobar'), qr/\A[A-Z2-7]*\z/,
	     'encoded output uses only the RFC 4648 alphabet');
	unlike(main::encode_base32('f'), qr/=/,
	       'encoder omits "=" padding (note: deviation from RFC 4648)');

	# Decoder also accepts canonical padded input (RFC 4648 mandates "="
	# padding on unaligned outputs). The encoder still omits padding, so
	# this matters mainly for externally-produced base32 strings.
	is(main::decode_base32('MY======'), 'f',    'padded "MY======" decodes');
	is(main::decode_base32('MZXQ===='), 'fo',   'padded "MZXQ====" decodes');
	is(main::decode_base32('MZXW6==='), 'foo',  'padded "MZXW6===" decodes');
	is(main::decode_base32('MZXW6YQ='), 'foob', 'padded "MZXW6YQ=" decodes');

	# Case-insensitive decode — Webmin's TOTP path accepts secrets
	# case-insensitively (twofactor-funcs-lib.pl validates with /i),
	# so lowercase input from third-party authenticators must decode
	# identically to uppercase.
	is(main::decode_base32('mzxw6ytboi'),       'foobar',
	   'lowercase decodes identically to uppercase');
	is(main::decode_base32('MzXw6YtBoI'),       'foobar',
	   'mixed-case decodes identically');
	is(main::decode_base32('mzxw6yq='),         'foob',
	   'lowercase with padding decodes correctly');

	# Empty input → empty output, both directions.
	is(main::encode_base32(''), '', 'empty encode → empty');
	is(main::decode_base32(''), '', 'empty decode → empty');
};

# serialise_variable / unserialise_variable
#
# Webmin's own serialization (used by remote_eval and friends). Format:
# TYPE,urlized-payload where nested collections re-encode through urlize
# at each level — so nested structures gain layers of %25 escaping.
subtest 'serialise_variable / unserialise_variable' => sub {
	# Scalars round-trip byte-for-byte.
	for my $s ('hello', '', 'a,b,c', 'a=b&c', "\x00\xff", "spaces here") {
		is(main::unserialise_variable(main::serialise_variable($s)), $s,
		   "scalar round-trip: '$s'");
		}

	# undef has a dedicated marker.
	is(main::serialise_variable(undef), 'UNDEF', 'undef serializes to "UNDEF"');
	is(main::unserialise_variable('UNDEF'), undef, '"UNDEF" deserializes to undef');

	# Refs.
	my $scalar_ref = \'inner';
	is_deeply(main::unserialise_variable(main::serialise_variable($scalar_ref)),
		  $scalar_ref, 'scalar ref round-trips');

	# Arrays — note numeric values come back as strings (Perl scalar stringification).
	is_deeply(main::unserialise_variable(main::serialise_variable([1,2,3])),
		  ['1','2','3'], 'array of numbers round-trips (as strings)');
	is_deeply(main::unserialise_variable(main::serialise_variable(['a','b','c'])),
		  ['a','b','c'], 'array of strings round-trips');
	is_deeply(main::unserialise_variable(main::serialise_variable([])),
		  [], 'empty array round-trips');

	# Hashes.
	is_deeply(main::unserialise_variable(main::serialise_variable({a=>'x', b=>'y'})),
		  {a=>'x', b=>'y'}, 'flat hash round-trips');
	is_deeply(main::unserialise_variable(main::serialise_variable({})),
		  {}, 'empty hash round-trips');

	# Nested — array-of-arrays and hash-of-hashes survive the recursive
	# urlize wrapping (each level adds %25 to existing %s).
	is_deeply(main::unserialise_variable(main::serialise_variable([[1,2],[3,4]])),
		  [['1','2'],['3','4']], 'nested array round-trips');
	is_deeply(main::unserialise_variable(
		main::serialise_variable({outer=>{inner=>['x','y']}})),
		{outer=>{inner=>['x','y']}}, 'nested hash round-trips');

	# Wire-format spot checks — pin the documented format so callers that
	# rely on it (remote_eval) don't silently change shape.
	is(main::serialise_variable('hi'),   'VAL,hi',  'scalar wire format');
	is(main::serialise_variable('a,b'),  'VAL,a%2Cb', 'comma in scalar urlized');
	is(main::serialise_variable([1,2]),  'ARRAY,VAL%2C1,VAL%2C2',
	   'array wire format (one level of urlize wrapping)');

	# Data::Dumper path — opt-in via the second arg.
	my $d = main::serialise_variable({k=>'v'}, 1);
	like($d, qr/^\$VAR1\s*=/, 'dumper mode emits Data::Dumper format');
	is_deeply(main::unserialise_variable($d), {k=>'v'},
	   'dumper-format round-trips through the $VAR1 detector');
};

# convert_to_json / convert_from_json
#
# Thin wrappers over JSON::XS or JSON::PP. We test the wrapper contract —
# the defaults, the pretty flag, the raw-utf8 flag, the undef-defaulting,
# and the relaxed parser — not JSON conformance, which is the library's job.
subtest 'convert_to_json / convert_from_json' => sub {
	# Plain round-trip preserves structure (not key order).
	my $in = {name=>'x', items=>[1,2,3], nested=>{k=>'v'}};
	is_deeply(main::convert_from_json(main::convert_to_json($in)), $in,
		  'round-trips a mixed structure');

	# Pretty output is human-formatted (multi-line, indented).
	my $pretty = main::convert_to_json({a=>1,b=>2}, 1);
	like($pretty, qr/\n/, 'pretty mode produces multi-line output');
	# And still round-trips.
	is_deeply(main::convert_from_json($pretty), {a=>1,b=>2},
		  'pretty output still parses');

	# Current contract: undef input becomes {} (the `||= {}` default).
	is(main::convert_to_json(undef), '{}', 'undef input → "{}"');

	# Arrays at the top level work too.
	is(main::convert_to_json([1,2,3]), '[1,2,3]', 'top-level array encodes');
	is_deeply(main::convert_from_json('[1,2,3]'), [1,2,3], 'top-level array decodes');

	# Relaxed mode accepts comments and trailing commas (JSON::PP feature).
	my $rx = main::convert_from_json('{"a":1, /* note */ "b":2,}', 0, 1);
	is_deeply($rx, {a=>1,b=>2}, 'relaxed parser accepts /* comments */ and trailing comma');
};

done_testing();
