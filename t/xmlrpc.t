#!/usr/bin/perl
# Unit tests for xmlrpc.cgi helper subs.
#
# xmlrpc.cgi is loaded like miniserv loads Perl CGIs; its top-level body
# (ACL check, reading
# the request, dispatching the call, emitting the response) is skipped unless
# it is invoked directly or via Webmin's CGI environment, so loading it only
# defines the subs plus loads WebminCore.
#
# Most subs under test are the XML <-> Perl marshalling layer:
#   encode_xml_value  - Perl scalar/hashref/arrayref -> XML-RPC <value> body
#   parse_xml_value   - parsed XML <value> node      -> Perl scalar/ref
#   find_xmls         - recursive element search over an XML::Parser tree
#   make_error_xml    - faultCode/faultString -> <methodResponse> fault doc
# A separate regression test covers Webmin's internal-CGI `do` execution path.
#
# Assertions target the contract (type selection, round-trip identity,
# structural balance, escaping), not exact whitespace or attribute order.

use strict;
use warnings;
use Test::More;
use File::Basename qw(dirname);
use File::Spec;

# WebminCore loads web-lib.pl / ui-lib.pl with relative `do`, so the repo
# root must be the cwd (the script's BEGIN block adds "." to @INC).
my $root = File::Spec->rel2abs(
	File::Spec->catdir(dirname(__FILE__), '..'));
chdir($root) or die "chdir $root: $!";

my $script = File::Spec->catfile($root, 'xmlrpc.cgi');
my $loaded = do $script;
die $@ if $@;
die "do $script: $!" if (!defined($loaded) && $!);

# XML::Parser is only needed to build the parsed-tree inputs for
# parse_xml_value and the round-trip tests. Probe for it once.
my $have_parser = eval { require XML::Parser; 1 };

sub run_internal_cgi_empty_post {
	my $code = <<'PERL';
use strict;
use warnings;
use File::Path qw(make_path);
use File::Temp qw(tempdir);

my ($root) = @ARGV;
my $cfg = tempdir(CLEANUP => 1);
my $var = tempdir(CLEANUP => 1);
make_path("$var/modules");

open(my $config, ">", "$cfg/config") or die "open config: $!";
print {$config} "os_type=unix\n";
close($config) or die "close config: $!";

open(my $acl, ">", "$cfg/webmin.acl") or die "open acl: $!";
print {$acl} "root: *\n";
close($acl) or die "close acl: $!";

local %ENV = (
	%ENV,
	WEBMIN_CONFIG    => $cfg,
	WEBMIN_VAR       => $var,
	SERVER_ROOT      => $root,
	GATEWAY_INTERFACE => "CGI/1.1",
	REQUEST_METHOD   => "POST",
	CONTENT_LENGTH   => 0,
	SCRIPT_NAME      => "/xmlrpc.cgi",
	SCRIPT_FILENAME  => "$root/xmlrpc.cgi",
	REMOTE_USER      => "root",
);

do "./xmlrpc.cgi";
die $@ if $@;
PERL
	open(my $child, "-|", $^X, "-I.", "-e", $code, $root)
		or die "fork xmlrpc.cgi CGI harness: $!";
	local $/ = undef;
	my $out = <$child>;
	close($child);
	return ($?, $out);
}

subtest 'internal CGI invocation emits headers' => sub {
	my ($status, $out) = run_internal_cgi_empty_post();

	is($status, 0, 'internal CGI harness exits cleanly');
	like($out, qr/\AContent-type:\s*text\/xml/i,
	     'response starts with a CGI Content-type header');
	like($out, qr/<methodResponse>/, 'response contains an XML-RPC fault body');
};

# Build the parsed-tree node that parse_xml_value expects from an
# encode_xml_value body: wrap it in <value>...</value> and parse. The root
# node XML::Parser returns is itself a [name, content] pair, exactly the
# shape find_xmls walks.
sub value_tree {
	my ($body) = @_;
	return XML::Parser->new('Style' => 'Tree')
		->parse("<value>$body</value>");
}

