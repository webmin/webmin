#!/usr/bin/perl
# api-only-cluster.pl(task-directory, operation, fixture-file)
# Set up cluster records and inspect the isolated destination. Guest use only.
use strict;
use warnings;
no warnings 'uninitialized';
use JSON::PP;
BEGIN {
    # Require root on Linux and load Webmin from the sandbox.
    die 'Run only in an isolated Linux guest sandbox' unless $^O eq 'linux' &&
        $> == 0 && $ARGV[0] =~ m{^/tmp/webmin-api-};
    unshift @INC, "$ARGV[0]/root";
    $ENV{WEBMIN_CONFIG} = "$ARGV[0]/config";
    $ENV{WEBMIN_VAR} = "$ARGV[0]/var";
}
use WebminCore;
# Initialize the sandbox and load its fixture accounts and credentials.
my ($task, $mode, $file) = @ARGV;
$0 = "$task/root/api-only-cluster.pl";
init_config();
foreign_require('acl', 'acl-lib.pl');
open(my $fh, '<', $file) or die $!;
my $f = decode_json(do { local $/; <$fh> });
close($fh);
if ($mode eq 'destination') {
    # The destination has only a fixture RPC administrator, never host logins.
    acl::create_user({name => $f->{admin}, modules => ['acl'],
        pass => acl::encrypt_password($f->{admin_password}, '$6$fixture$')});
    save_module_acl({rpc => 1}, $f->{admin}, '', 1);
    reload_miniserv();
}
elsif ($mode eq 'source' || $mode eq 'ordinary-source') {
    # Give the administrator cluster access and set the source user's policy.
    my $admin = acl::get_user($f->{admin});
    $admin->{modules} = ['acl', 'cluster-webmin', 'servers'];
    acl::modify_user($f->{admin}, $admin);
    save_module_acl({api_only => $mode eq 'source' ? 'cluster-api.cgi' : '',
        rpc => 0}, $f->{user}, '', 1);
    # Register the second sandbox as a fast-RPC target on guest loopback.
    foreign_require('servers', 'servers-lib.pl');
    servers::save_server({id => $f->{server_id}, host => '127.0.0.1', port => 18444,
        ssl => 0, fast => 1, user => $f->{admin}, pass => $f->{admin_password}});
    # Give sync.cgi one cached source account and an empty destination cache.
    foreign_require('cluster-webmin', 'cluster-webmin-lib.pl');
    foreign_call('cluster-webmin', 'save_webmin_host',
        {id => 0, users => [acl::get_user($f->{user})], groups => [],
         modules => [], themes => []});
    foreign_call('cluster-webmin', 'save_webmin_host',
        {id => $f->{server_id}, users => [], groups => [], modules => [], themes => []});
    reload_miniserv();
}
elsif ($mode eq 'inspect') {
    # Return account existence, login locks and the API endpoint.
    my $user = acl::get_user($f->{user});
    my %acl = $user ? get_module_acl($f->{user}, '', 1, 1) : ();
    print encode_json({exists => $user ? 1 : 0,
        locked => $user && $user->{pass} =~ /^!/ ? 1 : 0,
        deny => $user->{deny}, api_only => $acl{api_only}});
}
elsif ($mode eq 'delete-copy') {
    # Remove a successful or partial copy before another synchronization test.
    acl::delete_user($f->{user}) if acl::get_user($f->{user});
    reload_miniserv();
}
else {
    # Reject unknown operations before making unrelated fixture changes.
    die 'Unknown cluster fixture operation';
}
