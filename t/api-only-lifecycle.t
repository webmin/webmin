#!/usr/bin/perl
# Exercise global ACL saves and copies in an isolated temporary configuration.

use strict;
use warnings;
no warnings qw(once redefine uninitialized);
use Test::More;
use File::Temp qw(tempdir);
use FindBin;
require "$FindBin::Bin/../web-lib-funcs.pl";
our ($config_directory, $base_remote_user, %in, %text);
$config_directory = tempdir(CLEANUP => 1);
$base_remote_user = 'admin';
# module_root_directory([module]): keep default-ACL reads in the fixture tree.
*main::module_root_directory = sub { return $config_directory; };
# get_userdb_string(): use local fixture files, never a user database.
*main::get_userdb_string = sub { return ''; };
# get_module_preferences_acl(module, key): disable unrelated preference checks.
*main::get_module_preferences_acl = sub { return undef; };
# error(message, ...): turn validation failures into catchable test exceptions.
*main::error = sub { die join('', @_)."\n"; };

# load_routine(file, name)
# Load just the real routine under test, without module initialization or
# reading workstation configuration. Runtime IO stays in the temporary tree.
sub load_routine
{
my ($file, $name) = @_;
open(my $fh, '<', "$FindBin::Bin/../$file") or die $!;
local $/;
my $routine_source = <$fh>;
$routine_source =~ /^(sub \Q$name\E\n\{.*?^\})/ms or die "Missing $name";
eval "no strict; $1";
die $@ if $@;
}
load_routine('acl_security.pl', 'acl_security_save');
load_routine('acl/acl-lib.pl', $_) for qw(copy_acl_files set_acl_files);

my $endpoint = 'virtual-server/remote.cgi';
# Run the same persistence checks through the user and group ACL writers.
for my $group (0, 1) {
    my $save = $group ? \&save_group_module_acl : \&save_module_acl;
    my $get = $group ? \&get_group_module_acl : \&get_module_acl;
    my $kind = $group ? 'group' : 'user';
    $save->({api_only => $endpoint, rpc => 0}, 'integration', '', 1);
    my $input = {rpc => 1};
    my $same = $input;
    $save->($input, 'integration', '', 1);
    my %actual = $get->('integration', '');
    is($actual{api_only}, $endpoint, "$kind save retains omitted endpoint");
    is($actual{rpc}, 1, "$kind save still updates other settings");
    is($input, $same, "$kind save does not replace caller reference");
    ok(!exists($input->{api_only}), "$kind save does not mutate shared policy");
    # A reset removes ordinary fields but retains the endpoint restriction.
    $save->(undef, 'integration', '', 1);
    %actual = $get->('integration', '');
    is_deeply(\%actual, {api_only => $endpoint}, "$kind reset keeps only endpoint");
    $save->({}, 'integration', '.', 1);
    %actual = $get->('integration', '');
    is($actual{api_only}, $endpoint, "$kind dot-path global save retains endpoint");
    # Explicit clearing restores normal reset behavior.
    $save->({api_only => ''}, 'integration', '', 1);
    %actual = $get->('integration', '');
    is($actual{api_only}, '', "$kind explicit removal is honored");
    $save->(undef, 'integration', '', 1);
    %actual = $get->('integration', '');
    ok(!$actual{api_only} && !-e "$config_directory/integration.".($group ? 'gacl' : 'acl'),
       "$kind unrestricted reset removes ACL");
    # The retention rule applies only to global ACLs.
    $save->({api_only => $endpoint}, 'integration', 'example', 1);
    $save->({}, 'integration', 'example', 1);
    %actual = $get->('integration', 'example');
    ok(!exists($actual{api_only}), "$kind module ACL behavior is unchanged");
}

# A database outage must not turn an API-only login into an unrestricted user,
# including when a CGI is hosted outside miniserv.
{
    local *main::get_userdb_string = sub { return 'postgresql://fixture'; };
    local *main::connect_userdb = sub { return 'fixture database unavailable'; };
    local $main::remote_user_proto = 'postgresql';
    eval { webmin_user_api_only(); };
    like($@, qr/Cannot read global ACL/, 'global policy read fails closed on database outage');
}

# Current forms deliberately set or clear the endpoint. Old forms omit it.
%text = (acl_eapi_only => 'Invalid API endpoint');
for my $input (
    {api_only_def => 0, api_only => $endpoint},
    {api_only_def => 1},
    {},
) {
    %in = %$input;
    my %policy;
    acl_security_save(\%policy);
    if (!exists($input->{api_only_def})) {
        # Older forms leave the setting for the ACL writer to preserve.
        ok(!exists($policy{api_only}), 'older form leaves endpoint unspecified');
    }
    else {
        # Current forms explicitly choose an endpoint or unrestricted access.
        is($policy{api_only}, $input->{api_only_def} ? '' : $endpoint,
           'form saves explicit endpoint choice');
    }
}
# Reject paths and values that could escape or corrupt the endpoint setting.
for my $bad ('', '/virtual-server/remote.cgi', '../rpc.cgi',
             'virtual-server/../rpc.cgi', 'remote.cgi?x=1', "remote.cgi\nrpc=1") {
    %in = (api_only_def => 0, api_only => $bad);
    eval { acl_security_save({}); };
    like($@, qr/Invalid API endpoint/, 'invalid endpoint is rejected');
}

