#!/usr/bin/perl
# Check strict policy reads and backend resolution without host configuration.
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
require "$FindBin::Bin/../miniserv-lib.pl";
our ($config_directory, $base_remote_user, $remote_user_proto);
# Keep all policy files and user identities separate from host configuration.
$config_directory = tempdir(DIR => '/tmp', CLEANUP => 1);
$base_remote_user = 'fixture';
# module_root_directory([module]): use the isolated directory for defaults.
*main::module_root_directory = sub { return $config_directory; };
# get_module_preferences_acl(module, key): supply no preference override.
*main::get_module_preferences_acl = sub { return undef; };
# get_userdb_string(): default to local account storage.
*main::get_userdb_string = sub { return ''; };
# get_miniserv_config(&config): point account resolution at the fixture file.
*main::get_miniserv_config = sub { %{$_[0]}=(userfile=>"$config_directory/miniserv.users"); };
# error(messages...): make production errors catchable by the assertions.
*main::error = sub { die join('', @_); };
# text(key, [values...]): retain error keys without loading translations.
*main::text = sub { return join(': ', @_); };
# clear_cache(): clear cached contents and missing-file flags.
sub clear_cache { %main::read_file_cache=(); %main::read_file_missing=(); }

subtest 'CGI policy reader rejects invalid ACL files' => sub {
    # A directory opens successfully on some systems but is not a policy file.
    mkdir("$config_directory/fixture.acl") or die $!;
    clear_cache();
    my $policy = eval { webmin_user_api_only() };
    like($@, qr/Cannot read API policy file/, 'invalid ACL is a policy error');
    # Both request paths must deny access for the same invalid file.
    local $miniserv::config{env_WEBMIN_CONFIG} = $config_directory;
    my ($endpoint, $error) = miniserv::get_api_only_endpoint('fixture', {});
    ok($error, 'MiniServ rejects the same invalid ACL');
    rmdir("$config_directory/fixture.acl") or die $!;
};

subtest 'database policy lookup works without MiniServ hint' => sub {
    # SQLite supplies the SQL account and ACL rows without a database service.
    clear_cache();
    my $db = DBI->connect('dbi:SQLite:dbname=:memory:', '', '', {RaiseError=>1, PrintError=>0});
    $db->do('create table webmin_user (id integer, name text)');
    $db->do('create table webmin_user_acl (id integer, module text, attr text, value text)');
    $db->do(q{insert into webmin_user values (1, 'fixture')});
    $db->do(q{insert into webmin_user_acl values (1, '', 'api_only', 'virtual-server/remote.cgi')});
    my $connections = 0;
    # get_userdb_string(): select the SQL branch for this subtest.
    local *main::get_userdb_string = sub { return 'mysql://fixture'; };
    # connect_userdb(url): count lookups and return the in-memory connection.
    local *main::connect_userdb = sub { $connections++; return ($db, 'mysql'); };
    # disconnect_userdb(url, &db): keep this connection alive for later checks.
    local *main::disconnect_userdb = sub {};
    # Compare external CGI identity resolution with MiniServ's backend hint.
    local $remote_user_proto = undef;
    is(webmin_user_api_only(), 'virtual-server/remote.cgi', 'external CGI finds database policy without hint');
    is($connections, 1, 'database was consulted');
    $remote_user_proto = 'mysql';
    is(webmin_user_api_only(), 'virtual-server/remote.cgi', 'MiniServ hint also works');
    {
        # Error pages suppress normal DB ACL lookups. Policy checks must still
        # run and leave that setting unchanged.
        local $main::no_miniserv_userdb = 1;
        # get_userdb_string(): emulate lookup suppression during themed errors.
        local *main::get_userdb_string = sub {
            return $main::no_miniserv_userdb ? undef : 'mysql://fixture';
        };
        is(webmin_user_api_only(), 'virtual-server/remote.cgi', 'error-page initialization still reads policy');
        is($main::no_miniserv_userdb, 1, 'ordinary error-page behavior is restored');
    }
    # Prefer a local account over a SQL account with the same name.
    $remote_user_proto = undef;
    open(my $fh, '>', "$config_directory/miniserv.users") or die $!;
    print $fh "fixture:!\n"; close($fh);
    is(webmin_user_api_only(), undef, 'local account takes precedence over database duplicate');
    unlink("$config_directory/miniserv.users");
    # Neither a deleted account nor a failed query can establish its policy.
    $db->do('delete from webmin_user');
    eval { webmin_user_api_only() };
    like($@, qr/Cannot read global ACL/, 'unresolved database identity is denied');
    $db->do('drop table webmin_user');
    eval { webmin_user_api_only() };
    ok($@, 'failed user query is denied');
};

