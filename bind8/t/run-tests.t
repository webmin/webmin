#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use Cwd qw(abs_path);
use File::Temp qw(tempdir);

sub script_dir
{
    my $path = $0;
    if ($path =~ m{^/}) {
        $path =~ s{/[^/]+$}{};
        return $path;
    }
    my $cwd = `pwd`;
    chomp($cwd);
    if ($path =~ m{/}) {
        $path =~ s{/[^/]+$}{};
        return $cwd.'/'.$path;
    }
    return $cwd;
}

my $bindir = script_dir();
my $rootdir = abs_path("$bindir/../..") or die "rootdir: $!";

my $confdir = tempdir(CLEANUP => 1);
my $vardir = tempdir(CLEANUP => 1);

# Global Webmin config
open(my $cfh, ">", "$confdir/config") or die "config: $!";
print $cfh "os_type=linux\nos_version=0\n";
close($cfh);
open(my $vfh, ">", "$confdir/var-path") or die "var-path: $!";
print $vfh "$vardir\n";
close($vfh);

# Per-module config
mkdir "$confdir/bind8" or die "bind8 confdir: $!";
my $named_conf = "$confdir/named.conf";
open(my $mfh, ">", "$confdir/bind8/config") or die "bind8 config: $!";
print $mfh "named_conf=$named_conf\n";
print $mfh "named_path=/usr/sbin/named\n";
print $mfh "short_names=0\n";
print $mfh "ipv6_mode=1\n";
print $mfh "spf_record=0\n";
print $mfh "soa_style=0\n";
print $mfh "soa_start=0\n";
print $mfh "updserial_on=1\n";
print $mfh "allow_underscore=0\n";
print $mfh "allow_wild=1\n";
close($mfh);

# Avoid spawning `named -v`: bind8-lib reads version from this file.
open(my $verfh, ">", "$confdir/bind8/version") or die "version: $!";
print $verfh "9.18.0\n";
close($verfh);

$ENV{'WEBMIN_CONFIG'} = $confdir;
$ENV{'WEBMIN_VAR'} = $vardir;
$ENV{'FOREIGN_MODULE_NAME'} = 'bind8';
$ENV{'FOREIGN_ROOT_DIRECTORY'} = $rootdir;

chdir("$bindir/..") or die "chdir: $!";

require "$bindir/../bind8-lib.pl";
our (%config, %access, $bind_version);

# Sanity check: globals populated by lib.
is($bind_version, '9.18', 'bind_version normalized from version file');
ok($config{'named_conf'}, 'named_conf loaded from module config');

# --- IPv4 reverse helpers --------------------------------------------------
is(ip_to_arpa('1.2.3.4'), '4.3.2.1.in-addr.arpa.', 'ip_to_arpa basic');
is(arpa_to_ip('4.3.2.1.in-addr.arpa.'), '1.2.3.4', 'arpa_to_ip basic');
is(arpa_to_ip(ip_to_arpa('192.0.2.55')), '192.0.2.55',
   'ip_to_arpa round-trips through arpa_to_ip');
# Pass-through for non-matching input
is(arpa_to_ip('not.an.arpa.name'), 'not.an.arpa.name',
   'arpa_to_ip leaves non-arpa input alone');
is(ip_to_arpa('not.an.ip'), 'not.an.ip',
   'ip_to_arpa leaves non-IPv4 input alone');

# --- IPv6 helpers ----------------------------------------------------------
is(expand_ip6('2001:db8::1'), '2001:db8:0:0:0:0:0:1',
   'expand_ip6 expands ::');
is(expand_ip6('::1'), '0:0:0:0:0:0:0:1', 'expand_ip6 leading ::');
is(expand_ip6('fe80::'), 'fe80:0:0:0:0:0:0:0', 'expand_ip6 trailing ::');
is(expand_ip6('FE80::1'), 'fe80:0:0:0:0:0:0:1', 'expand_ip6 lowercases');
is(expandall_ip6('2001:db8::1'),
   '2001:0db8:0000:0000:0000:0000:0000:0001',
   'expandall_ip6 pads zeros');

