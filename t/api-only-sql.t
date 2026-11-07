#!/usr/bin/perl
# Exercise SQL policy replacement with real statements and failing triggers.
use strict;
use warnings;
no warnings qw(once redefine uninitialized);
use Test::More;
use File::Temp qw(tempdir);
use FindBin;
BEGIN {
    eval { require DBI; require DBD::SQLite; 1 }
        or plan skip_all => 'DBI and DBD::SQLite are required';
}
require "$FindBin::Bin/../web-lib-funcs.pl";
$main::config_directory = tempdir(CLEANUP => 1);
$main::base_remote_user = 'admin';
my $db = DBI->connect('dbi:SQLite:dbname=:memory:', '', '',
                     {RaiseError => 0, PrintError => 0, AutoCommit => 1});
# Use a real SQL store, while keeping Webmin configuration in the temp tree.
*main::get_userdb_string = sub { return 'mysql://fixture'; };
*main::connect_userdb = sub { return ($db, 'mysql'); };
*main::disconnect_userdb = sub {};
*main::module_root_directory = sub { return $main::config_directory; };
*main::get_module_preferences_acl = sub { return undef; };
*main::error = sub { die join('', @_)."\n"; };
*main::text = sub { return join(': ', @_); };
for my $kind ('user', 'group') {
    my $table = "webmin_${kind}_acl";
    $db->do("create table webmin_$kind (id integer primary key, name text)");
    $db->do("insert into webmin_$kind values (1, 'integration')");
    $db->do("create table $table (id integer, module text, attr text, value text, primary key(id,module,attr))");
    my $save = $kind eq 'user' ? \&save_module_acl : \&save_group_module_acl;
    my $get = $kind eq 'user' ? \&get_module_acl : \&get_group_module_acl;
    $save->({api_only => 'virtual-server/remote.cgi', rpc => 0}, 'integration', '', 1);
    # A failed ordinary-field insertion must not remove the endpoint row.
    $db->do("create trigger fail_insert before insert on $table begin select raise(abort, 'fixture insert failure'); end");
    eval { $save->({rpc => 1}, 'integration', '', 1); };
    like($@, qr/fixture insert failure/, "$kind reports failed SQL save");
    my %actual = $get->('integration', '', 1, 1);
    is($actual{api_only}, 'virtual-server/remote.cgi', "$kind failed SQL save retains endpoint");
    eval { $save->({api_only => '', rpc => 1}, 'integration', '', 1); };
    like($@, qr/fixture insert failure/, "$kind reports failed clearing request");
    %actual = $get->('integration', '', 1, 1);
    is($actual{api_only}, 'virtual-server/remote.cgi', "$kind failed clearing request retains endpoint");
    $db->do('drop trigger fail_insert');
    # Check the policy is present while other fields are being replaced.
    $db->do("create trigger require_policy before insert on $table when new.attr <> 'api_only' and not exists (select 1 from $table where id = new.id and module = '' and attr = 'api_only' and value <> '') begin select raise(abort, 'policy disappeared during save'); end");
    eval { $save->({rpc => 1}, 'integration', '.', 1); };
    is($@, '', "$kind restriction stays present throughout SQL replacement");
    %actual = $get->('integration', '', 1, 1);
    is($actual{rpc}, 1, "$kind dot-path writes the real global SQL ACL");
    $db->do('drop trigger require_policy');
    # Replacing an endpoint must be an UPDATE that leaves the old value on error.
    $db->do("create trigger fail_update before update on $table begin select raise(abort, 'fixture update failure'); end");
    eval { $save->({api_only => 'other/api.cgi'}, 'integration', '', 1); };
    like($@, qr/fixture update failure/, "$kind reports failed endpoint update");
    %actual = $get->('integration', '', 1, 1);
    is($actual{api_only}, 'virtual-server/remote.cgi', "$kind failed update retains original endpoint");
    $db->do('drop trigger fail_update');
    $save->(undef, 'integration', '', 1);
    %actual = $get->('integration', '', 1, 1);
    is_deeply(\%actual, {api_only => 'virtual-server/remote.cgi'}, "$kind SQL reset retains only endpoint");
    $save->({api_only => ''}, 'integration', '', 1);
    %actual = $get->('integration', '', 1, 1);
    is($actual{api_only}, '', "$kind explicit SQL clearing works");
}
$db->disconnect();
done_testing();
