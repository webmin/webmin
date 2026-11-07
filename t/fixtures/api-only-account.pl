#!/usr/bin/perl
# api-only-account.pl(mode, fixture-file)
# Create and inspect disposable Webmin fixtures. Passwords never leave the VM.
use strict;
use warnings;
no warnings 'uninitialized';
use JSON::PP;
# Debian and RPM packages install Webmin under different roots. Read the
# guest's root before the library is loaded at compile time.
my $webmin_root;
BEGIN {
    $webmin_root = '/usr/share/webmin';
    if (open(my $cfh, '<', '/etc/webmin/miniserv.conf')) {
        while (my $line = <$cfh>) {
            $webmin_root = $1 if ($line =~ /^root=(\S+)/);
        }
        close($cfh);
    }
}
use lib $webmin_root;
use WebminCore;
my ($mode, $file) = @ARGV;
# Load only the VM-local fixture file supplied by the test driver.
open(my $fh, '<', $file) or die $!;
my $f = decode_json(do { local $/; <$fh> });
close($fh);
# Initialize the installed guest instance; this helper must not run locally.
$ENV{'WEBMIN_CONFIG'} = '/etc/webmin';
$ENV{'WEBMIN_VAR'} = '/var/webmin';
$0 = "$webmin_root/api-only-account.pl";
&init_config();
&foreign_require('acl', 'acl-lib.pl');

if ($mode eq 'setup') {
    # Only generated fixture logins are modified by this helper.
    foreach my $kind ('admin', 'user', 'editor') {
        &acl::get_user($f->{$kind}) && die 'Fixture name clash';
        &acl::create_user({name => $f->{$kind}, modules => ['acl'], nochange => 1,
            pass => &acl::encrypt_password($f->{$kind.'_password'}, '$6$fixture$')});
        &save_module_acl({rpc => 0}, $f->{$kind}, '', 1);
    }
    # Give the restricted fixture a conflicting RPC grant to test precedence.
    &save_module_acl({api_only => 'virtual-server/remote.cgi', rpc => 1},
        $f->{user}, '', 1);
    # The delegated editor can edit accounts but cannot change their ACLs.
    &save_module_acl({users => $f->{user}, acl => 0, create => 0, delete => 0,
        rename => 0, groups => 1, pass => 0}, $f->{editor}, 'acl', 1);
    &save_module_acl({users => '', acl => 0, create => 0, delete => 0,
        rename => 0, groups => 0}, $f->{user}, 'acl', 1);
    # An unrestricted group exercises copying without an inherited endpoint.
    &acl::create_group({name => $f->{group}, desc => 'API lifecycle fixture',
        modules => [], members => []});
    &save_group_module_acl({api_only => ''}, $f->{group}, '', 1);
    &reload_miniserv();
}
elsif ($mode eq 'inspect') {
    # Return policy fields only, never credentials or hashes.
    my %result;
    foreach my $key ('user', 'renamed', 'clone') {
        my %a = &get_module_acl($f->{$key}, '', 1, 1);
        $result{$key} = {exists => &acl::get_user($f->{$key}) ? 1 : 0,
            api_only => $a{api_only}, rpc => $a{rpc}};
    }
    my %g = &get_group_module_acl($f->{group}, '', 1);
    $result{group} = {exists => &acl::get_group($f->{group}) ? 1 : 0,
        api_only => $g{api_only}, rpc => $g{rpc}, nodot => $g{nodot}};
    print encode_json(\%result);
}
elsif ($mode eq 'copy') {
    # Copying a group with no endpoint restriction must preserve the target
    # endpoint, using the same helper as group assignment.
    &acl::copy_group_user_acl_files($f->{group}, $f->{user}, ['']);
}
elsif ($mode eq 'propagate') {
    # A group update must preserve the fixture user's current endpoint.
    my @users = &acl::list_users();
    my @groups = &acl::list_groups();
    &acl::set_acl_files(\@users, \@groups, '', [$f->{user}], {api_only => '', rpc => 1});
}
elsif ($mode eq 'group-editor') {
    # Exercise inherited fields for an ACL editor without group assignment.
    &save_module_acl({users => $f->{user}, acl => 1, gassign => '', create => 0,
        delete => 0, rename => 0, groups => 0, pass => 0}, $f->{editor}, 'acl', 1);
}
elsif ($mode eq 'cleanup') {
    # Remove every possible lifecycle name, including clones and renamed users.
    foreach my $key ('user', 'renamed', 'clone', 'editor', 'admin') {
        &acl::delete_user($f->{$key}) if (&acl::get_user($f->{$key}));
    }
    &acl::delete_group($f->{group}) if (&acl::get_group($f->{group}));
    # Older group deletion leaves the global ACL file behind.
    &unlink_file("/etc/webmin/$f->{group}.gacl");
    &reload_miniserv();
    foreach my $key ('user', 'renamed', 'clone', 'editor', 'admin') {
        &acl::get_user($f->{$key}) && die 'Fixture account remains';
    }
}
else {
    # Reject unknown operations instead of leaving ambiguous fixture state.
    die 'Unknown fixture operation';
}