# encode_xml_value - type selection from the Perl side
subtest 'encode_xml_value type selection' => sub {
	# Integers (with and without sign).
	is(encode_xml_value(5),    "<int>5</int>\n",    'positive int');
	is(encode_xml_value(-3),   "<int>-3</int>\n",   'negative int');
	is(encode_xml_value(0),    "<int>0</int>\n",    'zero is an int');

	# Doubles.
	like(encode_xml_value('3.14'),  qr{^<double>3\.14</double>\s*$},  'decimal -> double');
	like(encode_xml_value('-0.5'),  qr{^<double>-0\.5</double>\s*$},  'signed decimal -> double');

	# Plain strings.
	like(encode_xml_value('hello'), qr{^<string>hello</string>\s*$}, 'word -> string');
	like(encode_xml_value(''),      qr{^<string></string>\s*$},      'empty string -> empty <string>');

	# A value with control characters cannot live in a <string> (the
	# printable-range regex fails), so it must fall through to base64.
	like(encode_xml_value("a\tb\n"), qr{^<base64>.*</base64>\s*$}s,
	     'control chars force base64 encoding');
};

subtest 'encode_xml_value escapes markup' => sub {
	my $out = encode_xml_value('<b>&"x"</b>');
	unlike($out, qr/<b>/, 'literal markup does not survive in a string value');
	like($out, qr/&(?:amp|lt|gt|quot|#3[0-9]|#6[0-9]);/, 'special chars HTML-escaped');

	# Struct member names are escaped too.
	my $s = encode_xml_value({ '<k>' => 'v' });
	unlike($s, qr/<name><k></, 'struct member name is escaped');
};

subtest 'encode_xml_value nested structures' => sub {
	my $out = encode_xml_value({ list => [1, 2], name => 'bob' });

	# Structural balance of the emitted markup.
	for my $tag (qw(struct member name value)) {
		my $open  = () = $out =~ /<$tag\b[^>]*>/g;
		my $close = () = $out =~ /<\/$tag>/g;
		is($open, $close, "<$tag> tags balanced");
		}
	like($out, qr{<array>.*<data>.*</data>.*</array>}s, 'nested array rendered inside struct');

	# A flat array of mixed scalar types: one <value> wrapper each.
	my $arr = encode_xml_value([5, 'hi', 'x']);
	like($arr, qr{^<array>\s*<data>}s, 'array opens with <data>');
	my $vopen  = () = $arr =~ /<value>/g;
	my $vclose = () = $arr =~ /<\/value>/g;
	is($vopen, $vclose, '<value> wrappers balanced in array');
	is($vopen, 3,       'one <value> per scalar array element');
};

# find_xmls - recursive element search over a hand-built tree. The tree
# format is XML::Parser's: a node is [name, [ {attrs}, childname, childcontent, ...]].
subtest 'find_xmls' => sub {
	# <a><b>x</b><c><b>y</b></c></a>
	my $tree = [ 'a', [ {},
		'b', [ {}, 0, 'x' ],
		'c', [ {}, 'b', [ {}, 0, 'y' ] ],
		] ];

	my @b = find_xmls('b', $tree);
	is(scalar @b, 2, 'finds both <b> elements at any depth');
	is($b[0]->[0], 'b', 'returned node carries its tag name');
	is($b[0]->[1]->[2], 'x', 'first <b> text reachable at content index 2');

	# Depth limiting: depth 1 only looks at direct children, so the
	# nested <b> inside <c> is not reached.
	my @shallow = find_xmls('b', $tree, 1);
	is(scalar @shallow, 1, 'depth=1 finds only the direct-child <b>');

	# Name-list form matches any of several tags (case-insensitively,
	# via indexoflc). Search stops descending at a match, so the <b>
	# nested inside the matched <c> is not also returned.
	my @bc = find_xmls([ 'c', 'b' ], $tree);
	is(scalar @bc, 2, 'name-list matches the outer <b> and the <c>, not inside a match');

	# A name that is not present returns the empty list.
	is_deeply([ find_xmls('zzz', $tree) ], [], 'absent name -> empty list');

	# The root element itself can match.
	my @self = find_xmls('a', $tree);
	is(scalar @self, 1, 'root element matches its own name');
};

# parse_xml_value - drive the real parser so the tree shape is authentic.
subtest 'parse_xml_value' => sub {
	plan skip_all => 'XML::Parser not installed' if !$have_parser;

	is(parse_xml_value(value_tree('<int>42</int>')),       42,    'int parsed');
	is(parse_xml_value(value_tree('<i4>7</i4>')),          7,     'i4 alias parsed');
	is(parse_xml_value(value_tree('<boolean>1</boolean>')),1,     'boolean parsed');
	is(parse_xml_value(value_tree('<double>2.5</double>')),'2.5', 'double parsed');
	is(parse_xml_value(value_tree('<string>hi</string>')), 'hi',  'string parsed');

	# base64 is decoded back to its raw bytes.
	my $b64 = encode_base64("ab\x00cd");
	chomp($b64);
	is(parse_xml_value(value_tree("<base64>$b64</base64>")), "ab\x00cd",
	   'base64 decoded to raw bytes');

	# struct -> hashref.
	my $h = parse_xml_value(value_tree(
		'<struct><member><name>k</name><value><int>1</int></value></member></struct>'));
	is(ref($h), 'HASH', 'struct -> hashref');
	is($h->{k}, 1,      'struct member value parsed');

	# array -> arrayref.
	my $a = parse_xml_value(value_tree(
		'<array><data><value><int>1</int></value><value><string>x</string></value></data></array>'));
	is(ref($a), 'ARRAY', 'array -> arrayref');
	is_deeply($a, [1, 'x'], 'array elements parsed in order');
};

# Round-trip: encode_xml_value then parse_xml_value should reproduce the
# original Perl value. This is the core marshalling contract.
subtest 'encode/parse round-trip' => sub {
	plan skip_all => 'XML::Parser not installed' if !$have_parser;

	my %scalars = (
		'positive int'  => 5,
		'negative int'  => -42,
		'zero'          => 0,
		'simple string' => 'hello world',
		);
	for my $name (sort keys %scalars) {
		my $v = $scalars{$name};
		is(parse_xml_value(value_tree(encode_xml_value($v))), $v,
		   "round-trip: $name");
		}

	# Nested struct + array survives a round-trip structurally.
	my $complex = { name => 'bob', nums => [1, 2, 3], inner => { x => 'y' } };
	is_deeply(parse_xml_value(value_tree(encode_xml_value($complex))),
		  { name => 'bob', nums => [1, 2, 3], inner => { x => 'y' } },
		  'round-trip: nested struct and array');

	# Binary data routes through base64 and comes back byte-identical.
	my $bin = join('', map { chr } 0 .. 31);
	is(parse_xml_value(value_tree(encode_xml_value($bin))), $bin,
	   'round-trip: binary payload via base64');
};

# make_error_xml - fault document shape, and that each call is independent
# (the body buffer is a my-scoped var, not an accumulating package global).
subtest 'make_error_xml' => sub {
	my $err = make_error_xml(7, 'boom');

	like($err, qr{<methodResponse>.*<fault>.*</fault>.*</methodResponse>}s,
	     'fault wrapped in methodResponse');
	like($err, qr{<name>faultCode</name>},   'carries faultCode member');
	like($err, qr{<name>faultString</name>}, 'carries faultString member');
	like($err, qr{<int>7</int>},              'numeric code encoded as int');
	like($err, qr{boom},                      'message text present');

	# Two successive calls must not accumulate: each returns exactly one
	# methodResponse. (A package-global buffer would double the second.)
	my $first  = make_error_xml(1, 'one');
	my $second = make_error_xml(2, 'two');
	my $count  = () = $second =~ /<methodResponse>/g;
	is($count, 1, 'each call returns a single, fresh fault document');
	unlike($second, qr/one/, 'second call does not contain first message');

	# A faultString with newlines still produces a single balanced doc.
	my $multiline = make_error_xml(9, "line1\nline2");
	my $open  = () = $multiline =~ /<methodResponse>/g;
	my $close = () = $multiline =~ /<\/methodResponse>/g;
	is($open, $close, 'methodResponse balanced with multiline message');
};

done_testing();
