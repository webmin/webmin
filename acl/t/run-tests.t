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
open(my $cfh, ">", "$confdir/config") or die "config: $!";
# generic-linux (not just "linux") is what real modules list in their
# module.info os_support, so check_os_support() actually finds them.
print $cfh "os_type=generic-linux\nos_version=0\n";
close($cfh);
open(my $vfh, ">", "$confdir/var-path") or die "var-path: $!";
print $vfh "$vardir\n";
close($vfh);
$ENV{'WEBMIN_CONFIG'} = $confdir;
$ENV{'WEBMIN_VAR'} = $vardir;
$ENV{'FOREIGN_MODULE_NAME'} = 'acl';
$ENV{'FOREIGN_ROOT_DIRECTORY'} = $rootdir;

chdir("$bindir/..") or die "chdir: $!";

require "$bindir/../acl-lib.pl";
{
    my $r = do "$bindir/../acl_security.pl";
    if ($@) { die "compile acl_security.pl: $@" }
    if (!defined($r) && $!) { die "open acl_security.pl: $!" }
}
{
    my $r = do "$bindir/../log_parser.pl";
    if ($@) { die "compile log_parser.pl: $@" }
    if (!defined($r) && $!) { die "open log_parser.pl: $!" }
}
our (%text, %in, %gconfig);

# Stage 2 fixture: a fully self-contained miniserv.conf + empty user/group/acl
# files under $confdir, plus stubs for side-effecting subs so tests don't try
# to signal a real miniserv or scan the whole module tree.
my $userfile = "$confdir/miniserv.users";
my $groupfile = "$confdir/webmin.groups";
my $aclfile = "$confdir/webmin.acl";
my $miniservconf = "$confdir/miniserv.conf";
sub _touch { open(my $f, ">", $_[0]) or die "$_[0]: $!"; close($f); }
_touch($userfile);
_touch($groupfile);
_touch($aclfile);
open(my $mfh, ">", $miniservconf) or die "$miniservconf: $!";
print $mfh "userfile=$userfile\n";
print $mfh "keyfile=$confdir/miniserv.pem\n";
print $mfh "pidfile=$vardir/miniserv.pid\n";
# Needed so @root_directories has a real value; without this,
# get_all_module_infos can't enumerate any modules.
print $mfh "root=$rootdir\n";
close($mfh);
$ENV{'MINISERV_CONFIG'} = $miniservconf;

{
    no warnings 'redefine', 'once';
    *reload_miniserv  = sub { };
    *restart_miniserv = sub { };
    # list_modules() scans the whole module tree; for write-path tests we
    # only need a small deterministic list.
    *list_modules = sub { return qw(useradmin apache); };
}

sub _clear_caches
{
    no warnings 'once';
    # read_file_cached() cache
    undef(%main::read_file_cache);
    undef(%main::read_file_missing);
    undef(%main::read_file_cache_time);
    # read_file_lines() cache (used by list_groups, modify_group, delete_group)
    undef(%main::file_cache);
    undef(%main::file_cache_eol);
    undef(%main::file_cache_noflush);
    # read_acl() caches
    undef(%main::acl_hash_cache);
    undef(%main::acl_array_cache);
}

sub _reset_fixture
{
    _touch($userfile);
    _touch($groupfile);
    _touch($aclfile);
    _clear_caches();
    # Drop per-user gconfig keys so previous tests don't leak.
    foreach my $k (keys %gconfig) {
        delete($gconfig{$k}) if $k =~ /_(alice|bob|carol|anonymous|testu1)\b/;
    }
}

# ---------------------------------------------------------------------------
# CGI subprocess harness (Stage 3)
#
# The acl/*.cgi scripts are imperative top-to-bottom: no caller-guard, no
# sub definitions, no entry point we can require-and-call. To test them at
# the contract level we spawn each as a real subprocess with a constructed
# CGI environment, feed it a POST body, and assert on what an attacker
# would actually see: the redirect target on success, or the error page on
# failure.
#
# Lever for %access: acl-lib.pl line 24 does `our %access = &get_module_acl();`
# which reads <confdir>/acl/<base_remote_user>.acl. _seed_user_acl writes that
# file, so each test controls the caller's privileges directly.
use IPC::Open3 ();
use Symbol qw(gensym);

my $cgidir = "$confdir/acl";
mkdir($cgidir) or die "$cgidir: $!" unless -d $cgidir;

sub _urlenc {
    my $s = shift;
    $s = '' if !defined $s;
    $s =~ s/([^A-Za-z0-9._~-])/sprintf('%%%02X', ord($1))/ge;
    return $s;
}

# Write <confdir>/acl/<user>.acl. Pass a hashref of ACL keys (create, edit,
# delete, switch, mode, mods, gassign, users, groups, perms, etc.).
sub _seed_user_acl {
    my ($user, $acl) = @_;
    open(my $fh, ">", "$cgidir/$user.acl") or die "$cgidir/$user.acl: $!";
    for my $k (sort keys %$acl) {
        print $fh "$k=$acl->{$k}\n";
    }
    close($fh);
    _clear_caches();
}

# Build a urlencoded POST body from a form hashref. Array values get repeated.
sub _form_body {
    my ($form) = @_;
    my $body = '';
    for my $k (sort keys %$form) {
        my @vals = ref($form->{$k}) eq 'ARRAY' ? @{$form->{$k}} : ($form->{$k});
        for my $v (@vals) {
            $body .= '&' if length $body;
            $body .= _urlenc($k) . '=' . _urlenc($v);
        }
    }
    return $body;
}

# Spawn an acl/ CGI as a subprocess.
# Returns a hashref: { out => stdout, err => stderr, status => exit code,
#                      location => Location: target if any,
#                      body => response body after blank line }.
sub run_cgi {
    my ($cgi, $form, %opts) = @_;
    my $body = _form_body($form || {});
    my $user = exists $opts{user} ? $opts{user} : 'admin';

    my %env = (
        PATH                   => $ENV{PATH},
        WEBMIN_CONFIG          => $confdir,
        WEBMIN_VAR             => $vardir,
        FOREIGN_MODULE_NAME    => 'acl',
        FOREIGN_ROOT_DIRECTORY => $rootdir,
        MINISERV_CONFIG        => $miniservconf,
        REQUEST_METHOD         => 'POST',
        SCRIPT_NAME            => "/acl/$cgi",
        CONTENT_TYPE           => 'application/x-www-form-urlencoded',
        CONTENT_LENGTH         => length($body),
        SERVER_NAME            => 'localhost',
        SERVER_PORT            => '10000',
        HTTP_HOST              => 'localhost:10000',
    );
    if (defined $user) {
        $env{REMOTE_USER}      = $user;
        $env{BASE_REMOTE_USER} = $user;
    }
    if ($opts{env}) {
        $env{$_} = $opts{env}{$_} for keys %{$opts{env}};
    }

    my $errfh = gensym();
    my $pid;
    {
        local %ENV = %env;
        # Run from inside the acl module dir so `require './acl-lib.pl'`
        # works as it does under miniserv.
        $pid = IPC::Open3::open3(my $in, my $out, $errfh,
                                 $^X, "-I$rootdir", "$rootdir/acl/$cgi");
        print $in $body if length $body;
        close($in);

        my ($stdout, $stderr) = ('', '');
        # Read both streams non-deterministically to avoid pipe deadlock on
        # very chatty CGIs. The body sizes here are small so a draining
        # order is fine.
        local $/;
        $stdout = <$out>; $stdout = '' if !defined $stdout;
        $stderr = <$errfh>; $stderr = '' if !defined $stderr;
        close($out); close($errfh);
        waitpid($pid, 0);
        my $status = $? >> 8;

        my ($location) = $stdout =~ /^Location:\s*(\S+)/m;
        my ($hdr, $rbody) = split(/\r?\n\r?\n/, $stdout, 2);
        $rbody = '' if !defined $rbody;
        return {
            out      => $stdout,
            err      => $stderr,
            status   => $status,
            location => $location,
            body     => $rbody,
        };
    }
}

