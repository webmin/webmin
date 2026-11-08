#!/usr/bin/perl
# Exercise the real account and group save handlers with isolated storage.
use strict;
use warnings;
no warnings qw(once redefine uninitialized);
use Test::More;
use File::Temp qw(tempdir);
use FindBin;
BEGIN {
    # Skip this suite if the SQLite Perl drivers are unavailable.
    eval { require DBI; require DBD::SQLite; 1 }
        or plan skip_all => 'DBI and DBD::SQLite are required';
}
require "$FindBin::Bin/../web-lib-funcs.pl";
our ($config_directory, $base_remote_user, %in, %access, %text, %gconfig,
     $db, $proto);
$base_remote_user = 'admin';
$text{acl_eapi_only} = 'Invalid API endpoint';
# load_routine(file, name): load production helpers without host initialization.
sub load_routine {
    my ($file, $name) = @_;
    # Load from the named routine to the next POD section or end of file.
    # Include any following CGI helpers within that section.
    open(my $fh, '<', "$FindBin::Bin/../$file") or die $!;
    local $/; my $routine_source = <$fh>;
    $routine_source =~ /^(sub \Q$name\E\n\{.*?)(?=^=head2|\z)/ms or die "Missing $name";
    eval "no strict; $1"; die $@ if $@;
}
# Load real storage and validation helpers while replacing host integration.
load_routine('web-lib.pl', 'unique');
load_routine('acl/acl-lib.pl', $_) for qw(
    create_group modify_group list_groups get_group group_line update_members
    copy_acl_files copy_group_acl_files copy_group_user_acl_files set_acl_files
    create_user modify_user list_users get_user get_users_group acl_line add_old_password);
load_routine('acl_security.pl', 'acl_security_save');
# get_userdb_string(): select the current fixture's file or SQL backend.
*main::get_userdb_string = sub { return $proto ? "$proto://fixture" : ''; };
# get_miniserv_config(&config): provide only sandbox storage settings.
*main::get_miniserv_config = sub {
    %{$_[0]} = (userdb => get_userdb_string(), userfile => "$config_directory/miniserv.users");
};
# put_miniserv_config(&config): skip server configuration writes.
*main::put_miniserv_config = sub {};
# connect_userdb(url): route SQL operations to the isolated SQLite connection.
*main::connect_userdb = sub { return ($db, $proto); };
# disconnect_userdb(url, &db): preserve the connection for later assertions.
*main::disconnect_userdb = sub {};
# module_root_directory([module]): read defaults only from the fixture tree.
*main::module_root_directory = sub { return $config_directory; };
# get_module_preferences_acl(module, key): disable preference overrides.
*main::get_module_preferences_acl = sub { return undef; };
# list_modules(): expose the single module used in inherited permission tests.
*main::list_modules = sub { return ('example'); };
# acl_filename(): return the isolated module access list.
*main::acl_filename = sub { return "$config_directory/webmin.acl"; };
# foreign_require(module, file): helpers were loaded explicitly above.
*main::foreign_require = sub {};
# foreign_call(module, routine, args...): allow only real ACL form validation.
*main::foreign_call = sub {
    my ($module, $routine, @args) = @_;
    die "Unexpected foreign call $module:$routine" unless $routine eq 'acl_security_save';
    return acl_security_save(@args);
};
# foreign_check(module, [api-only]): suppress unrelated module integrations.
*main::foreign_check = sub { return 0; };
# can_edit_user(user, [&groups]): allow the fixture administrator to edit users.
*main::can_edit_user = sub { return 1; };
# check_password_restrictions(user, password): accept fixture passwords.
*main::check_password_restrictions = sub { return undef; };
# encrypt_password(password, [salt]): use a fixed salt for repeatable checks.
*main::encrypt_password = sub { return crypt($_[0], 'ZZ'); };
# set_ownership_permissions(user, group, mode, files...): avoid host chown.
*main::set_ownership_permissions = sub {};
# error(messages...): expose save failures as exceptions for run_cgi().
*main::error = sub { die join('', @_)."\n"; };
# text(key, [values...]): keep errors readable without translation files.
*main::text = sub { return join(': ', @_); };
# Prevent the CGI from reloading helpers and initializing host configuration.
$INC{'./acl-lib.pl'} = 1;
# ReadParse(): run_cgi() supplies the form fields directly in %in.
*main::ReadParse = sub {};
# error_setup(message): assertions inspect the error without an HTML wrapper.
*main::error_setup = sub {};
# reload_miniserv(): no server process is used by these handler tests.
*main::reload_miniserv = sub {};
# webmin_log(args...): avoid writing host audit logs.
*main::webmin_log = sub {};
# redirect(url): suppress the handler's HTTP redirect.
*main::redirect = sub { return 1; };
# reset_fixture(backend): use files for '' or SQLite for the 'mysql' code path.
sub reset_fixture {
    ($proto) = @_;
    # Start each case with fresh account files and no cached permissions.
    $config_directory = tempdir(DIR => '/tmp', CLEANUP => 1);
    $ENV{MINISERV_CONFIG} = "$config_directory/miniserv.conf";
    for my $name (qw(miniserv.conf miniserv.users webmin.acl webmin.groups config)) {
        open(my $fh, '>', "$config_directory/$name") or die $!; close($fh);
    }
    %main::read_file_cache = (); %main::read_file_missing = (); %gconfig = ();
    # Reproduce the user/group tables needed by the real storage helpers.
    $db = DBI->connect('dbi:SQLite:dbname=:memory:', '', '',
        {RaiseError => 0, PrintError => 0, AutoCommit => 1});
    for my $kind ('user', 'group') {
        $db->do("create table webmin_$kind (id integer primary key, name text, pass text, description text)");
        $db->do("create table webmin_${kind}_attr (id integer, attr text, value text)");
        $db->do("create table webmin_${kind}_acl (id integer, module text, attr text, value text, primary key(id,module,attr))");
    }
    %access = (groups => 1, acl => 1, gassign => '*', create => 1, users => '*');
}
# group_fixture(name, [members], [endpoint]): create a stored group policy.
# Defaults to no members and no API-only restriction.
sub group_fixture {
    my ($name, $members, $endpoint) = @_;
    create_group({name => $name, desc => 'original', modules => ['example'], members => $members || []});
    save_group_module_acl({api_only => $endpoint || '', rpc => 0}, $name, '', 1);
}
# run_cgi(name, &parameters): run acl/name.cgi and return its exception text.
sub run_cgi {
    my ($name, $params) = @_;
    %in = %$params;
    do "$FindBin::Bin/../acl/$name.cgi";
    return $@;
}

# The same form submissions must preserve policy in file and SQL storage.
for my $backend ('', 'mysql') {
    my $label = $backend || 'files';
    subtest "$label parent assignment restricts the group and its members" => sub {
        reset_fixture($backend);
        create_user({name => 'member', pass => '*LK*', modules => ['example']});
        group_fixture('parent', [], 'virtual-server/remote.cgi');
        group_fixture('child', ['member'], '');
        # Submit a stale unrestricted form when assigning a restricted parent.
        is(run_cgi('save_group', {old => 'child', name => 'child', group => 'parent', mod => 'example', acl_security_form => 1, api_only_def => 1}), '', 'reparenting succeeds');
        my %acl = get_group_module_acl('child', '', 1);
        is($acl{api_only}, 'virtual-server/remote.cgi', 'stale unrestricted form cannot clear inherited policy');
        my %member = get_module_acl('member', '', 1, 1);
        is($member{api_only}, 'virtual-server/remote.cgi', 'existing member inherits effective policy');
    };
    subtest "$label requested endpoint survives group assignment" => sub {
        reset_fixture($backend); group_fixture('ordinary', [], '');
        # An explicit endpoint survives inheritance from an unrestricted group.
        is(run_cgi('save_user', {name => 'newuser', group => 'ordinary', mod => 'example', pass_def => 0, pass => 'fixture-only-password', acl_security_form => 1, api_only_def => 0, api_only => 'virtual-server/remote.cgi', rpc => 0}), '', 'user creation succeeds');
        ok(get_user('newuser'), 'new user exists');
        my %acl = get_module_acl('newuser', '', 1, 1);
        is($acl{api_only}, 'virtual-server/remote.cgi', 'requested endpoint is saved');
        is($acl{rpc}, 0, 'other global permissions still come from the group');
        # Successful ACL writes must release both temporary login restrictions.
        is(get_user('newuser')->{pass}, crypt('fixture-only-password', get_user('newuser')->{pass}), 'successful account is activated');
        ok(!get_user('newuser')->{deny}, 'temporary IP denial is removed');
    };
    subtest "$label existing ungrouped user requests endpoint and group" => sub {
        reset_fixture($backend); group_fixture('ordinary', [], '');
        create_user({name => 'existing', pass => '!fixture', modules => ['example']});
        # Joining a group must retain an existing user's requested endpoint.
        is(run_cgi('save_user', {old => 'existing', name => 'existing', group => 'ordinary',
            mod => 'example', pass_def => 0, pass => 'fixture-only-password',
            acl_security_form => 1, api_only_def => 0,
            api_only => 'other/api.cgi', rpc => 1}), '', 'existing account can join group');
        my %acl = get_module_acl('existing', '', 1, 1);
        is($acl{api_only}, 'other/api.cgi', 'explicit endpoint survives assignment');
        is($acl{rpc}, 0, 'ordinary group permissions are retained');
    };
}

subtest 'failed SQL policy write leaves disabled user' => sub {
    reset_fixture('mysql');
    # Fail only the endpoint write, after the account itself has been created.
    $db->do(q{create trigger fail_policy before insert on webmin_user_acl when new.attr = 'api_only' begin select raise(abort, 'fixture endpoint insert failure'); end});
    my $err = run_cgi('save_user', {name => 'partial', mod => 'example', pass_def => 0, pass => 'fixture-only-password', acl_security_form => 1, api_only_def => 0, api_only => 'virtual-server/remote.cgi', rpc => 1});
    like($err, qr/fixture endpoint insert failure/, 'real SQL write fails as injected');
    # The incomplete account can be repaired but cannot authenticate.
    my $user = get_user('partial');
    ok($user, 'failed account remains available for repair');
    like($user->{pass}, qr/^!/, 'password remains locked');
    is($user->{deny}, '0.0.0.0/0 ::/0', 'IP-based login is also denied');
    my %acl = get_module_acl('partial', '', 1, 1);
    ok(!$acl{api_only}, 'failed write leaves no endpoint');
};

subtest 'invalid endpoint is rejected before group changes' => sub {
    reset_fixture('mysql'); group_fixture('before', [], '');
    # Validation must precede both the rename and the description update.
    my $err = run_cgi('save_group', {old => 'before', name => 'after', desc => 'changed', mod => 'example', acl_security_form => 1, api_only_def => 0, api_only => '../rpc.cgi'});
    like($err, qr/Invalid API endpoint/, 'validation rejects endpoint');
    ok(get_group('before') && !get_group('after'), 'rejected request does not rename group');
    is(get_group('before')->{desc}, 'original', 'rejected request does not change description');
};

# A hidden parent selector must not detach inherited permissions.
for my $backend ('', 'mysql') {
    subtest 'omitted subgroup parent on '.($backend || 'files') => sub {
        # The editor cannot change the parent, so the form omits that field.
        reset_fixture($backend);
        group_fixture('parent', ['@child'], 'virtual-server/remote.cgi');
        group_fixture('child', [], 'virtual-server/remote.cgi');
        $access{gassign} = '';
        # Submitting an unrestricted policy must not clear inherited limits.
        is(run_cgi('save_group', {old => 'child', name => 'child', mod => 'example', acl_security_form => 1, api_only_def => 1}), '', 'save without selector succeeds');
        my %policy = get_group_module_acl('child', '', 1);
        is($policy{api_only}, 'virtual-server/remote.cgi', 'inherited endpoint is retained');
        is_deeply(get_group('child')->{modules}, ['example'], 'inherited modules are retained');
        ok(grep($_ eq '@child', @{get_group('parent')->{members}}), 'parent membership is retained');
    };
}

# Use real storage and synchronization, replacing only the RPC transport.
load_routine('cluster-webmin/sync.cgi', 'sync_account');
# remote_error_setup(&handler): let local storage exceptions propagate.
*main::remote_error_setup = sub {};
# remote_foreign_require(host, module, file): helpers are already loaded.
*main::remote_foreign_require = sub {};
# remote_foreign_call(host, module, function, [args...]): supply the source
# policy or invoke the destination's real storage routine with args.
*main::remote_foreign_call = sub {
    my ($host, $module, $function, @args) = @_;
    if ($host eq 'source') {
        # Only the source group's global policy is relevant to this transfer.
        die "Unexpected source routine $function" unless $function eq 'get_group_module_acl';
        return $args[1] eq '' ? (api_only => 'virtual-server/remote.cgi', rpc => 0) : ();
    }
    # Destination calls operate on the isolated file or SQLite backend.
    no strict 'refs';
    return &{$function}(@args);
};
for my $backend ('', 'mysql') {
    subtest 'group sync reaches existing members on '.($backend || 'files') => sub {
        # Both users already exist; only one has a personal endpoint.
        reset_fixture($backend);
        for my $name ('member', 'personal') {
            create_user({name => $name, pass => '*LK*', modules => ['example']});
        }
        save_module_acl({api_only => 'other/api.cgi'}, 'personal', '', 1);
        group_fixture('nested', ['member', 'personal'], '');
        # Synchronize a new parent without recreating its nested members.
        my $err = sync_account({name => 'synced', members => ['@nested'], modules => ['example'], source => {host => 'source'}}, {host => 'destination'}, 'group');
        is($err, undef, 'synchronization succeeds');
        # Inheritance reaches nested members without replacing personal policy.
        my %nested = get_group_module_acl('nested', '', 1);
        is($nested{api_only}, 'virtual-server/remote.cgi', 'nested group inherits the endpoint');
        my %member = get_module_acl('member', '', 1, 1);
        is($member{api_only}, 'virtual-server/remote.cgi', 'existing nested user inherits the endpoint');
        my %personal = get_module_acl('personal', '', 1, 1);
        is($personal{api_only}, 'other/api.cgi', 'personal endpoint is retained');
    };
}
done_testing();
