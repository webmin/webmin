#!/usr/bin/perl
# Test cluster synchronization failures and per-host API policy preservation.
use strict;
use warnings;
no warnings qw(once redefine uninitialized);
use Test::More;
use FindBin;

{
    package cluster_fixture;
    our (%in, %text, @hosts, @servers, @phosts, @ulist, @glist, %doneuser,
        %donegroup, %done_require, $destination, $cached,
        $failure, $created, $activated, $writes, $cleanup_fails, $source, $endpoint);
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
    sub remote_error_setup { $main::remote_error_handler = $_[0]; }
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
            return $main::remote_error_handler->('injected source read failure')
                if $failure eq 'read';
            return $args[1] eq '' ? (api_only => 'virtual-server/remote.cgi')
                                 : (fixture => 1);
        }
        if ($function eq 'save_module_acl') {
            # Count successful writes and retain the transferred endpoint.
            return $main::remote_error_handler->('injected destination write failure')
                if $failure eq 'write';
            die 'writer may update parent group' unless $args[3];
            $writes++;
            $endpoint = $args[0]->{api_only} if $args[2] eq '';
            return;
        }
        # Activation must read the destination's actual account record.
        if ($function eq 'get_user') { return {%$destination, modules => []}; }
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
            return $main::remote_error_handler->('injected cleanup failure') if $cleanup_fails;
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
        $destination = $created = $cached = $endpoint = undef;
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
is($cluster_fixture::endpoint, 'virtual-server/remote.cgi', 'copied policy retained');
ok(!$cluster_fixture::destination->{deny}, 'temporary IP denial removed after success');
is(scalar @{$cluster_fixture::cached->{users}}, 1, 'completed copy cached');
is($cluster_fixture::cached->{users}[0]{id}, 42, 'destination ID cached');
is($cluster_fixture::cached->{users}[0]{proto}, 'mysql', 'destination backend cached');
is_deeply($cluster_fixture::destination->{modules}, ['example'],
    'source modules retained despite a stale destination ACL cache');
# Previewing the same transfer must not write accounts or ACLs.
cluster_fixture::run('', 0, 1);
ok(!$cluster_fixture::created && !$cluster_fixture::writes, 'dry run does not create users or write ACLs');