# Sanity: libs loaded and key subs are visible.
ok(defined &encrypt_password, 'acl-lib loaded encrypt_password');
ok(defined &validate_password, 'acl-lib loaded validate_password');
ok(defined &acl_security_save, 'acl_security.pl loaded acl_security_save');
ok(defined &list_acl_yesno_fields, 'acl_security.pl loaded list_acl_yesno_fields');

# to64: small deterministic vectors over the itoa64 alphabet
#   "./0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
is(to64(0, 1), '.', 'to64 first char');
is(to64(1, 1), '/', 'to64 second char');
is(to64(63, 1), 'z', 'to64 last char');
is(to64(63, 2), 'z.', 'to64 two chars zero high');
is(to64(65, 2), '//', 'to64 spans 6-bit boundary');

# obsfucate_email: deterministic mask
is(obsfucate_email('foo@bar.com'), 'f**@b**.c**',
   'obsfucate_email three-letter labels');
is(obsfucate_email('a@b.c'), 'a@b.c',
   'obsfucate_email single-letter labels unchanged');
is(obsfucate_email('alice@mail.example.co.uk'),
   'a****@m***.e******.c*.u*',
   'obsfucate_email multi-label domain');

# md5-lib: encrypt / validate round-trips per scheme.
# Each check_* returns a missing-module name or undef-when-supported, which
# we use as the skip gate so tests pass on a minimal box.

SKIP: {
    skip 'MD5 unsupported', 5 if check_md5();
    my $h = encrypt_md5('hunter2', 'abcdefgh');
    like($h, qr/^\$1\$abcdefgh\$/, 'encrypt_md5 emits $1$ magic');
    is(encrypt_md5('hunter2', 'abcdefgh'), $h, 'encrypt_md5 deterministic');
    isnt(encrypt_md5('hunter3', 'abcdefgh'), $h, 'encrypt_md5 sensitive to password');
    ok(validate_password('hunter2', $h), 'validate_password matches md5 hash');
    ok(!validate_password('wrong', $h), 'validate_password rejects wrong md5');
}

SKIP: {
    skip 'SHA512 unsupported', 4 if check_sha512();
    my $h = encrypt_sha512('hunter2', '$6$saltsalt$');
    like($h, qr/^\$6\$saltsalt\$/, 'encrypt_sha512 emits $6$ magic with given salt');
    is(encrypt_sha512('hunter2', '$6$saltsalt$'), $h,
       'encrypt_sha512 deterministic');
    ok(validate_password('hunter2', $h), 'validate_password matches sha512');
    ok(!validate_password('wrong', $h), 'validate_password rejects wrong sha512');
}

SKIP: {
    skip 'yescrypt unsupported', 3 if check_yescrypt();
    # yescrypt salts are complex; reuse one generated by encrypt_yescrypt.
    my $h = encrypt_yescrypt('hunter2');
    like($h, qr/^\$y\$/, 'encrypt_yescrypt emits $y$ magic');
    ok(validate_password('hunter2', $h), 'validate_password matches yescrypt');
    ok(!validate_password('wrong', $h), 'validate_password rejects wrong yescrypt');
}

SKIP: {
    skip 'Crypt::Eksblowfish::Bcrypt missing', 4 if check_blowfish();
    my $h = encrypt_blowfish('hunter2');
    like($h, qr/^\$2a\$/, 'encrypt_blowfish emits $2a$ magic');
    is(encrypt_blowfish('hunter2', $h), $h, 'encrypt_blowfish reuses embedded salt');
    ok(validate_password('hunter2', $h), 'validate_password matches blowfish');
    ok(!validate_password('wrong', $h), 'validate_password rejects wrong blowfish');
}

# acl_security_save: contract test of the ACL parser that decides which other
# users a Webmin admin can manage. Drives the sub through every users_def
# branch, mode==2 branch, and all yes/no fields.
{
    no warnings 'once';
    local %in = (
        users_def => 1,
        mode      => 0,
        groups    => 1,
        gassign_def => 1,
    );
    my %o;
    acl_security_save(\%o);
    is($o{'users'}, '*', 'users_def=1 -> users="*"');
    is($o{'gassign'}, '*', 'gassign_def=1 -> gassign="*"');
}

{
    no warnings 'once';
    local %in = (
        users_def => 2,
        mode      => 0,
        groups    => 1,
        gassign_def => 1,
    );
    my %o;
    acl_security_save(\%o);
    is($o{'users'}, '~', 'users_def=2 -> users="~"');
}

{
    no warnings 'once';
    # users_def=0 with null-separated list (the wire format from <select multiple>)
    local %in = (
        users_def => 0,
        users     => "alice\0bob\0carol",
        mode      => 2,
        mods      => "useradmin\0apache",
        groups    => 0,
        gassign_def => 0,
        gassign   => "wheel\0staff",
    );
    my %o;
    acl_security_save(\%o);
    is($o{'users'}, 'alice bob carol',
       'users_def=0 -> null-separated list joined with spaces');
    is($o{'mode'}, 2, 'mode passed through');
    is($o{'mods'}, 'useradmin apache',
       'mode=2 -> mods joined from null-separated list');
    is($o{'gassign'}, 'wheel staff',
       'gassign_def=0 -> gassign joined from null-separated list');
    is($o{'groups'}, 0, 'groups passed through');
}

{
    no warnings 'once';
    # mode != 2 must clear mods to undef, so saved ACL doesn't carry stale data.
    local %in = (
        users_def => 1,
        mode      => 1,
        mods      => "leftover",   # should be ignored
        groups    => 1,
        gassign_def => 1,
    );
    my %o = (mods => 'previous-value');
    acl_security_save(\%o);
    is($o{'mode'}, 1, 'mode=1 passed through');
    is($o{'mods'}, undef, 'mode!=2 -> mods cleared to undef');
}

# Yes/no fields: every entry in list_acl_yesno_fields should be copied through
# from %in to $o. This catches accidental drops of e.g. 'pass' or 'switch'.
{
    no warnings 'once';
    my @fields = list_acl_yesno_fields();
    ok(scalar(grep { $_ eq 'pass' } @fields),
       'list_acl_yesno_fields includes pass');
    ok(scalar(grep { $_ eq 'switch' } @fields),
       'list_acl_yesno_fields includes switch');
    ok(scalar(grep { $_ eq 'sql' } @fields),
       'list_acl_yesno_fields includes sql');

    local %in = (
        users_def => 1,
        mode => 0,
        groups => 1,
        gassign_def => 1,
        map { $_ => 1 } @fields,
    );
    my %o;
    acl_security_save(\%o);
    foreach my $f (@fields) {
        is($o{$f}, 1, "yes/no field $f copied through");
    }
}