# net_to_ip6int with default ipv6_mode=1 should produce ip6.arpa names
my $rev6 = net_to_ip6int('2001:db8::1');
like($rev6, qr/\.ip6\.arpa\.$/, 'net_to_ip6int returns ip6.arpa');
# Round-trip from ip6.arpa back to a canonical address
my $back = ip6int_to_net($rev6);
$back =~ s{/\d+$}{};
like($back, qr/^2001:.*::?1$/i,
     'ip6int_to_net inverts net_to_ip6int for full address');

# Bits parameter trims labels (and so encodes a /prefix length)
my $rev6_short = net_to_ip6int('2001:db8::', 32);
like($rev6_short, qr/^8\.b\.d\.0\.1\.0\.0\.2\.ip6\.arpa\.$/i,
     'net_to_ip6int with /32 truncates to 8 nibbles');

# --- email <-> dotted notation --------------------------------------------
is(email_to_dotted('admin@example.com'), 'admin.example.com.',
   'simple email -> dotted');
is(dotted_to_email('admin.example.com.'), 'admin@example.com',
   'simple dotted -> email');
is(dotted_to_email(email_to_dotted('hostmaster@example.com')),
   'hostmaster@example.com', 'email <-> dotted round-trip');
# Dots in local-part must be escaped, per RFC 1183
is(email_to_dotted('first.last@example.com'),
   'first\\.last.example.com.',
   'email_to_dotted escapes dots in local part');
is(dotted_to_email('first\\.last.example.com.'), 'first.last@example.com',
   'dotted_to_email unescapes dots in local part');
is(dotted_to_email('.'), '.', 'root domain dotted form preserved');

# --- valdnsname / valemail -------------------------------------------------
ok(valdnsname('host.example.com', 0), 'valid hostname accepted');
ok(valdnsname('_dmarc.example.com', 0, 'example.com', 'TXT'),
   'underscore allowed for TXT owner name');
ok(!valdnsname('_dmarc.example.com', 0, 'example.com', 'A'),
   'underscore rejected for A owner name when allow_underscore off');
ok(!valdnsname('-leading.example.com', 0),
   'leading dash rejected');
ok(!valdnsname('trailing-.example.com', 0),
   'trailing dash rejected');
ok(!valdnsname('a..b.example.com', 0),
   'double dot rejected');
ok(valdnsname('*.example.com', 1),
   'wildcard accepted when wild flag set');

ok(valemail('admin@example.com'), 'simple email valid');
ok(valemail('admin.test@example.com'), 'email with dot in local valid');
ok(valemail('.'), 'root marker email valid');
# valemail also accepts the SOA RNAME dotted form (no @), so "no-at-sign"
# parses successfully; the rejection cases are syntactically invalid input.
ok(!valemail('contains spaces'),
   'free-form text with spaces rejected');

# --- check_net_ip ----------------------------------------------------------
ok(check_net_ip('192.168.1.0/24'), 'CIDR /24 accepted');
ok(check_net_ip('192.168.1.5'), 'plain IP accepted');
ok(check_net_ip('10.0.1-100'), 'range syntax accepted');
ok(!check_net_ip('999.1.1.1'), 'out-of-range octet rejected');

# --- compute_serial --------------------------------------------------------
$config{'soa_style'} = 0;
is(compute_serial(2024010100), 2024010101,
   'soa_style 0 increments by one');
$config{'soa_style'} = 2;
my $now = time();
my $serial2 = compute_serial($now - 10);
ok($serial2 > $now - 10, 'soa_style 2 unix-time serial advances');
$config{'soa_style'} = 1;
$config{'soa_start'} = 0;
my $today = date_serial();
my $serial1 = compute_serial($today.'00');
is($serial1, $today.'01', 'soa_style 1 increments within day');
# Rollover: same date, counter at 99 -> next day, counter reset to soa_start.
my $rolled = compute_serial($today.'99');
is($rolled, sprintf("%d%02d", $today + 1, 0),
   'soa_style 1 rolls counter past 99 to next day');
