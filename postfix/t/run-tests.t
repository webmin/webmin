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

my $bindir  = script_dir();
my $rootdir = abs_path("$bindir/../..") or die "rootdir: $!";

my $confdir = tempdir(CLEANUP => 1);
my $vardir  = tempdir(CLEANUP => 1);

# Global Webmin config
open(my $cfh, ">", "$confdir/config") or die "config: $!";
print $cfh "os_type=linux\nos_version=0\n";
close($cfh);
open(my $vfh, ">", "$confdir/var-path") or die "var-path: $!";
print $vfh "$vardir\n";
close($vfh);

# A main.cf to drive the config parser
my $maincf   = "$confdir/main.cf";
my $mastercf = "$confdir/master.cf";
open(my $mc, ">", $maincf) or die "main.cf: $!";
print $mc <<'EOF';
myhostname = mail.example.com
mydestination = example.com,
	mail.example.com,
	localhost
compatibility_level = 2
util_lt = {{$compatibility_level} < {3} ? {old} : {new}}
util_ge = {{$compatibility_level} >= {3} ? {high} : {low}}
util_eq = {{$compatibility_level} == {2} ? {match} : {nomatch}}
subtest = key1 valueA key2 valueB
alias_maps = hash:/etc/postfix/aliases, hash:/etc/aliases
EOF
close($mc);

# A master.cf with one enabled and one disabled service, plus a continuation
open(my $ms, ">", $mastercf) or die "master.cf: $!";
print $ms <<'EOF';
smtp      inet  n       -       y       -       -       smtpd
#qmgr     unix  n       -       n       300     1       qmgr
pickup    unix  n       -       y       60      1       pickup
  -o content_filter=foo
EOF
close($ms);

# Per-module config
mkdir "$confdir/postfix" or die "postfix confdir: $!";
open(my $mod, ">", "$confdir/postfix/config") or die "module config: $!";
print $mod "postfix_config_file=$maincf\n";
print $mod "postfix_master=$mastercf\n";
print $mod "postfix_config_command=/bin/true\n";
print $mod "postfix_control_command=/bin/true\n";
print $mod "prefix_cmts=0\n";
close($mod);

# Pre-seed the version file so loading the lib does not shell out to postconf.
open(my $ver, ">", "$confdir/postfix/version") or die "version: $!";
print $ver "3.4.0\n";
close($ver);

$ENV{'WEBMIN_CONFIG'}          = $confdir;
$ENV{'WEBMIN_VAR'}             = $vardir;
$ENV{'FOREIGN_MODULE_NAME'}    = 'postfix';
$ENV{'FOREIGN_ROOT_DIRECTORY'} = $rootdir;

chdir("$bindir/..") or die "chdir: $!";

require "$bindir/../postfix-lib.pl";
our (%config, $postfix_version, $virtual_maps, $ldap_timeout, $config_dir);

# --- load-time globals -----------------------------------------------------
is($postfix_version, '3.4.0', 'postfix_version read from version file');
is($virtual_maps, 'virtual_alias_maps', 'virtual_maps for >= 2.x');
is($ldap_timeout, 'ldap_timeout', 'ldap_timeout for >= 2.x');
is($config_dir, $confdir, 'guess_config_dir is dirname of main.cf');

# --- file_map_type ---------------------------------------------------------
ok(file_map_type('hash'),  'hash is a file map type');
ok(file_map_type('pcre'),  'pcre is a file map type');
ok(file_map_type('cidr'),  'cidr is a file map type');
ok(!file_map_type('mysql'),'mysql is not a file map type');
ok(!file_map_type('ldap'), 'ldap is not a file map type');

# --- get_maps_types_files --------------------------------------------------
is_deeply([ get_maps_types_files('hash:/etc/postfix/canonical') ],
          [ [ 'hash', '/etc/postfix/canonical' ] ],
          'single type:file parsed');
is_deeply([ get_maps_types_files(
                'hash:/etc/postfix/canonical, proxy:pcre:/etc/postfix/x') ],
          [ [ 'hash', '/etc/postfix/canonical' ],
            [ 'pcre', '/etc/postfix/x' ] ],
          'multiple maps and proxy: prefix parsed');
is_deeply([ get_maps_types_files('mysql:/etc/postfix/m.cf') ],
          [ [ 'mysql', '/etc/postfix/m.cf' ] ],
          'mysql backend type:file parsed');
is_deeply([ get_maps_types_files('') ], [],
          'empty value yields no maps');
is_deeply([ get_maps_types_files('garbage-without-colon') ], [],
          'unparseable value yields no maps');

# --- get_maps_files (path extraction) --------------------------------------
is_deeply([ get_maps_files('hash:/etc/postfix/aliases,hash:/etc/aliases') ],
          [ '/etc/postfix/aliases', '/etc/aliases' ],
          'get_maps_files extracts both file paths');
is_deeply([ get_maps_files('static:foo') ], [],
          'get_maps_files ignores non-path map values');

# --- get_current_value (main.cf parser) ------------------------------------
is(get_current_value('myhostname', 1), 'mail.example.com',
   'single-line parameter parsed');
my $dest = get_current_value('mydestination', 1);
like($dest, qr/example\.com/, 'continuation line: first value present');
like($dest, qr/localhost/,    'continuation line: trailing value joined');
is(get_current_value('no_such_param', 1), undef,
   'unknown parameter with nodef returns undef (no postconf fallback)');
is(get_current_value('subtest:key1', 1), 'valueA',
   'sub-parameter extraction (foo:bar) returns value after the key');