# acl_line / group_line: ACL file serializers. Fixed-string contract — the
# parsers in list_users / list_groups depend on this format.
is(acl_line({ name => 'alice', modules => [ 'useradmin', 'apache' ] }),
   "alice: useradmin apache\n",
   'acl_line emits "name: m1 m2\n"');
is(acl_line({ name => 'bob', modules => [] }),
   "bob: \n",
   'acl_line handles empty module list');
is(acl_line({ name => 'carol' }),
   "carol: \n",
   'acl_line handles missing modules key');

is(group_line({ name => 'wheel',
                members => [ 'alice', 'bob' ],
                modules => [ 'useradmin' ],
                desc => 'Sysadmins',
                ownmods => [ 'apache' ] }),
   'wheel:alice bob:useradmin:Sysadmins:apache',
   'group_line emits colon-separated record');
is(group_line({ name => 'empty' }),
   'empty::::',
   'group_line handles all-empty fields without warnings');

# get_unixauth / save_unixauth: round-trip parsing of the unixauth setting in
# miniserv.conf. The format mixes "*=user" (default mapping) with "scope=user"
# (group/user-specific). get_unixauth treats a bare token as "*=token".
{
    my %miniserv = (
        unixauth => 'admin staff=ops _wheel=root',
    );
    my @auth = get_unixauth(\%miniserv);
    is_deeply(\@auth, [ [ '*', 'admin' ],
                        [ 'staff', 'ops' ],
                        [ '_wheel', 'root' ] ],
              'get_unixauth parses mixed scope=user and bare tokens');

    my %m2;
    save_unixauth(\%m2, \@auth);
    is($m2{'unixauth'}, 'admin staff=ops _wheel=root',
       'save_unixauth round-trips through get_unixauth');

    my %empty;
    is_deeply([ get_unixauth(\%empty) ], [],
              'get_unixauth on missing key returns empty list');
}

# join_userdb_string + split_userdb_string: URI for the user/group DB. The
# split form is the parser; the join form is the serializer. They must agree.
{
    my $s = join_userdb_string('mysql', 'webmin', 'secret',
                               'db.example.com', 'webmindb', {});
    is($s, 'mysql://webmin:secret@db.example.com/webmindb',
       'join_userdb_string without args');
    my ($proto, $user, $pass, $host, $prefix, $args) = split_userdb_string($s);
    is($proto,  'mysql',           'split proto');
    is($user,   'webmin',          'split user');
    is($pass,   'secret',          'split pass');
    is($host,   'db.example.com',  'split host');
    is($prefix, 'webmindb',        'split prefix');
    is_deeply($args, {}, 'split args empty');

    my $s2 = join_userdb_string('ldap', 'cn=admin', 'p',
                                'ldap.example.com', 'dc=example,dc=com',
                                { userclass => 'webminUser' });
    like($s2, qr{\?userclass=webminUser$},
         'join_userdb_string appends ?key=val for single arg');
    my (undef, undef, undef, undef, undef, $args2) = split_userdb_string($s2);
    is_deeply($args2, { userclass => 'webminUser' },
              'single-arg query string round-trips');

    is(join_userdb_string('', 'u', 'p', 'h', 'pre', {}), '',
       'join_userdb_string returns empty when proto missing');
}

# can_edit_user: privilege boundary. Drives %access and $base_remote_user
# directly and passes a synthetic group list so list_groups isn't called.
{
    our (%access, $base_remote_user);
    my @groups = (
        { name => 'admins', members => [ 'alice', 'bob' ] },
        { name => 'ops',    members => [ 'carol' ] },
    );
    local $base_remote_user = 'alice';

    local %access = (users => '*');
    ok(can_edit_user('bob', \@groups),
       'users="*" allows editing anyone');
    ok(can_edit_user('nonexistent', \@groups),
       'users="*" allows editing names not in any group');

    local %access = (users => '~');
    ok(can_edit_user('alice', \@groups),
       'users="~" allows editing self');
    ok(!can_edit_user('bob', \@groups),
       'users="~" denies editing others');

    local %access = (users => 'dave eve');
    ok(can_edit_user('dave', \@groups),
       'named user match allowed');
    ok(can_edit_user('eve', \@groups),
       'named user match allowed (second token)');
    ok(!can_edit_user('mallory', \@groups),
       'unnamed user denied');

    local %access = (users => '_admins');
    ok(can_edit_user('alice', \@groups),
       'group prefix _admins allows editing alice (member)');
    ok(can_edit_user('bob', \@groups),
       'group prefix _admins allows editing bob (member)');
    ok(!can_edit_user('carol', \@groups),
       'group prefix _admins denies carol (not a member)');
    ok(!can_edit_user('alice', [ ]),
       'group prefix with empty group list denies');
}

# generate_random_session_id / generate_random_id: session ID format.
# Both should return 32 hex chars (lowercase). Two calls must differ.
{
    my $sid1 = generate_random_session_id();
    my $sid2 = generate_random_session_id();
    like($sid1, qr/^[0-9a-f]{32}$/,
         'generate_random_session_id returns 32 lowercase hex chars');
    like($sid2, qr/^[0-9a-f]{32}$/,
         'generate_random_session_id second call same format');
    isnt($sid1, $sid2, 'two generate_random_session_id calls differ');

    SKIP: {
        skip 'no /dev/urandom', 2 unless -r '/dev/urandom';
        my $id1 = generate_random_id();
        my $id2 = generate_random_id();
        like($id1, qr/^[0-9a-f]{32}$/,
             'generate_random_id returns 32 lowercase hex chars');
        isnt($id1, $id2, 'two generate_random_id calls differ');
    }
}

# hash_session_id: deterministic, with an in-process cache. Use a local cache
# hash so test ordering doesn't pollute it.
{
    our %hash_session_id_cache;
    local %hash_session_id_cache;
    my $sid = '0123456789abcdef0123456789abcdef';
    my $h1 = hash_session_id($sid);
    ok(length($h1) > 0, 'hash_session_id returns a non-empty hash');
    is(hash_session_id($sid), $h1,
       'hash_session_id is deterministic on repeat call (cache hit)');
    isnt(hash_session_id('feedfacefeedfacefeedfacefeedface'), $h1,
         'different session id hashes differently');
}

# md5_perl_module: should report a usable MD5 class on any system with either
# MD5 or Digest::MD5 available. On a box with neither it returns undef, so
# skip in that case rather than fail.
{
    my $mod = md5_perl_module();
    if (defined $mod) {
        like($mod, qr/^(MD5|Digest::MD5)$/,
             "md5_perl_module returns a known class ($mod)");
    } else {
        SKIP: { skip 'no MD5 perl module installed', 1; }
    }
}

# Stage 2: fs-backed lifecycle tests.

