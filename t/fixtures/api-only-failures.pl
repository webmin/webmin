#!/usr/bin/perl
# api-only-failures.pl(task-directory, operation, fixture-file)
# Inspect isolated guest accounts and inject failures into a disposable user DB.
use strict;
use warnings;
no warnings 'uninitialized';
use JSON::PP;
# Validate the guest at runtime, before loading Webmin or changing its paths.
# Syntax checks must not initialize a guest sandbox.
die 'Run only in an isolated Linux guest sandbox' unless $^O eq 'linux' &&
    $> == 0 && $ARGV[0] =~ m{^/(?:var/)?tmp/webmin-api-};
unshift @INC, "$ARGV[0]/root";
$ENV{WEBMIN_CONFIG} = "$ARGV[0]/config";
$ENV{WEBMIN_VAR} = "$ARGV[0]/var";
require WebminCore;
WebminCore->import();
# Load isolated Webmin settings and the private fixture account names.
my ($task, $mode, $file) = @ARGV;
$0 = "$task/root/api-only-failures.pl";
init_config();
foreign_require('acl', 'acl-lib.pl');
open(my $fh, '<', $file) or die $!;
my $f = decode_json(do { local $/; <$fh> });
close($fh);

if ($mode eq 'inspect') {
    # Return only non-secret account and policy state.
    my %result;
    foreach my $key ('user', 'clone', 'renamed') {
        my $u = acl::get_user($f->{$key});
        my %a = get_module_acl($f->{$key}, '', 1, 1);
        $result{$key} = {exists => $u ? 1 : 0, deny => $u->{deny},
            locked => $u && $u->{pass} =~ /^!/ ? 1 : 0,
            api_only => $a{api_only}, rpc => $a{rpc}};
    }
    # Include inherited group state so rejected forms can be compared exactly.
    foreach my $key ('group', 'parent') {
        my $g = acl::get_group($f->{$key});
        my %a = get_group_module_acl($f->{$key}, '', 1);
        $result{$key} = {exists => $g ? 1 : 0, desc => $g->{desc},
            members => $g->{members}, api_only => $a{api_only}};
    }
    print encode_json(\%result);
}
elsif ($mode eq 'parent') {
    # Create a separate parent for the existing test group to join.
    acl::create_group({name => $f->{parent}, desc => 'Restricted parent',
        modules => [], members => []});
    save_group_module_acl({api_only => 'strict-api.cgi', rpc => 0},
        $f->{parent}, '', 1);
}
elsif ($mode eq 'cleanup-parent') {
    # Remove the extra parent even if an earlier assertion aborted the test.
    acl::delete_group($f->{parent}) if acl::get_group($f->{parent});
}
elsif ($mode eq 'subgroup-editor') {
    # This editor can edit permissions, but cannot select a parent group.
    save_module_acl({users => $f->{user}, acl => 1, gassign => '',
        groups => 1, create => 0, delete => 0, rename => 0},
        $f->{editor}, 'acl', 1);
}
else {
    # Faults affect only the sandbox database created by api-only-userdb.py.
    my $userdb = get_userdb_string();
    $userdb =~ m{/webmin_apitest_[a-z0-9]+$} or die 'Not a fixture database';
    my ($db, $proto) = connect_userdb($userdb);
    ref($db) or die 'Cannot connect to fixture database';
    my @sql;
    if ($mode eq 'fail-write') {
        # Reject only the new fixture's endpoint insert, after ordinary ACLs.
        my $name = $db->quote($f->{renamed});
        if ($proto eq 'mysql') {
            # MySQL can raise the injected error directly from its trigger.
            @sql = ("create trigger api_fixture_fail before insert on webmin_user_acl " .
                "for each row begin if new.attr = 'api_only' and new.id in " .
                "(select id from webmin_user where name = $name) then " .
                "signal sqlstate '45000' set message_text = 'fixture policy write failure'; end if; end");
        }
        else {
            # PostgreSQL implements the same fault through a trigger function.
            @sql = ("create function api_fixture_fail() returns trigger language plpgsql as \$\$ " .
                "begin if new.attr = 'api_only' and new.id in " .
                "(select id from webmin_user where name = $name) then " .
                "raise exception 'fixture policy write failure'; end if; return new; end; \$\$",
                'create trigger api_fixture_fail before insert on webmin_user_acl ' .
                'for each row execute function api_fixture_fail()');
        }
    }
    elsif ($mode eq 'restore-write') {
        # Remove the trigger and, for PostgreSQL, its supporting function.
        @sql = $proto eq 'mysql' ? ('drop trigger if exists api_fixture_fail') :
            ('drop trigger if exists api_fixture_fail on webmin_user_acl',
             'drop function if exists api_fixture_fail()');
    }
    elsif ($mode eq 'fail-lookup') {
        # Make account lookups fail without stopping the database server.
        @sql = ('alter table webmin_user rename to api_fixture_unavailable');
    }
    elsif ($mode eq 'restore-lookup') {
        # Restore the account table before querying or deleting test users.
        @sql = ('alter table api_fixture_unavailable rename to webmin_user');
    }
    else {
        # Do not silently accept a misspelled fault or recovery operation.
        die 'Unknown operation';
    }
    # Stop at the first failed setup or recovery statement.
    foreach my $sql (@sql) {
        $db->do($sql) or die $db->errstr;
    }
    disconnect_userdb($userdb, $db);
}