# Older-dated serial gets bumped forward to today regardless.
my $caught_up = compute_serial('1999010199');
is($caught_up, $today.'00',
   'soa_style 1 catches up to current date when old serial is stale');

# --- make_record / record_id / find_record_by_id --------------------------
my $rec = make_record('www', 3600, 'IN', 'A', '192.0.2.1', 'web server');
like($rec, qr/^www\t3600\tIN\tA\t192\.0\.2\.1\t;web server$/,
     'make_record renders A record line');
my $rec_notlt = make_record('www', '', 'IN', 'A', '192.0.2.1');
is($rec_notlt, "www\tIN\tA\t192.0.2.1",
   'make_record omits TTL when blank');
# SPF gets mapped down to TXT when spf_record is 0 (default)
my $spfline = make_record('foo', '', 'IN', 'SPF', '"v=spf1 -all"');
like($spfline, qr/\tTXT\t/,
     'make_record maps SPF to TXT when spf_record=0');

my $r = { 'name' => 'a.example.com.', 'type' => 'A',
          'values' => [ '10.0.0.1' ] };
is(record_id($r), 'a.example.com./A/10.0.0.1', 'record_id basic');
my $soa = { 'name' => 'example.com.', 'type' => 'SOA',
            'values' => [ 'ns', 'admin', 1, 2, 3, 4, 5 ] };
is(record_id($soa), 'example.com./SOA',
   'record_id omits values for SOA');

my @recs = (
    { 'name' => 'a.example.com.', 'type' => 'A',
      'values' => [ '10.0.0.1' ], 'num' => 0 },
    { 'name' => 'a.example.com.', 'type' => 'A',
      'values' => [ '10.0.0.1' ], 'num' => 1 },
    { 'name' => 'b.example.com.', 'type' => 'A',
      'values' => [ '10.0.0.2' ], 'num' => 2 },
);
my $found = find_record_by_id(\@recs, 'b.example.com./A/10.0.0.2', 2);
ok($found && $found->{'num'} == 2, 'find_record_by_id unique match');
my $found_dup = find_record_by_id(\@recs, 'a.example.com./A/10.0.0.1', 1);
ok($found_dup && $found_dup->{'num'} == 1,
   'find_record_by_id picks correct duplicate by num');

# --- join_record_values ---------------------------------------------------
is(join_record_values({ 'type' => 'A', 'values' => [ '192.0.2.1' ] }),
   '192.0.2.1', 'join_record_values single A value');
is(join_record_values({ 'type' => 'TXT', 'values' => [ 'hello' ] }),
   '"hello"', 'join_record_values quotes TXT');
is(join_record_values({ 'type' => 'MX', 'values' => [ '10', 'mail.example.com.' ] }),
   '10 mail.example.com.', 'join_record_values MX preference and host');

# --- SPF parsing / serialization ------------------------------------------
my $spf = parse_spf('v=spf1 mx a:relay.example.com ip4:192.0.2.0/24 -all');
ok($spf, 'parse_spf returns hash');
is($spf->{'mx'}, 1, 'spf flag mx set');
is_deeply($spf->{'a:'}, [ 'relay.example.com' ], 'spf a: list');
is_deeply($spf->{'ip4:'}, [ '192.0.2.0/24' ], 'spf ip4: list');
is($spf->{'all'}, 3, 'spf -all maps to 3');
my $spf_str = join_spf($spf);
like($spf_str, qr/v=spf1/, 'join_spf starts with v=spf1');
like($spf_str, qr/-all/, 'join_spf preserves -all');
my $spf2 = parse_spf($spf_str);
is($spf2->{'all'}, 3, 'spf round-trips -all');
is_deeply($spf2->{'a:'}, [ 'relay.example.com' ], 'spf round-trips a:');
is_deeply($spf2->{'ip4:'}, [ '192.0.2.0/24' ], 'spf round-trips ip4:');