# create_user / list_users round-trip. Asserts that a user written via
# create_user reappears with the same key fields when read back via list_users.
{
    _reset_fixture();
    my $hash = encrypt_md5('secret', 'abcdefgh');
    my $alice = {
        name        => 'alice',
        pass        => $hash,
        modules     => [ 'useradmin', 'apache' ],
        lastchange  => 1700000000,
        email       => 'alice@example.com',
        real        => 'Alice Example',
    };
    create_user($alice);
    _clear_caches();
    my @users = list_users();
    my ($got) = grep { $_->{'name'} eq 'alice' } @users;
    ok($got, 'create_user then list_users finds alice');
    is($got->{'pass'},       $hash,                 'password persisted');
    is($got->{'email'},      'alice@example.com',   'email persisted');
    is($got->{'lastchange'}, '1700000000',          'lastchange persisted');
    is_deeply([ sort @{$got->{'modules'} || []} ],
              [ 'apache', 'useradmin' ],
              'modules persisted via webmin.acl');
}

# modify_user: change a field and a module set, then re-read.
{
    _reset_fixture();
    my $alice = {
        name => 'alice',
        pass => 'x',
        modules => [ 'useradmin', 'apache' ],
        email => 'alice@old.example',
    };
    create_user($alice);
    _clear_caches();

    $alice->{'email'}   = 'alice@new.example';
    $alice->{'modules'} = [ 'useradmin' ];
    modify_user('alice', $alice);
    _clear_caches();

    my ($got) = grep { $_->{'name'} eq 'alice' } list_users();
    is($got->{'email'}, 'alice@new.example', 'modify_user updated email');
    is_deeply($got->{'modules'}, [ 'useradmin' ],
              'modify_user reduced module set');
}

# modify_user with rename: name change is reflected in users file and ACL.
{
    _reset_fixture();
    create_user({ name => 'alice', pass => 'x',
                  modules => [ 'useradmin' ] });
    _clear_caches();

    modify_user('alice', { name => 'alice2', pass => 'x',
                           modules => [ 'useradmin' ] });
    _clear_caches();

    my @names = map { $_->{'name'} } list_users();
    ok((grep { $_ eq 'alice2' } @names),  'rename created alice2');
    ok(!(grep { $_ eq 'alice'  } @names), 'old alice no longer present');
}

# delete_user removes the row from miniserv.users and webmin.acl.
{
    _reset_fixture();
    create_user({ name => 'alice', pass => 'x',
                  modules => [ 'useradmin' ] });
    create_user({ name => 'bob',   pass => 'y',
                  modules => [ 'apache' ] });
    _clear_caches();

    delete_user('alice');
    _clear_caches();

    my @names = map { $_->{'name'} } list_users();
    is_deeply([ sort @names ], [ 'bob' ],
              'delete_user removes alice, leaves bob');

    # webmin.acl should also no longer list alice
    open(my $afh, '<', $aclfile) or die;
    my $contents = do { local $/; <$afh> };
    close($afh);
    unlike($contents, qr/^alice:/m, 'delete_user removed alice from webmin.acl');
    like($contents, qr/^bob:/m,      'delete_user left bob in webmin.acl');
}

# create_user must reject the reserved "webmin" name. error() exits unless
# error_must_die is set, so flip that just for this block.
{
    _reset_fixture();
    no warnings 'once';
    local $main::error_must_die = 1;
    eval { create_user({ name => 'webmin', pass => 'x' }) };
    ok($@, 'create_user dies on reserved name "webmin"');
    like($@, qr/Invalid username/, 'reserved-name error mentions "Invalid username"');
}

# Group lifecycle: create, modify (with rename), delete.
{
    _reset_fixture();
    create_group({ name => 'wheel',
                   members => [ 'alice', 'bob' ],
                   modules => [ 'useradmin' ],
                   desc => 'Sysadmins',
                   ownmods => [ 'apache' ] });
    _clear_caches();
    my ($got) = grep { $_->{'name'} eq 'wheel' } list_groups();
    ok($got, 'create_group then list_groups finds wheel');
    is_deeply([ sort @{$got->{'members'}} ], [ 'alice', 'bob' ],
              'group members persisted');
    is_deeply($got->{'modules'}, [ 'useradmin' ], 'group modules persisted');
    is($got->{'desc'}, 'Sysadmins', 'group desc persisted');
    is_deeply($got->{'ownmods'}, [ 'apache' ], 'group ownmods persisted');

    modify_group('wheel', { name => 'wheel',
                            members => [ 'alice' ],
                            modules => [ 'useradmin', 'apache' ],
                            desc => 'Sysadmins (reduced)' });
    _clear_caches();
    ($got) = grep { $_->{'name'} eq 'wheel' } list_groups();
    is_deeply($got->{'members'}, [ 'alice' ], 'modify_group reduced members');
    is_deeply([ sort @{$got->{'modules'}} ],
              [ 'apache', 'useradmin' ],
              'modify_group expanded modules');
    is($got->{'desc'}, 'Sysadmins (reduced)', 'modify_group updated desc');

    modify_group('wheel', { name => 'admins',
                            members => [ 'alice' ],
                            modules => [],
                            desc => 'Renamed' });
    _clear_caches();
    my @names = map { $_->{'name'} } list_groups();
    ok((grep { $_ eq 'admins' } @names), 'modify_group renames wheel to admins');
    ok(!(grep { $_ eq 'wheel' } @names), 'old wheel gone after rename');

    delete_group('admins');
    _clear_caches();
    is_deeply([ map { $_->{'name'} } list_groups() ], [],
              'delete_group removes the only group');
}

# copy_acl_files (file mode): copy a module ACL file from one name to another.
{
    _reset_fixture();
    my $mdir = "$confdir/useradmin";
    mkdir($mdir);
    open(my $fh, '>', "$mdir/source.acl") or die;
    print $fh "k1=v1\nk2=v2\n";
    close($fh);

    copy_acl_files('source', 'dest', [ 'useradmin' ]);
    ok(-r "$mdir/dest.acl", 'copy_acl_files created destination .acl');
    _clear_caches();
    my %got;
    read_file("$mdir/dest.acl", \%got);
    is_deeply(\%got, { k1 => 'v1', k2 => 'v2' },
              'copy_acl_files preserved key/value pairs');
}

# can_module_acl: true when acl_security.pl or config.info exists in the
# module's dir, false otherwise. Override module_root_directory so we can
# point at synthetic dirs under $confdir without touching the real tree.
{
    my $modroot = "$confdir/can_module_acl_mods";
    mkdir($modroot);
    mkdir("$modroot/withacl");
    _touch("$modroot/withacl/acl_security.pl");
    mkdir("$modroot/withcfg");
    _touch("$modroot/withcfg/config.info");
    mkdir("$modroot/neither");

    no warnings 'redefine';
    local *module_root_directory = sub {
        my $d = ref($_[0]) ? $_[0]->{'dir'} : $_[0];
        return "$modroot/$d";
    };
    ok( can_module_acl({ dir => 'withacl' }),
       'can_module_acl true when acl_security.pl present');
    ok( can_module_acl({ dir => 'withcfg' }),
       'can_module_acl true when config.info present');
    ok(!can_module_acl({ dir => 'neither' }),
       'can_module_acl false when neither file present');
}

