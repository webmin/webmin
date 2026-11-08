#!/usr/bin/perl
# Unit tests for the encoding / serialization helpers in web-lib-funcs.pl:
# base64, base32, serialise_variable / unserialise_variable, JSON wrappers.
#
# Pure transforms — no globals beyond MIME::Base64 / JSON::* probes done by
# the subs themselves. A bare `require` is enough.

use strict;
use warnings;
use Test::More;
use FindBin qw($Bin);
use lib "$Bin/../vendor_perl";
use File::Basename qw(dirname);
use File::Spec;
use Scalar::Util ();

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

	# Enable Data::Dumper format with the optional second argument.
	my $d = main::serialise_variable({k=>'v'}, 1);
	like($d, qr/^\$VAR1 = /, 'Data::Dumper mode emits an assignment');
	is_deeply(main::unserialise_variable($d), {k=>'v'},
	   'Data::Dumper format round-trips');

	# Remote object names must not load or bless local classes.
	my $object = main::unserialise_variable(
		'OBJECT RPC::Untrusted,VAL%2Ck,VAL%2Cv');
	is_deeply($object, {k=>'v'}, 'object data is retained');
	is(ref($object), 'HASH', 'object data is not blessed');
};

# Data::Dumper format
#
# Fast RPC uses Data::Dumper for serialization. unserialise_variable() parses
# it as data instead of calling eval. Supported forms must preserve shared and
# cyclic references, and input must never execute code.
subtest 'Data::Dumper format' => sub {
	require Data::Dumper;
	require JSON::PP;

	# Newer peers emit native booleans as !!1 and !!0, including RPC results.
	for my $value (0, 1) {
		is(main::unserialise_variable("\$VAR1 = !!$value;"), !!$value,
		   "literal !!$value retains Perl boolean semantics");
		is_deeply(main::unserialise_variable(
			"\$VAR1 = {'rv' => !!$value, 'status' => 1};"),
			{ 'rv' => !!$value, 'status' => 1 },
			"fast RPC response accepts !!$value");
		}
	is_deeply(main::unserialise_variable(q{$VAR1 = [!!1, !!0, \!!0];}),
		[ !!1, !!0, \!!0 ], 'booleans work in arrays and scalar references');
	is_deeply(main::unserialise_variable(q{$VAR1 = ['!!1', "!!0"];}),
		[ '!!1', '!!0' ], 'quoted boolean text remains unchanged');

	# Spot-check the supported scalar, reference, object and container forms.
	my $str = 'x';
	my $shared = [ 1 ];
	my $v = { 'int' => 42, 'neg' => -7, 'float' => 1.5, 'undef' => undef,
		  'quote' => "it's \\ ok", 'utf8' => "caf\x{e9} \x{263a}",
		  'bin' => join('', map { chr } 0..255), 'nl' => "a\nb",
		  'sref' => \$str, 'rref' => \\'y', 'a' => $shared, 'b' => $shared,
		  'obj' => bless({ 'x' => 1 }, 'RPC::Untrusted'),
		  'sobj' => bless(\$str, 'RPC::Untrusted'),
		  'empty' => [], 'eh' => {}, 'true' => !!1, 'false' => !!0 };
	$v->{'self'} = $v;
	# Data::Dumper cannot preserve a reference to a hash value if it sees that
	# reference first. Sorting keys makes this test deterministic.
	$v->{'slot'} = \$v->{'quote'};
	for my $opts ([ 'compact', 0, 0, 0 ], [ 'indented', 2, 0, 0 ],
		      [ 'useqq', 1, 1, 0 ], [ 'pure Perl', 2, 0, 1 ]) {
		my ($name, $indent, $useqq, $useperl) = @$opts;
		my $dd = Data::Dumper->new([ $v ], [ 'VAR1' ]);
		$dd->Purity(1)->Indent($indent)->Useqq($useqq)->Useperl($useperl)
		   ->Sortkeys(1);
		my $got = main::unserialise_variable($dd->Dump());
		ok(same_graph($got, $v), "$name output preserves data and links");
		is($got->{'self'}, $got, "$name cyclic reference is restored");
		is($got->{'a'}, $got->{'b'}, "$name shared reference is restored");
		is($got->{'slot'}, \$got->{'quote'}, "$name slot reference is restored");
		is(ref($got->{'obj'}), 'HASH', "$name object is not blessed");
		is(ref($got->{'sobj'}), 'SCALAR', "$name scalar object is not blessed");
		# Match eval's number-versus-string behavior.
		is(JSON::PP->new->encode([ $got->{'int'}, $got->{'float'} ]),
		   '[42,"1.5"]', "$name preserves number and string types");
		}
	delete($v->{'slot'});

	# Convert executable and runtime-only values to inert data.
	my $odd = main::unserialise_variable(
		q{$VAR1 = [sub { "DUMMY" },*::STDOUT,\*{'::odd name'},qr/a\/b/i,do{my $o}];});
	is_deeply($odd, [ undef, undef, \undef, '(?^i:a\/b)', undef ],
		  'code refs, globs and regexps are not recreated');

	# Ignore global options to keep the wire format stable.
	{
		no warnings 'once';
		local $Data::Dumper::Indent = 2;
		local $Data::Dumper::Terse = 1;
		local $Data::Dumper::Useqq = 1;
		local $Data::Dumper::Deparse = 1;
		local $Data::Dumper::Varname = 'X';
		local $Data::Dumper::Purity = 0;
		local $Data::Dumper::Pad = 'BAD';
		my $out = main::serialise_variable($v, 1);
		like($out, qr/^\$VAR1 = \{'/, 'sender ignores global Dumper options');
		ok(same_graph(main::unserialise_variable($out), $v),
		   'sender output round-trips with links');
		local $SIG{'__WARN__'} = sub { };
		my $code = main::serialise_variable({ 'c' => sub { 1 } }, 1);
		like($code, qr/sub \{ "DUMMY" \}/, 'sender never deparses code');
	}

	# Compare supported option combinations with trusted eval output.
	srand(2886);
	my ($count, @fail) = (0);
	for my $round (1..400) {
		my $data = random_graph();
		for my $indent (0, 1, 2) {
			for my $useqq (0, 1) {
				for my $useperl (0, 1) {
					my $dd = Data::Dumper->new([ $data ], [ 'VAR1' ]);
					$dd->Purity(1)->Indent($indent)->Useqq($useqq)
					   ->Useperl($useperl)->Quotekeys($round % 2)
					   ->Sortkeys(1);
					# Include trailing commas when indented output supports them.
					$dd->Trailingcomma(1)
						if ($indent && $dd->can('Trailingcomma'));
					my $dump = $dd->Dump();
					my ($want, $err) = eval_dumper($dump);
					next if ($err);
					$count++;
					my $got = main::unserialise_variable($dump);
					push(@fail, $dump) if (!same_graph($got, $want));
					}
				}
			}
		}
	ok($count > 2000, "compared $count random dumps with eval");
	is(scalar(@fail), 0, 'parser matches eval for every random dump')
		|| diag("first mismatch:\n$fail[0]");

	# Reject hostile input without executing it.
	our $ran = 0;
	my @hostile = (
		q{$VAR1 = !!2;},
		q{$VAR1 = !!10;},
		q{$VAR1 = !!01;},
		q{$VAR1 = !!1e0;},
		q{$VAR1 = !!0.0;},
		q{$VAR1 = !!1foo;},
		q{$VAR1 = !!($main::ran = 1);},
		q{$VAR1 = !!0 || do { $main::ran = 1 };},
		q{$VAR1 = !!1; $main::ran = 1;},
		q{$VAR1 = {}; $main::ran = 1;},
		q{$VAR1 = "@{[ $main::ran = 1 ]}";},
		q{$VAR1 = "${\ ($main::ran = 1)}";},
		q{$VAR1 = do { $main::ran = 1 };},
		q{$VAR1 = sub { $main::ran = 1 };},
		q{$VAR1 = [ 1 ]; $VAR1->[0] = $main::ran;},
		q{$VAR1 = [ 1 ]; $VAR1->[0] = &main::ran();},
		q{$VAR1 = [ 1 ]; ${\ ($main::ran = 1)} = 1;},
		q{$VAR1 = [ 1 ]; $VAR1->[5] = $VAR1;},
		q{$VAR1 = {}; $VAR1->{'a'} = $VAR1;},
		q{$VAR1 = { 'a' => 1 }; $VAR1->{'a'} = $VAR1->{'b'};},
		q{$VAR1 = { 'a' => 1 }; $VAR1->{'a'} = ${$VAR1->{'a'}};},
		q{$VAR1 = { 'a' => 'main::ran' }; ${$VAR1->{'a'}} = $VAR1;},
		q{$VAR1 = [ 1 ]; $VAR1->[0] = 1;},
		q{$VAR1 = { 'a' => 1 }; $VAR1{'a'} = $VAR1;},
		q{$VAR1 = 'a' . system('true');},
		q{$VAR1 = {}; BEGIN { $main::ran = 1 }},
		q{$VAR1 = \&main::ran;},
		q{$VAR1 = "\N{U+263A}";},
		q{$VAR1 = "\u\LX";},
		q{$VAR1 = bless( {}, 'X' )->new;},
		q{$VAR1 = {} or $main::ran = 1;},
		'$VAR1 = '.('[' x 5000).(']' x 5000).';',
		q{$VAR1 = 'unterminated;},
		);
	for my $h (@hostile) {
		is(main::unserialise_variable($h), undef,
		   'refused: '.substr($h, 0, 50));
		}
	my $re = main::unserialise_variable(q{$VAR1 = qr/(?{ $main::ran = 1 })/;});
	is(ref($re), '', 'regexp with code is returned as a plain string');
	my $obj = main::unserialise_variable(
		q{$VAR1 = bless( {'REALNAME' => '/nonexistent','CLEANUP' => 1}, 'File::Temp::Dir' );});
	is(ref($obj), 'HASH', 'object with a DESTROY method is not blessed');
	is($ran, 0, 'no hostile input was executed');
};

# eval_dumper(string)
# Evaluates trusted, test-generated output for comparison with the old RPC
# decoder. Returns the value and any error. Never pass external input.
sub eval_dumper
{
	my ($dump) = @_;
	no strict;
	no warnings;
	my $VAR1;
	eval $dump;
	return ($VAR1, $@);
}

# same_graph(a, b, [&seen])
# Compares values and reference identities, including shared slots and cycles.
# Objects compare by their underlying type because the parser does not bless.
sub same_graph
{
	my ($x, $y, $seen) = @_;
	$seen ||= {};

	# Compare terminal values before tracking reference identities.
	return !defined($y) if (!defined($x));
	return 0 if (!defined($y));
	my ($tx, $ty) = (Scalar::Util::reftype($x) || '',
			 Scalar::Util::reftype($y) || '');
	return 0 if ($tx ne $ty);
	return $x eq $y if ($tx eq '');
	my ($ax, $ay) = (Scalar::Util::refaddr($x), Scalar::Util::refaddr($y));
	if (exists($seen->{"x$ax"}) || exists($seen->{"y$ay"})) {
		# A repeated reference must point to the matching value in both graphs.
		return ($seen->{"x$ax"} || 0) == $ay && ($seen->{"y$ay"} || 0) == $ax;
	}
	$seen->{"x$ax"} = $ay;
	$seen->{"y$ay"} = $ax;
	if ($tx eq 'HASH') {
		# Compare slots so references to hash values must also match.
		my @kx = sort keys %$x;
		return 0 if (join("\0", @kx) ne join("\0", sort keys %$y));
		for my $k (@kx) {
			return 0 if (!same_graph(\$x->{$k}, \$y->{$k}, $seen));
		}
		return 1;
	}
	elsif ($tx eq 'ARRAY') {
		# Compare slots so references to array elements must also match.
		return 0 if (@$x != @$y);
		for my $i (0..$#$x) {
			return 0 if (!same_graph(\$x->[$i], \$y->[$i], $seen));
		}
		return 1;
	}
	elsif ($tx eq 'SCALAR' || $tx eq 'REF') {
		return same_graph($$x, $$y, $seen);
	}
	return 1;
}

# random_graph()
# Builds nested data with edge-case strings, shared references, cycles,
# references to elements and objects.
sub random_graph
{
	my @pool;
	my $root = random_value(\@pool, 0);
	return $root if (!@pool);
	for (1..int(rand(5))) {
		my $from = $pool[int(rand(@pool))];
		my $to = $pool[int(rand(@pool))];
		my $link = $to;
		my $r = rand();
		if ($r < 0.2) {
			$link = \$to;
		}
		elsif ($r < 0.4 && ref($to) eq 'HASH' && %$to) {
			$link = \$to->{(sort keys %$to)[0]};
		}
		elsif ($r < 0.5 && ref($to) eq 'ARRAY' && @$to) {
			$link = \$to->[0];
		}
		elsif ($r < 0.6) {
			$link = bless([ $to ], 'RPC::Untrusted');
		}
		my $type = Scalar::Util::reftype($from);
		if ($type eq 'HASH') {
			$from->{'link'.int(rand(3))} = $link;
		}
		elsif ($type eq 'ARRAY') {
			push(@$from, $link);
		}
		else {
			$$from = $link;
		}
	}
	return $root;
}

# random_value(&pool, depth)
# Returns a random scalar or container and adds containers to the pool.
sub random_value
{
	my ($pool, $depth) = @_;
	my $r = rand();
	my $v;
	if ($depth > 3 || $r < 0.35) {
		# Bound recursion and make scalar leaves common.
		return random_string();
	}
	elsif ($r < 0.6) {
		$v = [ map { random_value($pool, $depth+1) } 1..int(rand(4)) ];
	}
	elsif ($r < 0.85) {
		$v = { map { (random_string() // 'u' => random_value($pool, $depth+1)) }
			   1..int(rand(4)) };
	}
	elsif ($r < 0.95) {
		my $inner = random_value($pool, $depth+1);
		$v = \$inner;
	}
	else {
		$v = bless({ 'x' => random_value($pool, $depth+1) },
			   'RPC::Untrusted');
	}
	push(@$pool, $v);
	return $v;
}

# random_string()
# Returns a hard-to-quote scalar containing bytes, Unicode, quotes, sigils,
# numbers or number-like strings.
sub random_string
{
	my @fixed = ('', 'plain', "it's", 'back\\slash', '$x @y', "a\nb",
		     '007', '1.5', '-0', '12345678901', 42, -7, 0, undef,
		     "\x{263a}\x{1f600}", "caf\x{e9}", "\0\x7f\x80\xff");

	# Usually choose a fixed edge case so every run covers common forms.
	return $fixed[int(rand(@fixed))] if (rand() < 0.7);

	# Otherwise generate arbitrary byte or Unicode content.
	return join('', map { chr(rand() < 0.1 ? int(rand(0x3000)) : int(rand(256))) }
			     1..int(rand(20)));
}

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

	# Sorting is independent of whitespace, with the same contract in both engines.
	for my $engine ('JSON::PP', 'JSON::XS') {
		subtest "$engine canonical output" => sub {
			eval "require $engine; 1" or plan skip_all => "$engine is not installed";
			# Force the supported PP fallback even when XS is installed.
			local $INC{'JSON/XS.pm'} = $engine eq 'JSON::PP' ? undef : $INC{'JSON/XS.pm'};
			my $data = {z => 2, a => {z => 1, a => 0}};
			is(main::convert_to_json($data, 0, 1, 1),
				'{"a":{"a":0,"z":1},"z":2}', 'compact output sorts nested keys');
			is(main::convert_to_json($data, 1),
				$engine->new->pretty->canonical->latin1->encode($data),
				'existing pretty calls retain sorted output');
			is(main::convert_to_json($data, 1, 0, 0),
				$engine->new->pretty->latin1->encode($data),
				'explicit false disables sorting independently of pretty printing');
			is(main::convert_to_json($data, 0, 0, undef),
				$engine->new->latin1->encode($data),
				'undefined canonical flag retains the default');
			# JSON syntax and byte encoding must remain independent of sorting.
			my $unicode = {label => "Caf\x{e9} \x{65e5}\x{672c} \x{1f642}"};
			my $bytes = main::convert_to_json($unicode, 0, 1, 1);
			ok(!utf8::is_utf8($bytes), 'UTF-8 mode returns bytes');
			is_deeply(main::convert_from_json($bytes), $unicode, 'Unicode round-trips');
			is($bytes, JSON::PP->new->canonical->utf8->encode($unicode),
				'compact UTF-8 matches the existing canonical encoding');
			my $backup = {content => join('', map { chr } 0..255)};
			my $raw = main::convert_to_json($backup, 0, 0, 1);
			is($raw, JSON::PP->new->canonical->encode($backup),
				'raw configuration bytes retain their existing serialized form');
			is_deeply(main::convert_from_json($raw, 1), $backup,
				'raw configuration bytes round-trip');
		};
	}

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