# Not an SPF record
is(parse_spf('just some text'), undef, 'parse_spf returns undef for non-SPF');

# --- DMARC parsing / serialization ----------------------------------------
my $dmarc = parse_dmarc('v=DMARC1; p=reject; rua=mailto:dmarc@example.com; pct=100');
ok($dmarc, 'parse_dmarc returns hash');
is($dmarc->{'p'}, 'reject', 'dmarc policy');
is($dmarc->{'pct'}, '100', 'dmarc pct');
is($dmarc->{'rua'}, 'mailto:dmarc@example.com', 'dmarc rua');
my $dmarc_str = join_dmarc($dmarc);
like($dmarc_str, qr/v=DMARC1/, 'join_dmarc starts with v=DMARC1');
like($dmarc_str, qr/p=reject/, 'join_dmarc preserves policy');
my $dmarc2 = parse_dmarc($dmarc_str);
is($dmarc2->{'p'}, 'reject', 'dmarc round-trips policy');
is($dmarc2->{'pct'}, '100', 'dmarc round-trips pct');

# --- extract_time_units ----------------------------------------------------
my @ev = ('3600', '5M', '2H', '1D', '7W');
my @units = extract_time_units(@ev);
is_deeply(\@units, ['', 'M', 'H', 'D', 'W'], 'extract_time_units returns units');
is_deeply(\@ev, ['3600', '5', '2', '1', '7'],
          'extract_time_units strips trailing unit char in place');

# --- version_atleast -------------------------------------------------------
ok(version_atleast(9), 'bind 9.18 is >= 9');
ok(version_atleast(9, 18), 'bind 9.18 is >= 9.18');
ok(!version_atleast(9, 19), 'bind 9.18 is not >= 9.19');

# --- wrap_lines / convert_to_absolute -------------------------------------
is_deeply([ wrap_lines('abcdefghij', 3) ],
          [ 'abc', 'def', 'ghi', 'j' ],
          'wrap_lines splits text');
is_deeply([ wrap_lines('', 5) ], [],
          'wrap_lines returns empty list for empty input');

is(convert_to_absolute('www', 'example.com'), 'www.example.com.',
   'convert_to_absolute short name');
is(convert_to_absolute('@', 'example.com'), 'example.com.',
   'convert_to_absolute @ name');
is(convert_to_absolute('www.example.com', 'example.com'),
   'www.example.com.', 'convert_to_absolute name already in zone');
is(convert_to_absolute('www.other.', 'example.com'), 'www.other.',
   'convert_to_absolute keeps fully qualified name');

# --- make_reverse_name ----------------------------------------------------
is(make_reverse_name('192.0.2.1', 'A', { 'name' => '2.0.192.in-addr.arpa' }),
   '1.2.0.192.in-addr.arpa.', 'make_reverse_name IPv4');
# Partial reverse delegation: zone name encodes a /27 inside a /24
my $partial = { 'name' => '0/27.2.0.192.in-addr.arpa' };
is(make_reverse_name('192.0.2.5', 'A', $partial),
   '5.0/27.2.0.192.in-addr.arpa.',
   'make_reverse_name partial reverse delegation');

# --- dnssec_size_range / list_dnssec_algorithms ---------------------------
is_deeply([ dnssec_size_range('RSASHA256') ], [ 2048, 4096 ],
          'dnssec_size_range RSASHA256');
is_deeply([ dnssec_size_range('DSA') ], [ 512, 1024, 64 ],
          'dnssec_size_range DSA includes divisor');
is_deeply([ dnssec_size_range('NOPE') ], [],
          'dnssec_size_range unknown alg returns empty');
my @algs = list_dnssec_algorithms();
ok((grep { $_ eq 'ED25519' } @algs),
   'list_dnssec_algorithms includes ED25519');