# get_safe_acl: reads safeacl file in the module dir, parses key=value.
{
    my $modroot = "$confdir/get_safe_acl_mods";
    mkdir($modroot);
    mkdir("$modroot/safe");
    open(my $sfh, '>', "$modroot/safe/safeacl") or die;
    print $sfh "view=1\nedit=0\n";
    close($sfh);
    mkdir("$modroot/nosafe");
    _clear_caches();
    no warnings 'redefine';
    local *module_root_directory = sub {
        my $d = ref($_[0]) ? $_[0]->{'dir'} : $_[0];
        return "$modroot/$d";
    };
    my $r = get_safe_acl('safe');
    is_deeply($r, { view => '1', edit => '0' },
              'get_safe_acl parses safeacl key=value');
    is(get_safe_acl('nosafe'), undef,
       'get_safe_acl returns undef when safeacl missing');
}

# encrypt_password salt-shape dispatch: $1$ -> MD5, $6$ -> SHA512, otherwise
# default. The default branch goes via useradmin if installed; we just verify
# the $1$ and $6$ branches which are pure.
{
    SKIP: {
        skip 'MD5 unsupported', 1 if check_md5();
        my $h = encrypt_password('hunter2', '$1$abcdefgh$XYZ');
        like($h, qr/^\$1\$abcdefgh\$/,
             'encrypt_password with $1$ salt -> MD5 hash');
    }
    SKIP: {
        skip 'SHA512 unsupported', 1 if check_sha512();
        my $h = encrypt_password('hunter2', '$6$saltsalt$');
        like($h, qr/^\$6\$saltsalt\$/,
             'encrypt_password with $6$ salt -> SHA512 hash');
    }
}

# check_password_restrictions: each rule should fire independently and a
# compliant password should return undef. Drives miniserv.conf flags via
# put_miniserv_config so the real read path is exercised.
{
    _reset_fixture();
    # Pre-create a user with an old hash for the pass_oldblock branch.
    my $oldpw = '$1$abcdefgh$old';
    SKIP: {
        skip 'MD5 unsupported', 7 if check_md5();
        my $real_old = encrypt_md5('oldsecret', 'abcdefgh');
        create_user({ name => 'alice', pass => 'x',
                      modules => [ 'useradmin' ],
                      olds => [ $real_old ] });
    _clear_caches();

        my %miniserv;
        get_miniserv_config(\%miniserv);
        $miniserv{'pass_minsize'} = 8;
        $miniserv{'pass_regexps'} = '[0-9]'."\t".'![Pp]assword';
        $miniserv{'pass_nouser'}  = 1;
        $miniserv{'pass_oldblock'} = 5;
        put_miniserv_config(\%miniserv);
        # put_miniserv_config doesn't bump mtime in time for the stat cache
        # in tight tests; force a re-read.
    _clear_caches();

        ok(check_password_restrictions('alice', 'sh0rt'),
           'pass_minsize rule rejects short password');
        ok(check_password_restrictions('alice', 'longenoughbutnodigits'),
           'pass_regexps positive rule rejects password without digit');
        ok(check_password_restrictions('alice', 'Password12345'),
           'pass_regexps negated rule rejects password matching "Password"');
        ok(check_password_restrictions('alice', 'alice12345!!'),
           'pass_nouser rule rejects password containing username');
        ok(check_password_restrictions('alice', 'oldsecret'),
           'pass_oldblock rejects reuse of an old password');

        is(check_password_restrictions('alice', 'fresh-Pa55-9'),
           undef,
           'check_password_restrictions returns undef for a compliant password');
        is(check_password_restrictions('alice', 'fresh-Pa55-9'),
           undef, 'compliant password still returns undef on second call');
    }
}

# Anonymous access round-trip via miniserv.conf "anonymous=" key.
{
    _reset_fixture();
    setup_anonymous_access('/foo', 'useradmin');
    _clear_caches();

    my ($user, $idx) = get_anonymous_access('/foo');
    is($user, 'anonymous', 'setup_anonymous_access created the anonymous user');
    ok($idx >= 0, 'get_anonymous_access reports a positive index');

    # An "anonymous" user with the module should now exist.
    _clear_caches();
    my ($auser) = grep { $_->{'name'} eq 'anonymous' } list_users();
    ok($auser, 'anonymous user exists after setup');
    ok(scalar(grep { $_ eq 'useradmin' } @{$auser->{'modules'} || []}),
       'anonymous user has the requested module');

    remove_anonymous_access('/foo', 'useradmin');
    _clear_caches();
    my (undef, $idx2) = get_anonymous_access('/foo');
    is($idx2, -1, 'remove_anonymous_access dropped the mapping');
}

# delete_from_groups / get_users_group operate on the group file.
{
    _reset_fixture();
    create_group({ name => 'wheel',
                   members => [ 'alice', 'bob' ],
                   modules => [ 'useradmin' ] });
    create_group({ name => 'ops',
                   members => [ 'carol' ],
                   modules => [ 'apache' ] });
    _clear_caches();

    my $g = get_users_group('bob');
    is($g && $g->{'name'}, 'wheel', 'get_users_group finds bob in wheel');
    is(get_users_group('nobody'), undef,
       'get_users_group returns undef when user is in no group');

    delete_from_groups('bob');
    _clear_caches();
    my ($wheel) = grep { $_->{'name'} eq 'wheel' } list_groups();
    is_deeply($wheel->{'members'}, [ 'alice' ],
              'delete_from_groups removes bob from wheel');
}