# --- resolve_current_value (compatibility_level conditionals) --------------
# Exercises the operator-dispatch rewrite of the old stringy eval.
is(resolve_current_value('util_lt'), 'old',
   'resolve "<": level 2 is < 3, takes true branch');
is(resolve_current_value('util_ge'), 'low',
   'resolve ">=": level 2 is not >= 3, takes false branch');
is(resolve_current_value('util_eq'), 'match',
   'resolve "==": level 2 == 2, takes true branch');
is(resolve_current_value('myhostname'), 'mail.example.com',
   'resolve passes through a plain value unchanged');

# --- master.cf parser + serializer -----------------------------------------
my $master = get_master_config();
is(ref($master), 'ARRAY', 'get_master_config returns array ref');
is(scalar(@$master), 3, 'three service entries parsed');

my ($smtp)   = grep { $_->{'name'} eq 'smtp' } @$master;
my ($qmgr)   = grep { $_->{'name'} eq 'qmgr' } @$master;
my ($pickup) = grep { $_->{'name'} eq 'pickup' } @$master;

ok($smtp,  'smtp service parsed');
ok($smtp->{'enabled'}, 'smtp is enabled');
is($smtp->{'type'},    'inet', 'smtp type');
is($smtp->{'chroot'},  'y',    'smtp chroot column');
is($smtp->{'command'}, 'smtpd','smtp command');

ok($qmgr, 'commented service still parsed');
ok(!$qmgr->{'enabled'}, 'commented service is disabled');

ok($pickup, 'pickup service parsed');
is($pickup->{'command'}, 'pickup -o content_filter=foo',
   'continuation line appended to command');

# master_line round-trips an entry back to its on-disk form
is(master_line($smtp),
   "smtp\tinet\tn\t-\ty\t-\t-\tsmtpd",
   'master_line serializes an enabled service with tabs');
is(master_line($qmgr),
   "#qmgr\tunix\tn\t-\tn\t300\t1\tqmgr",
   'master_line prefixes a disabled service with #');

# --- is_table_comment / make_table_comment ---------------------------------
{
    local $config{'prefix_cmts'} = 0;
    is(is_table_comment('# hello world'), 'hello world',
       'plain comment text extracted when prefix_cmts off');
    is_deeply([ make_table_comment('a note') ], [ '# a note' ],
       'make_table_comment emits a plain # line');
    is_deeply([ make_table_comment('') ], [],
       'make_table_comment emits nothing for empty comment');
}
{
    local $config{'prefix_cmts'} = 1;
    is(is_table_comment('# Webmin: tagged'), 'tagged',
       'Webmin-tagged comment extracted when prefix_cmts on');
    is(is_table_comment('# untagged'), undef,
       'untagged comment ignored when prefix_cmts on');
    is_deeply([ make_table_comment('z') ], [ '# Webmin: z' ],
       'make_table_comment emits a Webmin-tagged line when prefix_cmts on');
}

# --- in_props --------------------------------------------------------------
is(in_props([ qw(cn foo objectClass top) ], 'objectClass'), 'top',
   'in_props returns value following a matched name');
is(in_props([ qw(cn foo) ], 'mail'), undef,
   'in_props returns undef for an absent name');
is(in_props([ qw(CN foo) ], 'cn'), 'foo',
   'in_props matches case-insensitively');

# --- get_ldap_key ----------------------------------------------------------
is_deeply([ get_ldap_key({}) ],
          [ 'mailacceptinggeneralid', '(mailacceptinggeneralid=*)' ],
          'get_ldap_key default attribute and filter');
is_deeply([ get_ldap_key({ 'query_filter' => 'mail=%s' }) ],
          [ 'mail', '(mail=*)' ],
          'get_ldap_key derives attribute and filter from query_filter');

# --- make_map_ldap_dn ------------------------------------------------------
{
    local $config{'ldap_doms'} = 1;       # allow sub-domain DNs
    local $config{'ldap_id'}   = undef;   # default to cn
    my $conf = { 'search_base' => 'dc=example,dc=com', 'scope' => 'sub' };
    is(make_map_ldap_dn({ 'name' => 'user@dom.com' }, $conf),
       'cn=user,cn=dom.com,dc=example,dc=com',
       'make_map_ldap_dn builds a per-user DN inside a domain');
    is(make_map_ldap_dn({ 'name' => '@dom.com' }, $conf),
       'cn=default,cn=dom.com,dc=example,dc=com',
       'make_map_ldap_dn builds a catch-all DN for a domain');
    is(make_map_ldap_dn({ 'name' => 'literal' }, $conf),
       'cn=literal,dc=example,dc=com',
       'make_map_ldap_dn builds a flat DN for a non-address name');
}

# --- get_backend_config ----------------------------------------------------
my $backend = "$confdir/mysql.cf";
open(my $bfh, ">", $backend) or die "backend: $!";
print $bfh "user = postfix\npassword = secret\n# a comment\nhosts = localhost\n";
close($bfh);
my $bc = get_backend_config($backend);
is($bc->{'user'},     'postfix',   'backend config user parsed');
is($bc->{'password'}, 'secret',    'backend config password parsed');
is($bc->{'hosts'},    'localhost', 'backend config hosts parsed');

# --- list_smtpd_restrictions (version-dependent constant) ------------------
my @restr = list_smtpd_restrictions();
ok((grep { $_ eq 'permit_mynetworks' } @restr),
   'smtpd restrictions include permit_mynetworks');
ok((grep { $_ eq 'reject_unknown_reverse_client_hostname' } @restr),
   '>= 2.3 uses reject_unknown_reverse_client_hostname');

done_testing();