# --- can_edit_zone access control ------------------------------------------
{
    local %access = ( 'zones' => '*', 'inviews' => '*', 'dironly' => 0 );
    ok(can_edit_zone({ 'name' => 'example.com', 'file' => '/etc/named/example.com' }),
       'wildcard ACL allows any zone');

    %access = ( 'zones' => 'example.com', 'inviews' => '*' );
    ok(can_edit_zone({ 'name' => 'example.com' }),
       'allow-list ACL accepts named zone');
    ok(!can_edit_zone({ 'name' => 'other.com' }),
       'allow-list ACL rejects unlisted zone');

    # Deny-list convention: leading "!" is a separate token (see acl_security.pl).
    %access = ( 'zones' => '! banned.com', 'inviews' => '*' );
    ok(can_edit_zone({ 'name' => 'allowed.com' }),
       'deny-list ACL allows unbanned zone');
    ok(!can_edit_zone({ 'name' => 'banned.com' }),
       'deny-list ACL rejects banned zone');

    %access = ( 'zones' => '*', 'inviews' => 'internal' );
    ok(can_edit_zone({ 'name' => 'z.com', 'view' => 'internal' }),
       'view ACL accepts matching view');
    ok(!can_edit_zone({ 'name' => 'z.com', 'view' => 'external' }),
       'view ACL rejects mismatched view');
}

# --- can_edit_view ---------------------------------------------------------
{
    local %access = ( 'vlist' => '*' );
    ok(can_edit_view({ 'name' => 'anyview' }),
       'wildcard view ACL allows all');
    %access = ( 'vlist' => 'public private' );
    ok(can_edit_view({ 'name' => 'public' }),
       'allow-list view ACL accepts listed view');
    ok(!can_edit_view({ 'name' => 'hidden' }),
       'allow-list view ACL rejects unlisted view');
    %access = ( 'vlist' => '! hidden' );
    ok(can_edit_view({ 'name' => 'public' }),
       'deny-list view ACL allows non-listed view');
    ok(!can_edit_view({ 'name' => 'hidden' }),
       'deny-list view ACL rejects listed view');
}

# --- config-file parser round-trip ----------------------------------------
my $sample = <<'EOF';
// Test BIND config
options {
	directory "/var/named";
	listen-on port 53 { 127.0.0.1; 192.0.2.1; };
	allow-query { localhost; };
};

zone "example.com" IN {
	type master;
	file "example.com.hosts";
	allow-transfer { 192.0.2.2; };
};

zone "0.0.127.in-addr.arpa" {
	type master;
	file "named.local";
};
EOF
$config{'named_conf'} = $named_conf;
open(my $nfh, ">", $named_conf) or die "named.conf: $!";
print $nfh $sample;
close($nfh);
clear_config_cache();

my $conf = get_config();
ok(ref($conf) eq 'ARRAY' && @$conf >= 3,
   'read_config_file returned >= 3 top-level structures');

my ($opts) = find('options', $conf);
ok($opts && $opts->{'members'}, 'options block parsed');
my $dir = find_value('directory', $opts->{'members'});
is($dir, '/var/named', 'directory option value');

my ($lo) = find('listen-on', $opts->{'members'});
ok($lo, 'listen-on directive present');
is($lo->{'value'}, 'port', 'listen-on first value');
is_deeply($lo->{'values'}, [ 'port', '53' ],
          'listen-on values before block');
is(scalar @{$lo->{'members'}}, 2,
   'listen-on inner block has 2 addresses');

my @zones = find('zone', $conf);
is(scalar @zones, 2, 'two zone directives found');
my ($z) = grep { $_->{'value'} eq 'example.com' } @zones;
ok($z, 'example.com zone found');
is(find_value('type', $z->{'members'}), 'master',
   'example.com zone type');
is(find_value('file', $z->{'members'}), 'example.com.hosts',
   'example.com zone file');

# extract_value handles directives with no separate 'value'
my $no_value = { 'values' => [ 'first', 'second' ] };
is(extract_value($no_value), 'first',
   'extract_value falls back to first values entry');