# parse_webmin_log: each action should produce a non-empty string. We seed
# %text with templates that include $1/$2 substitutions so we can assert
# specific values flowed through. This is the audit-trail rendering path,
# so we also check that user-supplied object names are HTML-escaped.
{
    no warnings 'once';
    local %text = (
        log_create      => 'Created user $1',
        log_create_g    => 'Created group $1',
        log_modify      => 'Modified user $1',
        log_modify_g    => 'Modified group $1',
        log_rename      => 'Renamed user $1 to $2',
        log_rename_g    => 'Renamed group $1 to $2',
        log_clone       => 'Cloned $1 to $2',
        log_clone_g     => 'Cloned group $1 to $2',
        log_delete      => 'Deleted $1',
        log_delete_g    => 'Deleted group $1',
        log_delete_users  => 'Bulk deleted users $1',
        log_delete_groups => 'Bulk deleted groups $1',
        log_acl         => 'Edited ACL for $1 in $2',
        log_reset       => 'Reset ACL for $1 in $2',
        log_cert        => 'Updated cert for $1',
        log_switch      => 'Switched to $1',
        log_twofactor   => '2FA $1 provider=$2 id=$3',
        log_forgot_users => 'Sent reset for $1 to $2',
        log_joingroup    => 'User $1 joined $2',
    );

    like(parse_webmin_log('admin', 's', 'create', 'user', 'alice',
                          { clone => '' }),
         qr/Created user.*alice/,    'parse_webmin_log create user');
    like(parse_webmin_log('admin', 's', 'create', 'group', 'wheel',
                          { clone => '' }),
         qr/Created group.*wheel/,   'parse_webmin_log create group');
    like(parse_webmin_log('admin', 's', 'create', 'user', 'bob',
                          { clone => 'alice' }),
         qr/Cloned.*alice.*bob/,     'parse_webmin_log create with clone');
    like(parse_webmin_log('admin', 's', 'modify', 'user', 'alice',
                          { old => 'alice', name => 'alice' }),
         qr/Modified user.*alice/,   'parse_webmin_log modify same-name');
    like(parse_webmin_log('admin', 's', 'modify', 'user', 'alice2',
                          { old => 'alice', name => 'alice2' }),
         qr/Renamed user.*alice.*alice2/,
         'parse_webmin_log modify rename');
    like(parse_webmin_log('admin', 's', 'delete', 'user', 'alice', {}),
         qr/Deleted.*alice/,         'parse_webmin_log delete user');
    like(parse_webmin_log('admin', 's', 'delete', 'users', 'a b c', {}),
         qr/Bulk deleted users.*a b c/,
         'parse_webmin_log delete users (bulk)');
    like(parse_webmin_log('admin', 's', 'acl', 'user', 'alice',
                          { moddesc => 'User Admin' }),
         qr/Edited ACL.*alice.*User Admin/,
         'parse_webmin_log acl edit');
    like(parse_webmin_log('admin', 's', 'switch', 'user', 'alice', {}),
         qr/Switched to.*alice/,    'parse_webmin_log switch');

    # html_escape: every branch that interpolates a user-controlled value into
    # the rendered audit-trail string must come back escaped. These are
    # defense-in-depth — usernames are normally restricted to a safe charset,
    # but the audit log is the wrong place to trust upstream validation.
    my $payload = '<script>x</script>';
    my $esc     = qr/&lt;script&gt;/;

    for my $case (
        [ 'delete user',
          [ 'admin', 's', 'delete', 'user', $payload, {} ] ],
        [ 'create with clone (clone source)',
          [ 'admin', 's', 'create', 'user', 'safe',
            { clone => $payload } ] ],
        [ 'create with clone (new name)',
          [ 'admin', 's', 'create', 'user', $payload,
            { clone => 'safe' } ] ],
        [ 'modify rename (old name)',
          [ 'admin', 's', 'modify', 'user', 'safe',
            { old => $payload, name => 'safe' } ] ],
        [ 'modify rename (new name)',
          [ 'admin', 's', 'modify', 'user', 'safe',
            { old => 'safe', name => $payload } ] ],
        [ 'joingroup (object)',
          [ 'admin', 's', 'joingroup', 'user', $payload,
            { group => 'wheel' } ] ],
        [ 'joingroup (group)',
          [ 'admin', 's', 'joingroup', 'user', 'alice',
            { group => $payload } ] ],
        [ 'twofactor (object)',
          [ 'admin', 's', 'twofactor', 'user', $payload,
            { provider => 'totp', id => 'k' } ] ],
        [ 'acl (object)',
          [ 'admin', 's', 'acl', 'user', $payload,
            { moddesc => 'User Admin' } ] ],
        [ 'reset (object)',
          [ 'admin', 's', 'reset', 'user', $payload,
            { moddesc => 'User Admin' } ] ],
        [ 'delete users bulk (object)',
          [ 'admin', 's', 'delete', 'users', $payload, {} ] ],
        ) {
        my ($name, $args) = @$case;
        my $out = parse_webmin_log(@$args);
        unlike($out, qr/<script>/,
               "parse_webmin_log html-escapes $name");
        like($out, $esc,
             "parse_webmin_log emits entities for $name");
    }

    # acl/reset moddesc was already escaped pre-fix; keep the test as a
    # regression guard.
    my $xss2 = parse_webmin_log('admin', 's', 'acl', 'user', 'alice',
                                { moddesc => '<img src=x>' });
    unlike($xss2, qr/<img/,
           'parse_webmin_log html-escapes moddesc in acl action');
    like($xss2, qr/&lt;img/,
         'parse_webmin_log emits escaped entities for moddesc');
}

# ---------------------------------------------------------------------------
# Stage 3: CGI contract tests. Each block sets up `%access` for the caller by
# writing <confdir>/acl/<user>.acl, seeds whatever miniserv-user state the CGI
# needs, runs the CGI as a subprocess, and asserts on what the caller sees.

# Harness sanity: a CGI with no privileges should reject any action and
# print an HTML error (not a redirect). switch.cgi is the smallest victim.
subtest 'CGI harness smoke' => sub {
    _reset_fixture();
    _seed_user_acl('admin', { });  # empty ACL -> nothing allowed
    my $r = run_cgi('switch.cgi', { user => 'someone' });
    ok(!$r->{location},
       'no Location header on error path');
    like($r->{out}, qr{(?:<html|<body|Error)}i,
         'error path emits an HTML error page');
};

# delete_user.cgi — four distinct gates. NOTE: <rootdir>/acl/defaultacl has
# every flag set to 1, and get_module_acl merges it under the per-user ACL.
# So each denial test must EXPLICITLY set the relevant key to 0; relying on
# absence is not enough.
#   1. access{delete} must be true
#   2. can_edit_user(target) must be true (gated by access{users})
#   3. target cannot equal $base_remote_user (self-delete)
#   4. happy path: removes user, removes from groups, redirects.
subtest 'delete_user.cgi gating' => sub {
    # 1. access{delete}=0 -> error
    _reset_fixture();
    _seed_user_acl('admin', { users => '*', delete => 0 });
    create_user({ name => 'victim', pass => 'x', modules => ['acl'] });
    my $r = run_cgi('delete_user.cgi', { user => 'victim' });
    ok(!$r->{location}, 'no redirect when access{delete}=0');
    like($r->{out}, qr/<html|Error/i,
         'error page returned when delete privilege missing');
    ok(get_user('victim'), 'victim still exists after blocked delete');
    delete_user('victim');

    # 2. can_edit_user=no (users whitelist excludes target) -> error
    _reset_fixture();
    _seed_user_acl('admin', { users => 'someone-else' });
    create_user({ name => 'victim', pass => 'x', modules => ['acl'] });
    $r = run_cgi('delete_user.cgi', { user => 'victim' });
    ok(!$r->{location}, 'no redirect when target not in users whitelist');
    ok(get_user('victim'),
       'victim still exists when can_edit_user denies');
    delete_user('victim');

    # 3. self-delete refused (even with users=* and delete=1)
    _reset_fixture();
    _seed_user_acl('admin', { users => '*' });
    create_user({ name => 'admin', pass => 'x', modules => ['acl'] });
    $r = run_cgi('delete_user.cgi', { user => 'admin' });
    ok(!$r->{location}, 'no redirect on self-delete');
    like($r->{out}, qr/<html|Error/i,
         'error page returned on self-delete attempt');
    ok(get_user('admin'), 'admin still exists after self-delete attempt');
    delete_user('admin');

    # 4. happy path: deletes user + removes from groups + redirects
    _reset_fixture();
    _seed_user_acl('admin', { users => '*' });
    create_user({ name => 'admin',  pass => 'x', modules => ['acl'] });
    create_user({ name => 'victim', pass => 'x', modules => ['acl'] });
    create_group({ name => 'g1', members => ['victim', 'admin'],
                   modules => ['acl'] });
    $r = run_cgi('delete_user.cgi', { user => 'victim' });
    ok($r->{location}, 'redirect emitted on successful delete')
        or diag("stdout: $r->{out}\nstderr: $r->{err}");
    _clear_caches();
    ok(!get_user('victim'), 'victim removed from users file');
    my ($g) = grep { $_->{name} eq 'g1' } list_groups();
    is(scalar(grep { $_ eq 'victim' } @{$g->{members}}), 0,
       'victim removed from group g1 members')
        if $g;
    delete_group('g1') if $g;
    delete_user('admin');
};