subtest 'unresolved database identity is denied' => sub {
    # Exercise identity lookup first, so the policy reader receives its result.
    local %miniserv::config = (userdb=>'mysql://fixture', env_WEBMIN_CONFIG=>$config_directory);
    local %miniserv::users=(); local %miniserv::get_user_details_cache=();
    # connect_userdb(url): emulate a connection failure before any query.
    local *miniserv::connect_userdb = sub { return 'injected database outage'; };
    # log_error(message): suppress expected fixture errors.
    local *miniserv::log_error = sub {};
    open(local *miniserv::DEBUG, '>', \my $debug) or die $!;
    my $unresolved = eval { miniserv::get_user_details('fixture') };
    ok((miniserv::get_api_only_endpoint('fixture', $unresolved))[1],
       'connection outage cannot produce an unrestricted policy');
    my $db = DBI->connect('dbi:SQLite:dbname=:memory:', '', '', {RaiseError=>0, PrintError=>0});
    # connect_userdb(url): use a missing user table to make prepare() fail.
    local *miniserv::connect_userdb = sub { return ($db, 'mysql'); };
    my $user = miniserv::get_user_details('fixture');
    ok(!$user, 'failed database query returns unresolved identity');
    my ($endpoint, $error) = miniserv::get_api_only_endpoint('fixture', $user);
    ok(!$endpoint && $error, 'policy check rejects unresolved identity');
};

{
    package policy_ldap;
    our $failure = '';
    # search(self, options...): emulate account and policy searches by scope.
    sub search {
        my ($self, %args) = @_;
        my $account = $args{scope} eq 'sub';
        # Fail either lookup independently to check both error paths.
        return bless {code => 1}, 'policy_ldap_result'
            if $failure eq ($account ? 'account' : 'policy');
        # An absent account must not fall back to local permissions.
        return bless {entries => []}, 'policy_ldap_result'
            if $failure eq 'missing' && $account;
        # Successful searches supply one account or one global policy entry.
        return bless {entries => [bless {account => $account}, 'policy_ldap_entry']},
            'policy_ldap_result';
    }
    package policy_ldap_result;
    # code(self): report success unless this result contains an injected error.
    sub code { return $_[0]->{code} || 0; }
    # error(self): describe the injected LDAP error.
    sub error { return 'injected LDAP search failure'; }
    # all_entries(self): return search matches, or none for a missing account.
    sub all_entries { return @{$_[0]->{entries} || []}; }
    package policy_ldap_entry;
    # dn(self): supply the fixture account's distinguished name.
    sub dn { return 'cn=fixture,dc=example'; }
    # get_value(self, attribute): supply the fixture's stored API-only entry.
    sub get_value { return ('api_only=virtual-server/remote.cgi'); }
}
subtest 'external CGI resolves LDAP and rejects search failures' => sub {
    # get_userdb_string(): select LDAP without contacting a real server.
    local *main::get_userdb_string = sub { return 'ldap://fixture'; };
    # connect_userdb(url): return the mock LDAP connection and search settings.
    local *main::connect_userdb = sub {
        return (bless({}, 'policy_ldap'), 'ldap', 'dc=example', {userclass=>'webminUser'});
    };
    # disconnect_userdb(url, &db): the mock has no connection to close.
    local *main::disconnect_userdb = sub {};
    local $remote_user_proto = undef;
    local $policy_ldap::failure = '';
    is(webmin_user_api_only(), 'virtual-server/remote.cgi', 'LDAP policy needs no MiniServ hint');
    # Repeat the successful lookup with each independently injected failure.
    for my $failure ('account', 'policy', 'missing') {
        $policy_ldap::failure = $failure;
        eval { webmin_user_api_only() };
        ok($@, "LDAP $failure failure is denied");
    }
};
done_testing();