# directive_lines renders a structure back to text that can be re-parsed
my @lines = directive_lines($z, 0);
ok(scalar @lines >= 1, 'directive_lines emits at least one line');
like($lines[0], qr/^zone "example\.com"/,
     'directive_lines quotes zone name');

# Write rendered config back out and verify it re-parses identically
my $named_conf2 = "$confdir/named-roundtrip.conf";
open(my $rfh, ">", $named_conf2) or die "rt: $!";
foreach my $top (@$conf) {
    print $rfh join("\n", directive_lines($top, 0)), "\n";
}
close($rfh);
my @reparsed = read_config_file($named_conf2);
my ($z2) = grep { $_->{'name'} eq 'zone' &&
                  $_->{'value'} eq 'example.com' } @reparsed;
ok($z2, 'example.com zone present after round-trip');
is(find_value('file', $z2->{'members'}), 'example.com.hosts',
   'example.com zone file survives round-trip');
my ($opts2) = grep { $_->{'name'} eq 'options' } @reparsed;
is(find_value('directory', $opts2->{'members'}), '/var/named',
   'options directory survives round-trip');

# --- zone-file parser ------------------------------------------------------
my $zonefile = "$confdir/example.com.hosts";
open(my $zfh, ">", $zonefile) or die "zonefile: $!";
print $zfh <<'EOF';
$TTL 3600
@	IN	SOA	ns1.example.com. hostmaster.example.com. (
				2024010101 ; serial
				3600 ; refresh
				600 ; retry
				1209600 ; expire
				3600 ) ; minimum
@	IN	NS	ns1.example.com.
@	IN	NS	ns2.example.com.
ns1	IN	A	192.0.2.1
ns2	IN	A	192.0.2.2
www	IN	CNAME	@
mail	IN	A	192.0.2.10
@	IN	MX	10 mail
_dmarc	IN	TXT	"v=DMARC1; p=none"
EOF
close($zfh);

my @zrecs = read_zone_file($zonefile, 'example.com', undef, 0, 1);
ok(scalar @zrecs >= 8, 'read_zone_file parsed multiple records')
    or diag("got ".scalar(@zrecs)." records");

my ($soa_rec) = grep { $_->{'type'} eq 'SOA' } @zrecs;
ok($soa_rec, 'SOA record parsed');
is(scalar @{$soa_rec->{'values'}}, 7,
   'SOA has mname rname and 5 numeric fields');
is($soa_rec->{'values'}->[2], '2024010101', 'SOA serial parsed');

my @ns = grep { $_->{'type'} eq 'NS' } @zrecs;
is(scalar @ns, 2, 'two NS records parsed');

my @a = grep { $_->{'type'} eq 'A' } @zrecs;
is(scalar @a, 3, 'three A records parsed');

my ($mx) = grep { $_->{'type'} eq 'MX' } @zrecs;
ok($mx, 'MX record parsed');
is_deeply($mx->{'values'}, [ '10', 'mail' ],
          'MX values: preference + host');

# DMARC underneath an underscore name: zone parser classifies as DMARC
my ($dmarc_rec) = grep { uc($_->{'type'}) eq 'DMARC' } @zrecs;
ok($dmarc_rec, 'DMARC record reclassified from TXT');

# --- only-soa fast path ----------------------------------------------------
my @soaonly = read_zone_file($zonefile, 'example.com', undef, 1, 1);
my @soas = grep { $_->{'type'} eq 'SOA' } @soaonly;
is(scalar @soas, 1, 'only-soa mode finds the SOA record');

# --- is_raw_format_records -------------------------------------------------
ok(!is_raw_format_records($zonefile),
   'text-format zone file not classified as raw');
my $rawfile = "$confdir/raw.zone";
open(my $rfh2, ">", $rawfile) or die "rawfile: $!";
binmode $rfh2;
print $rfh2 "\0\0\0xxx";
close($rfh2);
ok(is_raw_format_records($rawfile),
   'three-NUL preamble classified as raw format');

done_testing();