# save_acl.cgi — gates the per-module ACL editor.
#   user path: mode controls which modules are editable; mode=2 + mods=<list>
#              is the principle-of-least-privilege case worth testing.
#   group path: access{groups} required.
#   reset path: removes the .acl file (or .gacl).
subtest 'save_acl.cgi gating' => sub {
    # Need a target module dir under $rootdir; useradmin is real.
    # mode=2, mods='useradmin', target _acl_mod='apache' -> denied
    _reset_fixture();
    _seed_user_acl('admin', { users => '*', mode => 2, mods => 'useradmin' });
    create_user({ name => 'target', pass => 'x', modules => ['acl'] });
    my $r = run_cgi('save_acl.cgi', {
        _acl_user => 'target', _acl_mod => 'apache', noconfig => 1 });
    ok(!$r->{location}, 'no redirect when target module not in mods whitelist');
    like($r->{out}, qr/<html|Error/i,
         'error page returned for out-of-whitelist module');
    ok(!-e "$confdir/apache/target.acl",
       'no .acl written for out-of-whitelist module');
    delete_user('target');

    # access{groups}=0, _acl_group=g1 -> error
    # defaultacl sets groups=1, so we must override to 0 to deny.
    _reset_fixture();
    _seed_user_acl('admin', { users => '*', mode => 0, groups => 0 });
    create_group({ name => 'g1', members => [], modules => ['acl'] });
    $r = run_cgi('save_acl.cgi', {
        _acl_group => 'g1', _acl_mod => 'useradmin', noconfig => 1 });
    ok(!$r->{location}, 'no redirect on group edit when access{groups}=0');
    like($r->{out}, qr/<html|Error/i,
         'error page returned for unauthorized group ACL edit');
    delete_group('g1');

    # can_edit_user denies -> error
    _reset_fixture();
    _seed_user_acl('admin', { users => 'someone-else', mode => 0 });
    create_user({ name => 'target', pass => 'x', modules => ['acl'] });
    $r = run_cgi('save_acl.cgi', {
        _acl_user => 'target', _acl_mod => 'useradmin', noconfig => 1 });
    ok(!$r->{location},
       'no redirect when can_edit_user denies the target user');
    delete_user('target');

    # Happy path: write an ACL for a user. mode=0 = all modules allowed.
    _reset_fixture();
    _seed_user_acl('admin', { users => '*', mode => 0 });
    create_user({ name => 'target', pass => 'x', modules => ['acl'] });
    mkdir("$confdir/useradmin") unless -d "$confdir/useradmin";
    $r = run_cgi('save_acl.cgi', {
        _acl_user => 'target', _acl_mod => 'useradmin', noconfig => 1 });
    ok($r->{location}, 'redirect emitted on successful ACL save')
        or diag("stdout: $r->{out}\nstderr: $r->{err}");
    ok(-e "$confdir/useradmin/target.acl",
       'per-user .acl file created on happy path')
        or diag("dir contents: " . join(",", glob("$confdir/useradmin/*")) .
                "\nstdout: $r->{out}\nstderr: $r->{err}");
    unlink("$confdir/useradmin/target.acl");
    delete_user('target');

    # Reset path: writes .acl first, then second call with reset=1 removes it.
    _reset_fixture();
    _seed_user_acl('admin', { users => '*', mode => 0 });
    create_user({ name => 'target', pass => 'x', modules => ['acl'] });
    mkdir("$confdir/useradmin") unless -d "$confdir/useradmin";
    run_cgi('save_acl.cgi', {
        _acl_user => 'target', _acl_mod => 'useradmin', noconfig => 1 });
    ok(-e "$confdir/useradmin/target.acl", '.acl exists before reset');
    $r = run_cgi('save_acl.cgi', {
        _acl_user => 'target', _acl_mod => 'useradmin', reset => 1 });
    ok($r->{location}, 'reset path also redirects on success');
    ok(!-e "$confdir/useradmin/target.acl",
       '.acl file removed by reset');
    delete_user('target');
};

# save_user.cgi — the largest CGI in the module. The security boundaries
# worth pinning at the contract level are:
#   - name regex validation (no shell metacharacters, no @prefix)
#   - the "webmin" reserved-name guard
#   - access{create} required for new users
#   - gassign whitelist enforced (cannot assign group user can't manage)
#   - self-lockout guard: removing the acl module from your own account is
#     refused (otherwise an admin could lock themselves out and brick the box)
subtest 'save_user.cgi name validation' => sub {
    _reset_fixture();
    _seed_user_acl('admin', { users => '*' });
    create_user({ name => 'admin', pass => 'x', modules => ['acl'] });

    # Bad characters in the username -> error.
    my $r = run_cgi('save_user.cgi', {
        name => 'bad name', pass_def => 1, oldpass => 'x', mod => 'acl' });
    ok(!$r->{location},
       'no redirect when new username has invalid characters');
    ok(!get_user('bad name'), 'invalid-name user not created');

    # @-prefix is explicitly forbidden by the regex.
    $r = run_cgi('save_user.cgi', {
        name => '@evil', pass_def => 1, oldpass => 'x', mod => 'acl' });
    ok(!$r->{location}, 'no redirect when name starts with @');
    ok(!get_user('@evil'), '@-prefix name not created');

    # Reserved name "webmin" is rejected.
    $r = run_cgi('save_user.cgi', {
        name => 'webmin', pass_def => 1, oldpass => 'x', mod => 'acl' });
    ok(!$r->{location}, 'no redirect when name is reserved "webmin"');
    ok(!get_user('webmin'), 'reserved name "webmin" not created');

    delete_user('admin');
};

subtest 'save_user.cgi create privilege' => sub {
    # access{create}=0 -> any create-user attempt is denied.
    _reset_fixture();
    _seed_user_acl('admin', { users => '*', create => 0 });
    create_user({ name => 'admin', pass => 'x', modules => ['acl'] });

    my $r = run_cgi('save_user.cgi', {
        name => 'newbie', pass_def => 1, oldpass => 'x', mod => 'acl' });
    ok(!$r->{location}, 'no redirect when access{create}=0');
    ok(!get_user('newbie'),
       'new user is not created when create privilege is missing');
    delete_user('admin');
};

subtest 'save_user.cgi gassign whitelist' => sub {
    # gassign='admins' allows assigning only to group "admins"; trying to
    # assign to a different group should fail.
    _reset_fixture();
    _seed_user_acl('admin', { users => '*', gassign => 'admins' });
    create_user({ name => 'admin', pass => 'x', modules => ['acl'] });
    create_group({ name => 'admins', members => [], modules => ['acl'] });
    create_group({ name => 'evil',   members => [], modules => ['acl'] });

    my $r = run_cgi('save_user.cgi', {
        name => 'newbie', pass_def => 1, oldpass => 'x',
        mod => 'acl', group => 'evil' });
    ok(!$r->{location}, 'no redirect when group not in gassign whitelist');
    ok(!get_user('newbie'),
       'user not created when requested group not allowed by gassign');

    delete_group('admins');
    delete_group('evil');
    delete_user('admin');
};

