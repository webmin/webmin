#!/usr/bin/perl
# Test cluster sync when ACL reads, ACL writes or account cleanup fail.
use strict;
use warnings;
no warnings qw(once redefine uninitialized);
use Test::More;
use FindBin;

{
    package cluster_fixture;
    our (%in, %text, @hosts, @servers, @phosts, @ulist, @glist, %doneuser,
        %donegroup, %done_require, $failure_handler, $destination, $cached,
        $failure, $created, $activated, $writes, $cleanup_fails, $source);
    # ReadParse(): run() supplies the submitted fields directly.
    sub ReadParse {}
    # list_webmin_hosts(): return the source and destination account caches.
    sub list_webmin_hosts { return @hosts; }
    # list_servers(): return the two simulated RPC destinations.
    sub list_servers { return @servers; }
    # ui_print_header(args...): omit page decoration from captured output.
    sub ui_print_header {}
    # ui_print_footer(args...): omit navigation from captured output.
    sub ui_print_footer {}
    # create_on_parse(prefix, &already, name, [no-print]): choose the target.
    sub create_on_parse { return $hosts[1]; }
    # server_name(&server): use the mock hostname as its display name.
    sub server_name { return $_[0]->{host}; }
    # text(key, [values...]): expose message keys without translations.
    sub text { return $_[0]; }
    # html_escape(text): retain fixture error text for assertions.
    sub html_escape { return $_[0]; }
    # remote_error_setup(&handler): install the production RPC error callback.
    sub remote_error_setup { $failure_handler = $_[0]; }
    # remote_foreign_require(host, module, file): no remote files are loaded.
    sub remote_foreign_require {}
    # save_webmin_host(&host): retain the resulting cache for inspection.
    sub save_webmin_host { $cached = $_[0]; }
    # unique(values...): preserve order while removing duplicate module names.
    sub unique { my %seen; return grep { !$seen{$_}++ } @_; }

    # remote_foreign_call(host, module, function, args...): simulate RPC calls
    # and failures, keeping destination state for assertions.
    sub remote_foreign_call {
        my ($host, $module, $function, @args) = @_;
        if ($function eq 'create_user') {
            # The destination assigns its own ID and backend.
            $created = {%{$args[0]}};
            $destination = {%$created, id => 42, proto => 'mysql'};
            return;
        }
        if ($function eq 'get_module_acl') {
            # Inject a source failure before returning global or module ACLs.
            return $failure_handler->('injected source read failure')
                if $failure eq 'read';
            return $args[1] eq '' ? (api_only => 'virtual-server/remote.cgi')
                                 : (fixture => 1);
        }
        if ($function eq 'save_module_acl') {
            # Count successful writes and retain the transferred endpoint.
            return $failure_handler->('injected destination write failure')
                if $failure eq 'write';
            $writes++;
            $destination->{api_only} = $args[0]->{api_only} if $args[2] eq '';
            return;
        }
        # Activation must read the destination's actual account record.
        if ($function eq 'get_user') { return {%$destination}; }
        if ($function eq 'modify_user') {
            # Reject activation before both ACLs exist or with a source-only ID.
            die 'activated before all ACLs were copied' unless $writes == 2;
            die 'used source database ID' unless $args[1]->{id} == 42;
            $activated++;
            $destination = {%{$args[1]}};
            return;
        }
        if ($function eq 'delete_user') {
            # An unreachable destination can make rollback fail as well.
            return $failure_handler->('injected cleanup failure') if $cleanup_fails;
            $destination = undef;
            return;
        }
        # No server process needs reloading in this test.
        return if $function eq 'reload_miniserv';
        # Unexpected calls must not silently pass the synchronization test.
        die "Unexpected remote operation $function";
    }

    # run(failure, cleanup-fails, dry-run): run the sync CGI and return HTML.
    # failure is 'read', 'write' or ''; the remaining arguments are booleans.
    sub run {
        ($failure, $cleanup_fails, my $dryrun) = @_;
        # Reset state so each test starts with an empty destination.
        %in = (users_mode => 1, test => $dryrun);
        %doneuser = (); %donegroup = (); %done_require = ();
        @ulist = (); @glist = ();
        $destination = $created = $cached = undef;
        $activated = $writes = 0;
        # Different source and destination IDs expose accidental ID copying.
        $source = {name => 'api-fixture', pass => 'fixture-hash',
            id => 1, proto => 'postgresql', modules => ['example']};
        @hosts = ({id => 1, users => [$source], groups => []},
                  {id => 2, users => [], groups => []});
        @servers = ({id => 1, host => 'source'}, {id => 2, host => 'destination'});
        # Run the handler with simulated RPC calls and capture its output.
        local $INC{'./cluster-webmin-lib.pl'} = 1;
        open(my $out, '>', \my $output) or die $!;
        local *STDOUT = $out;
        do "$FindBin::Bin/../cluster-webmin/sync.cgi";
        die $@ if $@;
        return $output;
    }
}

# Test each transfer failure both with successful and failed rollback.
for my $failure ('read', 'write') {
    for my $cleanup (0, 1) {
        subtest "$failure failure, cleanup failure=$cleanup" => sub {
            my $output = cluster_fixture::run($failure, $cleanup, 0);
            like($output, qr/injected/, 'error is reported');
            # Failed copies stay disabled and never enter the destination cache.
            like($cluster_fixture::created->{pass}, qr/^!/, 'created password is locked');
            is($cluster_fixture::created->{deny}, '0.0.0.0/0 ::/0', 'all IP logins denied');
            ok(!$cluster_fixture::activated, 'failed policy is never activated');
            is(scalar @{$cluster_fixture::cached->{users}}, 0, 'failed copy is not cached');
            is(!!$cluster_fixture::destination, !!$cleanup, 'cleanup removes failed copy when reachable');
            is($cluster_fixture::source->{pass}, 'fixture-hash', 'source credentials unchanged');
        };
    }
}
# A complete transfer activates the account and adds it to the cache.
cluster_fixture::run('', 0, 0);
is($cluster_fixture::activated, 1, 'successful copy is activated');
is($cluster_fixture::destination->{api_only}, 'virtual-server/remote.cgi', 'copied policy retained');
ok(!$cluster_fixture::destination->{deny}, 'temporary IP denial removed after success');
is(scalar @{$cluster_fixture::cached->{users}}, 1, 'completed copy cached');
# Previewing the same transfer must not write accounts or ACLs.
cluster_fixture::run('', 0, 1);
ok(!$cluster_fixture::created && !$cluster_fixture::writes, 'dry run does not create users or write ACLs');
done_testing();