# Global copying must work for every user/group direction and preserve an
# existing destination endpoint even when the source explicitly has none.
for my $fromtype ('user', 'group') {
    for my $totype ('user', 'group') {
        my $savefrom = $fromtype eq 'user' ? \&save_module_acl : \&save_group_module_acl;
        my $saveto = $totype eq 'user' ? \&save_module_acl : \&save_group_module_acl;
        my $getto = $totype eq 'user' ? \&get_module_acl : \&get_group_module_acl;
        $savefrom->({api_only => '', rpc => 1}, 'source', '', 1);
        $saveto->({api_only => $endpoint}, 'target', '', 1);
        my @mods = ('');
        copy_acl_files('source', 'target', \@mods, $fromtype, $totype);
        my %actual = $getto->('target', '');
        is($actual{api_only}, $endpoint, "$fromtype-to-$totype copy retains destination restriction");
        is($actual{rpc}, 1, "$fromtype-to-$totype copy updates ordinary fields");
        is_deeply(\@mods, [''], 'copy does not modify module list');
        # A destination without a restriction inherits the source endpoint.
        $savefrom->({api_only => $endpoint}, 'source', '', 1);
        $saveto->({api_only => ''}, 'newtarget', '', 1);
        $saveto->(undef, 'newtarget', '', 1);
        copy_acl_files('source', 'newtarget', [''], $fromtype, $totype);
        %actual = $getto->('newtarget', '');
        is($actual{api_only}, $endpoint, "$fromtype-to-$totype copy propagates source restriction");
        # Deleting an unrestricted source's global ACL earlier in the same
        # process must not leave cached data for the copy to reuse.
        $savefrom->({api_only => '', rpc => 1}, 'source', '', 1);
        $savefrom->(undef, 'source', '', 1);
        copy_acl_files('source', 'staletarget', [''], $fromtype, $totype);
        %actual = $getto->('staletarget', '');
        ok(!exists($actual{rpc}), "$fromtype-to-$totype copy does not reuse deleted source data");
    }
}

# A shared input must never acquire one member's private restriction, and a
# retained subgroup endpoint must also reach its otherwise unrestricted users.
save_module_acl({api_only => $endpoint}, 'restricted', '', 1);
save_group_module_acl({api_only => 'other/api.cgi'}, 'subgroup', '', 1);
my $shared = {rpc => 1, api_only => ''};
set_acl_files([map { {name => $_} } qw(restricted ordinary nested)],
    [{name => 'subgroup', members => ['nested']}], '',
    ['restricted', 'ordinary', '@subgroup'], $shared);
my %actual = get_module_acl('restricted', '');
is($actual{api_only}, $endpoint, 'group update retains user restriction');
%actual = get_module_acl('ordinary', '');
is($actual{api_only}, '', 'restriction does not leak to a sibling user');
%actual = get_group_module_acl('subgroup', '');
is($actual{api_only}, 'other/api.cgi', 'group update retains subgroup restriction');
%actual = get_module_acl('nested', '');
is($actual{api_only}, 'other/api.cgi', 'subgroup restriction reaches nested member');
is_deeply($shared, {rpc => 1, api_only => ''}, 'group propagation does not mutate source ACL');
# Deleting and recreating a local group must not revive its global policy.
load_routine('acl/acl-lib.pl', $_) for qw(create_group delete_group group_line);
{
    # Keep account storage and module enumeration inside the temporary fixture.
    local *main::get_miniserv_config = sub { %{$_[0]} = (); };
    local *main::list_modules = sub { return ('example'); };
    create_group({name => 'reused', modules => ['example'], members => []});
    save_group_module_acl({api_only => $endpoint, rpc => 1}, 'reused', '', 1);
    save_group_module_acl({fixture => 1}, 'reused', 'example', 1);
    my %before = get_group_module_acl('reused', '', 1);
    is($before{api_only}, $endpoint, 'group endpoint is cached before deletion');
    delete_group('reused');
    ok(!-e "$config_directory/reused.gacl", 'group deletion removes global ACL');
    ok(!-e "$config_directory/example/reused.gacl", 'group deletion removes module ACL');
    create_group({name => 'reused', modules => ['example'], members => []});
    my %after = get_group_module_acl('reused', '', 1);
    is_deeply(\%after, {}, 'recreated group has no old global permissions');
    copy_acl_files('reused', 'freshmember', [''], 'group', 'user');
    my %member = get_module_acl('freshmember', '', 1, 1);
    is_deeply(\%member, {}, 'new member does not inherit deleted group permissions');
    delete_group('reused');
}

# Cluster synchronization must include global permissions on the destination.
load_routine('web-lib.pl', 'unique');
load_routine('cluster-webmin/sync.cgi', 'copy_acls_for');
{
    my @saved;
    # remote_foreign_require(host, module, library): skip actual server loading.
    local *main::remote_foreign_require = sub { };
    # remote_foreign_call(host, module, function, ...): emulate reads, record
    # saves.
    local *main::remote_foreign_call = sub {
        my ($host, $module, $function, @args) = @_;
        if ($function =~ /^get_/) {
            # Only the simulated global ACL carries an endpoint restriction.
            return $args[1] eq '' ? (api_only => $endpoint) : (ordinary => 1);
        }
        # Record writes so the test can check both their policy and target.
        push(@saved, [$function, @args]);
    };
    for my $kind ('user', 'group') {
        @saved = ();
        copy_acls_for({name => 'integration', source => {host => 'source'},
            modules => ['acl']}, {host => 'destination'}, $kind);
        my ($global) = grep { $_->[3] eq '' } @saved;
        ok($global, "$kind cluster sync includes global permissions");
        is($global->[1]->{api_only}, $endpoint,
            "$kind cluster sync carries the API-only endpoint");
        is($global->[0], $kind eq 'user' ? 'save_module_acl' : 'save_group_module_acl',
            "$kind cluster sync uses the protected ACL writer");
    }
}
done_testing();