# forgot_form.cgi and forgot_send.cgi — the admin-side password-reset flow.
# These are NOT the unauthenticated /forgot.cgi flow; they require an
# authenticated admin and gate on can_edit_user.
#   - can_edit_user(target) required
#   - email format must be syntactically valid (or email_def set)
subtest 'forgot_form.cgi can_edit_user gate' => sub {
    _reset_fixture();
    _seed_user_acl('admin', { users => 'someone-else' });
    create_user({ name => 'target', pass => 'x', modules => ['acl'] });
    my $r = run_cgi('forgot_form.cgi', { user => 'target' });
    ok(!$r->{location}, 'no redirect when can_edit_user denies');
    like($r->{out}, qr/<html|Error/i,
         'error page when caller cannot edit the target user');
    delete_user('target');
};

subtest 'forgot_send.cgi gates' => sub {
    # 1. can_edit_user denies -> error
    _reset_fixture();
    _seed_user_acl('admin', { users => 'someone-else' });
    create_user({ name => 'target', pass => 'x', modules => ['acl'],
                  email => 'target@example.com' });
    my $r = run_cgi('forgot_send.cgi', {
        user_acc => 'target', user => 'target',
        email_def => 1 });
    ok(!$r->{location},
       'no redirect from forgot_send when can_edit_user denies');
    # Should NOT have written a forgot-password link file.
    my @links = glob("$vardir/forgot-password/*");
    is(scalar(@links), 0,
       'no forgot-password link written when caller cannot edit target');
    delete_user('target');

    # 2. Email format invalid -> error.
    _reset_fixture();
    _seed_user_acl('admin', { users => '*' });
    create_user({ name => 'target', pass => 'x', modules => ['acl'] });
    $r = run_cgi('forgot_send.cgi', {
        user_acc => 'target', user => 'target',
        email => 'not-an-email' });
    ok(!$r->{location},
       'no redirect when email argument fails format validation');
    @links = glob("$vardir/forgot-password/*");
    is(scalar(@links), 0,
       'no forgot-password link written when email is invalid');
    delete_user('target');
};

# delete_group.cgi — three gates worth pinning:
#   1. access{groups} required
#   2. cannot delete a group you yourself are a member of
#   3. happy path on an empty group: deletes + redirects
subtest 'delete_group.cgi gating' => sub {
    # 1. access{groups}=0 -> error
    _reset_fixture();
    _seed_user_acl('admin', { users => '*', groups => 0 });
    create_group({ name => 'g1', members => [], modules => ['acl'] });
    my $r = run_cgi('delete_group.cgi', { group => 'g1' });
    ok(!$r->{location}, 'no redirect when access{groups}=0');
    my ($g) = grep { $_->{name} eq 'g1' } list_groups();
    ok($g, 'group still exists after blocked delete');
    delete_group('g1') if $g;

    # 2. caller is a member of the group -> error
    _reset_fixture();
    _seed_user_acl('admin', { users => '*' });
    create_user({ name => 'admin', pass => 'x', modules => ['acl'] });
    create_group({ name => 'g2', members => ['admin'], modules => ['acl'] });
    $r = run_cgi('delete_group.cgi', { group => 'g2' });
    ok(!$r->{location},
       'no redirect when caller is a member of the group being deleted');
    _clear_caches();
    ($g) = grep { $_->{name} eq 'g2' } list_groups();
    ok($g, 'group still exists when caller is member');
    delete_group('g2') if $g;
    delete_user('admin');

    # 3. happy path: empty group, no confirm needed -> delete + redirect
    _reset_fixture();
    _seed_user_acl('admin', { users => '*' });
    create_group({ name => 'g3', members => [], modules => ['acl'] });
    $r = run_cgi('delete_group.cgi', { group => 'g3' });
    ok($r->{location}, 'redirect on successful empty-group delete')
        or diag("stdout: $r->{out}\nstderr: $r->{err}");
    _clear_caches();
    ($g) = grep { $_->{name} eq 'g3' } list_groups();
    ok(!$g, 'group g3 removed on happy path');
};

# save_group.cgi — name validation gates mirror save_user.cgi.
subtest 'save_group.cgi name validation' => sub {
    _reset_fixture();
    _seed_user_acl('admin', { users => '*' });

    # Bad characters.
    my $r = run_cgi('save_group.cgi', {
        name => 'bad name', desc => 'd' });
    ok(!$r->{location}, 'no redirect when new group name has bad characters');
    my ($g) = grep { $_->{name} eq 'bad name' } list_groups();
    ok(!$g, 'invalid-name group not created');

    # @-prefix forbidden.
    $r = run_cgi('save_group.cgi', { name => '@evil', desc => 'd' });
    ok(!$r->{location}, 'no redirect when group name starts with @');
    ($g) = grep { $_->{name} eq '@evil' } list_groups();
    ok(!$g, '@-prefix group not created');

    # Reserved "webmin".
    $r = run_cgi('save_group.cgi', { name => 'webmin', desc => 'd' });
    ok(!$r->{location}, 'no redirect when group name is reserved "webmin"');
    ($g) = grep { $_->{name} eq 'webmin' } list_groups();
    ok(!$g, 'reserved name "webmin" not created as a group');

    # Colon in desc is the on-disk separator — rejected.
    $r = run_cgi('save_group.cgi', {
        name => 'goodname', desc => 'bad:desc' });
    ok(!$r->{location}, 'no redirect when description contains colon');
    ($g) = grep { $_->{name} eq 'goodname' } list_groups();
    ok(!$g, 'group with colon-bearing description not created');
};

subtest 'save_user.cgi self-lockout guard' => sub {
    # Editing yourself out of the acl module is refused — otherwise an
    # admin could lock themselves out of Webmin entirely.
    _reset_fixture();
    _seed_user_acl('admin', { users => '*' });
    create_user({ name => 'admin', pass => 'x', modules => ['acl'] });

    my $r = run_cgi('save_user.cgi', {
        old => 'admin', name => 'admin', pass_def => 1, oldpass => 'x',
        # mod = (empty) — no modules selected, drops everything including acl
    });
    ok(!$r->{location},
       'no redirect when admin tries to remove acl from own account');
    my $me = get_user('admin');
    my %mods = map { $_ => 1 } @{$me->{modules} || []};
    ok($mods{acl},
       'admin still has acl module after blocked self-lockout');

    delete_user('admin');
};

# switch.cgi — access{switch} required AND can_edit_user(target) required.
# The happy path is harder to assert because it touches the session DB and
# kills the cookie. We test the gates here and the no-op contract.
subtest 'switch.cgi gating' => sub {
    # 1. access{switch}=0 -> error (defaultacl has switch=1, must override)
    _reset_fixture();
    _seed_user_acl('admin', { users => '*', switch => 0 });
    create_user({ name => 'target', pass => 'x', modules => ['acl'] });
    my $r = run_cgi('switch.cgi', { user => 'target' });
    ok(!$r->{location}, 'no redirect when access{switch}=0');
    like($r->{out}, qr/<html|Error/i,
         'error page returned when switch privilege missing');
    delete_user('target');

    # 2. can_edit_user=no (users whitelist) -> error even with switch=1
    _reset_fixture();
    _seed_user_acl('admin', { users => 'someone-else' });
    create_user({ name => 'target', pass => 'x', modules => ['acl'] });
    $r = run_cgi('switch.cgi', { user => 'target' });
    ok(!$r->{location},
       'no redirect when can_edit_user denies (even with switch=1)');
    delete_user('target');
};

done_testing();