{
    package cluster_save_fixture;
    use File::Temp qw(tempdir);
    use JSON::PP;
    our (%in, %maccess, $directory, $failure, $kind);
    # Page and input helpers use the submitted fixture fields.
    sub ReadParse {}
    sub error_setup {}
    sub ui_print_header {}
    sub ui_print_footer {}
    sub remote_finished {}
    sub foreign_require {}
    # remote_foreign_require(host, module, file): simulate connection failure.
    sub remote_foreign_require {
        remote_foreign_call($_[0], $_[1], 'require') if $failure eq 'require';
    }
    sub foreign_call { $_[2]->{rpc} = 0; }
    sub text { return join(' ', @_); }
    sub server_name { return $_[0]->{host}; }
    sub remote_error_setup { $main::remote_error_handler = $_[0]; }
    sub serialise_variable { return encode_json($_[0])."\n"; }
    sub unserialise_variable { return decode_json($_[0]); }
    # indexof(value, values...): match the editor's module selection.
    sub indexof {
        my $value = shift;
        for my $i (0 .. $#_) { return $i if $_[$i] eq $value; }
        return -1;
    }
    # list_servers(): two targets have different stored API endpoints.
    sub list_servers { return map { {id => $_, host => "host$_"} } (1, 2); }
    # list_webmin_hosts(): both targets contain the edited account.
    sub list_webmin_hosts {
        return map { {id => $_, users => [{name => 'target', modules => ['acl']}],
            groups => [{name => 'target', modules => ['acl'], members => []}]} } (1, 2);
    }
    # remote_eval(host, module, expression): return an isolated config path.
    sub remote_eval { return "$directory/$_[0]"; }
    # remote_foreign_call(host, module, function, args...)
    # Record child-process writes and inject errors through the real callback.
    sub remote_foreign_call {
        my ($host, $module, $function, @args) = @_;
        open(my $log, '>>', "$directory/$host.log") or die $!;
        print $log encode_json([$function, @args]),"\n";
        close($log) or die $!;
        return $main::remote_error_handler->('injected '.$failure.' failure')
            if $failure && $function eq $failure;
        if ($function =~ /^get_/) {
            die 'global defaults not excluded' unless $args[1] eq '' && $args[2];
            return $host eq 'host1' ? (api_only => 'one/api.cgi') : ();
        }
        if ($function =~ /^save_/) {
            die 'parent update enabled' unless $args[3];
        }
        return;
    }
    # run(type, module, failing-function): execute the complete CGI and return
    # its response and per-host RPC records, including calls made after errors.
    sub run {
        ($kind, my $module, $failure) = @_;
        $directory = tempdir(CLEANUP => 1);
        my $pid = fork();
        die $! unless defined($pid);
        if (!$pid) {
            %in = (all => 1, '_acl_'.$kind => 'target', _acl_mod => $module,
                api_only => 'forged/api.cgi');
            %maccess = ();
            local $INC{'./cluster-webmin-lib.pl'} = 1;
            chdir("$FindBin::Bin/../cluster-webmin") or die $!;
            open(STDOUT, '>', "$directory/output") or die $!;
            do "$FindBin::Bin/../cluster-webmin/save_acl.cgi";
            die $@ if $@;
            exit 0;
        }
        waitpid($pid, 0);
        die 'save handler failed' if $?;
        open(my $out, '<', "$directory/output") or die $!;
        my $output = do { local $/; <$out> };
        my %calls;
        for my $host ('host1', 'host2') {
            open(my $log, '<', "$directory/$host.log") or die $!;
            $calls{$host} = [map { decode_json($_) } <$log>];
        }
        return ($output, \%calls);
    }
}

# Global edits retain each target's policy; module edits never read that policy.
for my $kind ('user', 'group') {
    my $suffix = $kind eq 'user' ? 'module_acl' : 'group_module_acl';
    for my $module ('', 'acl') {
        my ($output, $calls) = cluster_save_fixture::run($kind, $module, '');
        like($output, qr/acl_success host1/, "$kind $module save succeeds");
        for my $host ('host1', 'host2') {
            my ($save) = grep { $_->[0] eq 'save_'.$suffix } @{$calls->{$host}};
            ok($save, "$host uses the $kind ACL writer");
            is($save->[1]{api_only}, !$module && $host eq 'host1' ? 'one/api.cgi' : undef,
                "$host retains only its own global restriction");
            is($save->[2], 'target', 'correct account saved');
            is($save->[3], $module, 'correct module saved');
            my @reads = grep { $_->[0] eq 'get_'.$suffix } @{$calls->{$host}};
            is(scalar(@reads), $module ? 0 : 1, 'global policy read only for global edit');
            ok(grep($_->[0] eq 'unlock_file', @{$calls->{$host}}), 'lock released');
        }
    }
    for my $failure ('require', 'lock_file', 'get_'.$suffix, 'save_'.$suffix) {
        my ($output, $calls) = cluster_save_fixture::run($kind, '', $failure);
        like($output, qr/acl_failed host1.*injected/, 'remote error reported');
        unlike($output, qr/acl_success/, 'failed saves never reported as successful');
        for my $host ('host1', 'host2') {
            ok(!grep($_->[0] eq 'set_acl_files', @{$calls->{$host}}),
                'failed save does not propagate permissions');
            is(scalar(grep($_->[0] eq 'unlock_file', @{$calls->{$host}})),
                $failure =~ /^(get_|save_)/ ? 1 : 0,
                'failure releases only an acquired lock');
            if ($failure !~ /^save_/) {
                ok(!grep($_->[0] eq 'save_'.$suffix, @{$calls->{$host}}),
                    'failed setup or policy read prevents replacement');
            }
        }
    }
}
done_testing();
