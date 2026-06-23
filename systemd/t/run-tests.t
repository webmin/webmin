#!/usr/bin/perl
use strict;
use warnings;
no warnings 'redefine';
no warnings 'once';
use Test::More;
use Cwd qw(abs_path);
use File::Path qw(make_path);
use File::Temp qw(tempdir);

# script_dir()
# Returns the directory containing this test file.
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

# write_test_file(file, data)
# Writes a fixture file.
sub write_test_file
{
    my ($file, $data) = @_;
    open(my $fh, '>', $file) or die "$file: $!";
    print $fh $data;
    close($fh);
}

# slurp_test_file(file)
# Reads a fixture or source file as one scalar.
sub slurp_test_file
{
    my ($file) = @_;
    open(my $fh, '<', $file) or die "$file: $!";
    local $/;
    my $data = <$fh>;
    close($fh);
    return $data;
}

my $bindir = script_dir();
my $rootdir = abs_path("$bindir/../..") or die "rootdir: $!";

my $confdir = tempdir(CLEANUP => 1);
my $vardir = tempdir(CLEANUP => 1);
make_path("$confdir/systemd");
write_test_file("$confdir/config", "os_type=generic-linux\nos_version=0\n");
write_test_file("$confdir/var-path", "$vardir\n");
write_test_file("$confdir/systemd/config", "desc=1\n");
$ENV{'WEBMIN_CONFIG'} = $confdir;
$ENV{'WEBMIN_VAR'} = $vardir;
$ENV{'FOREIGN_MODULE_NAME'} = 'systemd';
$ENV{'FOREIGN_ROOT_DIRECTORY'} = $rootdir;

chdir("$bindir/..") or die "chdir: $!";
unshift(@INC, "$bindir/..");
require 'systemd-lib.pl'; ## no critic
our (%access, %config, %in, %text, %gconfig, $remote_user);

%text = (
    %text,
    yes => 'Yes',
    no => 'No',
    systemd_ejournal => 'journalctl missing',
    systemd_euser => 'bad user',
    systemd_euserhome => 'bad home',
    systemd_euserunitfile => 'bad user unit file',
    systemd_euserunitdir => 'bad user unit dir',
    systemd_edropinfile => 'bad drop-in file',
    systemd_edropininstall => 'bad drop-in install section',
    systemd_ereadonly => 'runtime unit file',
    systemd_ename => 'bad unit name',
    systemd_egone => 'unit gone',
    systemd_evendoredit => 'vendor unit edit disabled',
    systemd_elocaldelete => 'local unit delete only',
    systemd_eclash => 'unit clash',
    systemd_emountwhat => 'missing mount source',
    systemd_emountname => 'bad mount name',
    systemd_eautomountmount => 'bad matching mount',
    systemd_eautomountname => 'bad automount name',
    systemd_eautomountmode => 'bad automount mode',
    systemd_everify => 'verify failed: $1',
    systemd_type_service => 'Service',
    systemd_type_timer => 'Timer',
    systemd_type_socket => 'Socket',
    systemd_type_path => 'Path',
    systemd_type_target => 'Target',
    systemd_type_mount => 'Mount',
    systemd_type_automount => 'Automount',
    systemd_type_swap => 'Swap',
    systemd_type_slice => 'Slice',
    systemd_type_scope => 'Scope',
    systemd_type_device => 'Device',
    systemd_tab_storage => 'Storage',
    systemd_tab_resources => 'Resources',
    systemd_tab_device => 'Devices',
    index_unknown => 'Unknown',
    log_modify => 'Modified unit $1',
    log_create => 'Created unit $1',
    log_delete => 'Deleted unit $1',
    log_override => 'Created drop-in override for unit $1',
    log_deleteoverride => 'Deleted drop-in override for unit $1',
    log_status => 'Fetched status of unit $1',
    log_props => 'Fetched properties of unit $1',
    log_deps => 'Listed dependencies of unit $1',
    log_logs => 'Fetched logs for unit $1',
    log_massstart => 'Started units $1',
    log_massstop => 'Stopped units $1',
    log_massrestart => 'Restarted units $1',
    log_massenable => 'Enabled units $1',
    log_massdisable => 'Disabled units $1',
    log_massmask => 'Masked units $1',
    log_massunmask => 'Unmasked units $1',
    mass_enostart => 'Start is not applicable for this unit type',
    mass_enorestart => 'Restart is not applicable for this unit type',
    log_user_modify => 'Modified user unit $1 for $2',
    log_user_create => 'Created user unit $1 for $2',
    log_user_delete => 'Deleted user unit $1 for $2',
    log_user_override => 'Created drop-in override for user unit $1 for $2',
    log_user_deleteoverride => 'Deleted user unit drop-in override $1 for $2',
    log_user_status => 'Fetched status of user unit $1 for $2',
    log_user_props => 'Fetched properties of user unit $1 for $2',
    log_user_deps => 'Listed dependencies of user unit $1 for $2',
    log_user_logs => 'Fetched logs for user unit $1 for $2',
    log_user_massstart => 'Started user units $1 for $2',
    log_user_massstop => 'Stopped user units $1 for $2',
    log_user_massrestart => 'Restarted user units $1 for $2',
    log_user_massenable => 'Enabled user units $1 for $2',
    log_user_massdisable => 'Disabled user units $1 for $2',
    log_user_massmask => 'Masked user units $1 for $2',
    log_user_massunmask => 'Unmasked user units $1 for $2',
    log_user_massdelete => 'Deleted user units $1 for $2',
    log_user_linger => 'Set linger for user $1 to $2',
);

is_deeply([ get_creatable_unit_types() ],
          [ qw(service timer socket path target mount automount swap slice) ],
          'creatable unit types are stable');
is_deeply([ get_creatable_unit_types(1) ],
          [ qw(service timer socket path target slice) ],
          'user creatable unit types exclude privileged storage units');
is_deeply([ get_list_unit_types() ],
          [ qw(service timer socket path target mount automount swap slice scope device) ],
          'listed unit types are stable');
ok(grep { $_ eq 'device' } get_unit_types(),
   'full unit type list includes generated systemd unit kinds');
is_deeply([ get_index_tab_ids() ],
          [ qw(service timer socket path target storage resources device user) ],
          'index tabs are stable');
is(default_visible_tabs(),
   'service,timer,socket,path,target,storage,resources,device,user',
   'default visible tabs include every tab');
{
    local $config{'visible_tabs'} = 'service,device';
    ok(tab_visible('service'), 'visible tab helper accepts configured tab');
    ok(!tab_visible('timer'), 'visible tab helper rejects hidden tab');
}
ok(boot_state_changeable('enabled'), 'enabled unit boot state is editable');
ok(boot_state_changeable('disabled'), 'disabled unit boot state is editable');
ok(boot_state_changeable('Disabled'), 'boot state helper accepts systemd-style casing');
ok(!boot_state_changeable('static'), 'static unit boot state is not editable');
ok(!boot_state_changeable('masked'), 'masked unit boot state is not editable');
ok(!boot_state_changeable('transient'), 'transient unit boot state is not editable');
ok(!boot_state_changeable('disabled', 'session-2.scope'),
   'scope units do not show boot state toggles');
ok(!boot_state_changeable('generated', 'dev-sda.device'),
   'device units do not show boot state toggles');
ok(unit_file_editable({
        name => 'user.slice',
        file => '/usr/lib/systemd/system/user.slice',
        unitstate => 'static',
    }),
   'persistent static unit files can still be edited');
ok(!unit_file_editable({
        name => 'session-2.scope',
        file => '/run/systemd/transient/session-2.scope',
        unitstate => 'transient',
    }),
   'transient scope files are read-only');
ok(!unit_file_editable({
        name => 'custom.scope',
        file => '/etc/systemd/system/custom.scope',
        unitstate => 'disabled',
    }),
   'scope unit files are read-only even with a persistent path');
ok(!unit_file_editable({
        name => 'generated.service',
        file => '/run/systemd/generator/generated.service',
        unitstate => 'generated',
    }),
   'generated unit files are read-only');
ok(system_unit_file_writable({
        name => 'local.service',
        file => '/etc/systemd/system/local.service',
        unitstate => 'enabled',
    }),
   'local system unit files can be edited directly');
ok(!system_unit_file_writable({
        name => 'vendor.service',
        file => '/usr/lib/systemd/system/vendor.service',
        unitstate => 'enabled',
    }),
   'packaged system unit files cannot be edited directly by default');
{
    local $config{'edit_vendor_units'} = 1;
    ok(system_unit_file_writable({
            name => 'vendor.service',
            file => '/usr/lib/systemd/system/vendor.service',
            unitstate => 'enabled',
        }),
       'packaged system unit files can be edited directly when configured');
}
ok(system_unit_file_deletable({
        name => 'local.service',
        file => '/etc/systemd/system/local.service',
        unitstate => 'enabled',
    }),
   'local system unit files can be deleted');
ok(!system_unit_file_deletable({
        name => 'vendor.service',
        file => '/usr/lib/systemd/system/vendor.service',
        unitstate => 'enabled',
    }),
   'packaged system unit files cannot be deleted');
{
    local $config{'delete_vendor_units'} = 1;
    ok(system_unit_file_deletable({
            name => 'vendor.service',
            file => '/usr/lib/systemd/system/vendor.service',
            unitstate => 'enabled',
        }),
       'packaged system unit files can be deleted when configured');
}
{
    local $config{'show_runtime_units'} = 0;
    ok(unit_visible_on_index({
            name => 'demo.service',
            file => '/etc/systemd/system/demo.service',
            unitstate => 'enabled',
        }),
       'persistent units remain visible when runtime units are hidden');
    ok(!unit_visible_on_index({
            name => 'session-2.scope',
            file => '/run/systemd/transient/session-2.scope',
            unitstate => 'transient',
        }),
       'transient units can be hidden from index tabs');
}

{
    ok(!systemd_acl_bool({ }, 'edit_user'),
       'missing granular ACL permissions are denied');
    ok(systemd_acl_bool({ edit_user => 1 }, 'edit_user'),
       'explicit granular ACL permissions are allowed');
    ok(systemd_can_view_system({ start => 1 }),
       'system action permission implies system scope visibility');
    ok(!systemd_can_view_system({ start_user => 1 }),
       'user action permission does not imply system scope visibility');
    ok(systemd_can_view_user_scope({ create_user => 1 }),
       'user action permission implies user scope visibility');
    ok(systemd_can_inspect({ view => 1, status => 1 }, 0),
       'status ACL allows system unit inspection');
    ok(systemd_can_inspect({ view_user => 1, status_user => 1 }, 1),
       'user status ACL allows user unit inspection');
    ok(!systemd_can_inspect({ view_user => 1, status => 1 }, 1),
       'system status ACL does not grant user unit inspection');
    ok(!systemd_can_logs({ view => 1, status => 1 }, 0),
       'status ACL does not grant log access');
    ok(systemd_can_runtime({ view_user => 1, start_user => 1 },
                           'start', 1),
       'runtime ACL allows user unit starts when user scope is visible');
    ok(!systemd_can_runtime({ view_user => 1, start => 1 }, 'start', 1),
       'system runtime ACL does not grant user unit starts');
    ok(!systemd_can_runtime({ view => 1, start_user => 1 }, 'start', 0),
       'user runtime ACL does not grant system unit starts');
    ok(!systemd_can_runtime({ view_user => 1, stop_user => 1 },
                            'start', 1),
       'one runtime action does not grant another');

    {
        local %access = ( view_user => 1, create_user => 1,
                          linger => 1, mode => 1, users => 'alice' );
        ok(systemd_acl_bool('view_user'),
           'ACL bool defaults to the current module ACL');
        ok(systemd_can_create(1, 'alice'),
           'ACL helpers default to the current module ACL');
        ok(!systemd_can_create(1, 'bob'),
           'default ACL still applies user ownership filters');
    }

    my %only_acl = ( mode => 1, users => 'alice bob' );
    ok(systemd_acl_user_allowed(\%only_acl, 'alice'),
       'user ACL only-list accepts listed owner');
    ok(!systemd_acl_user_allowed(\%only_acl, 'carol'),
       'user ACL only-list rejects unlisted owner');
    ok(systemd_acl_user_allowed({ mode => 99 }, 'alice'),
       'invalid user ACL mode falls back to all users');
    is(systemd_acl_default_user({ mode => 1, users => 'alice' }),
       'alice', 'single-user allow-list supplies a default owner');
    is(systemd_acl_default_user({ mode => 1, users => 'alice bob' }),
       undef, 'multi-user allow-list does not guess a default owner');
    my %except_acl = ( mode => 2, users => 'alice bob' );
    ok(!systemd_acl_user_allowed(\%except_acl, 'alice'),
       'user ACL except-list rejects listed owner');
    ok(systemd_acl_user_allowed(\%except_acl, 'carol'),
       'user ACL except-list accepts unlisted owner');
    local $remote_user = 'alice';
    ok(systemd_acl_user_allowed({ mode => 3 }, 'alice'),
       'current Webmin user ACL accepts matching owner');
    is(systemd_acl_default_user({ mode => 3 }), 'alice',
       'current Webmin user mode supplies a default owner');
    ok(!systemd_acl_user_allowed({ mode => 3 }, 'bob'),
       'current Webmin user ACL rejects different owner');
    ok(systemd_can_create({ view_user => 1, create_user => 1,
                            mode => 3 }, 1, 'alice'),
       'user create ACL honors current Webmin user owner');
    ok(!systemd_can_create({ view_user => 1, create_user => 1,
                             mode => 3 }, 1, 'bob'),
       'user create ACL rejects disallowed owner');
    ok(systemd_can_manual({ manual_user => 1, mode => 1,
                            users => 'alice' },
                          { scope => 'user', user => 'alice' }),
       'manual user file ACL honors owner filter');
    ok(!systemd_can_manual({ manual_user => 1, mode => 1,
                             users => 'alice' },
                           { scope => 'user', user => 'bob' }),
       'manual user file ACL rejects disallowed owner');

    my %virtualmin_acl = systemd_safe_user_unit_acl('alice');
    is($virtualmin_acl{'noconfig'}, 1,
       'Virtualmin user-unit ACL preset disables module config access');
    is($virtualmin_acl{'mode'}, 1,
       'Virtualmin user-unit ACL preset limits access to named users');
    is($virtualmin_acl{'users'}, 'alice',
       'Virtualmin user-unit ACL preset stores the allowed owner');
    foreach my $key (qw(view status logs start stop restart boot mask create
                        edit delete dropin manual reload backup)) {
        ok(!$virtualmin_acl{$key},
           "Virtualmin user-unit ACL preset denies system $key");
    }
    foreach my $key (qw(view_user status_user logs_user start_user stop_user
                        restart_user boot_user create_user edit_user
                        delete_user dropin_user manual_user linger)) {
        ok($virtualmin_acl{$key},
           "Virtualmin user-unit ACL preset allows $key");
    }
    ok(!$virtualmin_acl{'mask_user'},
       'Virtualmin user-unit ACL preset denies user-unit masking');
    ok(systemd_can_create(\%virtualmin_acl, 1, 'alice'),
       'Virtualmin user-unit ACL preset can create allowed user units');
    ok(!systemd_can_mask(\%virtualmin_acl, 1, 'alice'),
       'Virtualmin user-unit ACL preset cannot mask user units');
    ok(!systemd_can_create(\%virtualmin_acl, 1, 'bob'),
       'Virtualmin user-unit ACL preset rejects other user owners');
    ok(!systemd_can_create(\%virtualmin_acl, 0),
       'Virtualmin user-unit ACL preset cannot create system units');

    my %safe_acl = ( mode => 3,
                     view => 0, view_user => 1,
                     create => 0, create_user => 1,
                     edit => 0, edit_user => 1,
                     mask => 0, mask_user => 0 );
    ok(systemd_can_create(\%safe_acl, 1, 'alice'),
       'safe Webmin user ACL can create own user units');
    ok(!systemd_can_create(\%safe_acl, 1, 'bob'),
       'safe Webmin user ACL rejects other user managers');
    ok(!systemd_can_create(\%safe_acl, 0),
       'safe Webmin user ACL cannot create system units');
    ok(!systemd_can_mask(\%safe_acl, 1, 'alice'),
       'safe Webmin user ACL does not permit user-unit masking');

    my @me = getpwuid($<);
    if (@me) {
        my ($name, $uid, $gid) = ($me[0], $me[2], $me[3]);
        ok(systemd_acl_user_allowed({ mode => 4, uidmin => $uid,
                                      uidmax => $uid }, $name),
           'UID range ACL accepts matching owner');
        ok(systemd_acl_user_allowed({ mode => 5, users => $gid }, $name),
           'primary group ACL accepts matching owner');
    }
}

is_deeply([ split_exec_commands(" one \r\n\n two \n") ],
          [ 'one', 'two' ],
          'multi-line command fields are trimmed and split');
is(shell_exec_command('/bin/sh', q{echo 'one'}),
   q{/bin/sh -c 'echo '\''one'\'''},
   'shell command escapes single quotes');
is(format_exec_command('/bin/sh', 'echo ok'), 'echo ok',
   'plain command does not need a shell');
is(format_exec_command('/bin/sh', 'echo ok > /tmp/out'),
   q{/bin/sh -c 'echo ok > /tmp/out'},
   'redirected command is wrapped in a shell');
is(clean_unit_value(" a\0b\n c\r "), 'ab  c',
   'scalar unit values lose nulls and line breaks');
is(clean_unit_body(" A\0\r\nB\n "), "A\nB",
   'unit body preserves newlines but removes nulls and carriage returns');
is(quote_unit_word(q{A "B" \ C}), '"A \"B\" \\\\ C"',
   'Environment word quoting escapes quotes and backslashes');
is_deeply([ format_environment_directives(
              q{NODE_ENV=production APP_NAME="My App"}) ],
          [ "Environment=\"NODE_ENV=production\"\n",
            "Environment=\"APP_NAME=My App\"\n" ],
          'environment directives split shell-style words');
is(format_output_value('/var/log/demo.log'), 'append:/var/log/demo.log',
   'absolute log paths append by default');
is(format_output_value('journal'), 'journal',
   'systemd log targets are preserved');
is(format_output_value(" \n "), undef,
   'blank log target is ignored');

ok(valid_duration('30s'), 'duration accepts seconds');
ok(valid_duration('1min 30s'), 'duration accepts compound values');
ok(valid_duration('infinity'), 'duration accepts infinity');
ok(!valid_duration('soon'), 'duration rejects arbitrary words');
ok(valid_path('/run/app.pid', 0, 0), 'absolute path is valid');
ok(valid_path('-/etc/default/app', 1, 0), 'dash-prefixed path can be allowed');
ok(valid_path('~/app', 0, 1), 'tilde path can be allowed');
ok(!valid_path('relative/path', 0, 0), 'relative path is invalid by default');
ok(!valid_path("/tmp/a b", 0, 0), 'path with spaces is invalid');
is(path_unit_name('/mnt/data', 'mount'), 'mnt-data.mount',
   'mount unit name is derived from path');
is(path_unit_name('/mnt/data', 'automount'), 'mnt-data.automount',
   'automount unit name is derived from path');
is(path_unit_name('/', 'mount'), '-.mount',
   'root mount unit name is derived from path');
is(path_unit_name('/mnt/data', 'service'), undef,
   'path-derived unit names are limited to mount-like types');
ok(valid_output('append:/var/log/app.log'), 'append output target is valid');
ok(valid_output('/var/log/app.log'), 'absolute output path is valid');
ok(!valid_output("journal\nbad"), 'output target rejects newlines');

my $work = tempdir(CLEANUP => 1);
my $service_file = "$work/demo.service";
my $service_data = render_unit({
    type => 'service',
    description => "Demo\nService",
    service => {
        start => "/usr/bin/start-one\n/usr/bin/start-two",
        stop => "/usr/bin/stop",
        reload => "/usr/bin/reload",
        pidfile => "/run/demo.pid\n",
    },
    options => {
        before => "network.target\nignored.target",
        after => 'network-online.target',
        wants => 'network-online.target',
        requires => 'postgresql.service',
        conflicts => 'old-demo.service',
        onfailure => 'notify@%n.service',
        onsuccess => 'report.service',
        startpre => "/usr/bin/pre\n/usr/bin/pre2",
        startpost => '/usr/bin/post',
        stoppost => '/usr/bin/cleanup',
        env => q{A=1 B="two words"},
        envfile => '-/etc/default/demo',
        user => 'demo',
        group => 'demo',
        killmode => 'mixed',
        workdir => '/srv/demo',
        restart => 'on-failure',
        restartsec => '5s',
        watchdogsec => '30s',
        timeout => '99s',
        timeoutstartsec => '15s',
        timeoutstopsec => '10s',
        limitnofile => '65535',
        logstd => '/var/log/demo.log',
        logerr => 'journal',
        syslogid => 'demo',
        nonewprivs => 1,
        privatetmp => 1,
        protectsystem => 'full',
        readwritepaths => '/var/lib/demo',
        wantedby => 'multi-user.target',
    },
});
write_unit_file($service_file, $service_data);
my $service = slurp_test_file($service_file);
like($service, qr/^\[Unit\]$/m, 'service file has Unit section');
like($service, qr/^Description=Demo Service$/m, 'description is single-line');
like($service, qr/^Before=network\.target ignored\.target$/m,
     'relationship scalar is cleaned');
like($service, qr/^Type=oneshot$/m, 'multiple start commands default to oneshot');
is(() = $service =~ /^ExecStart=/mg, 2,
   'oneshot multi-command service emits one ExecStart per command');
like($service, qr/^ExecStartPre=\/usr\/bin\/pre$/m, 'start pre hook written');
like($service, qr/^ExecStartPost=\/usr\/bin\/post$/m, 'start post hook written');
like($service, qr/^ExecStopPost=\/usr\/bin\/cleanup$/m, 'stop post hook written');
like($service, qr/^ExecStop=\/usr\/bin\/stop$/m, 'stop command written');
like($service, qr/^ExecReload=\/usr\/bin\/reload$/m, 'reload command written');
like($service, qr/^Environment="A=1"$/m, 'first environment variable written');
like($service, qr/^Environment="B=two words"$/m,
     'quoted environment variable written');
like($service, qr/^EnvironmentFile=-\/etc\/default\/demo$/m,
     'environment file written');
like($service, qr/^User=demo$/m, 'system service user written');
like($service, qr/^Group=demo$/m, 'system service group written');
like($service, qr/^Restart=on-failure$/m, 'restart policy written');
like($service, qr/^RestartSec=5s$/m, 'restart delay written');
like($service, qr/^TimeoutStartSec=15s$/m, 'startup timeout uses TimeoutStartSec');
unlike($service, qr/^TimeoutSec=/m, 'legacy TimeoutSec is not emitted');
like($service, qr/^TimeoutStopSec=10s$/m, 'shutdown timeout written');
like($service, qr/^StandardOutput=append:\/var\/log\/demo\.log$/m,
     'absolute stdout path appends');
like($service, qr/^StandardError=journal$/m, 'stderr target written');
like($service, qr/^NoNewPrivileges=yes$/m, 'NoNewPrivileges written');
like($service, qr/^PrivateTmp=yes$/m, 'PrivateTmp written');
like($service, qr/^ProtectSystem=full$/m, 'ProtectSystem written');
like($service, qr/^ReadWritePaths=\/var\/lib\/demo$/m,
     'ReadWritePaths written');
like($service, qr/^WantedBy=multi-user\.target$/m, 'install target written');

my $simple_file = "$work/simple.service";
my $simple_data = render_unit({
    type => 'service',
    description => 'Simple',
    service => {
        start => "/bin/one\n/bin/two",
    },
    options => {
        type => 'simple',
    },
});
write_unit_file($simple_file, $simple_data);
my $simple = slurp_test_file($simple_file);
like($simple, qr/^Type=simple$/m, 'explicit service type preserved');
is(() = $simple =~ /^ExecStart=/mg, 1,
   'non-oneshot multi-command service emits one shell ExecStart');
like($simple, qr/^ExecStart=.* -c '\/bin\/one; \/bin\/two'$/m,
     'non-oneshot multi-command service joins commands through shell');

my $timer_file = "$work/demo.timer";
my $timer_data = render_unit({
    type => 'timer',
    description => "Timer\nDesc",
    body => "OnCalendar=daily\nPersistent=true\n",
    options => {
        wantedby => 'timers.target',
        after => 'network.target',
    },
});
write_unit_file($timer_file, $timer_data);
my $timer = slurp_test_file($timer_file);
like($timer, qr/^\[Unit\]\nDescription=Timer Desc\nAfter=network\.target/ms,
     'non-service unit writes common Unit settings');
like($timer, qr/^\[Timer\]\nOnCalendar=daily\nPersistent=true/m,
     'timer body is wrapped in Timer section');
like($timer, qr/^\[Install\]\nWantedBy=timers\.target/m,
     'non-service install target is written');

my $structured_timer = render_timer_body({
    oncalendar => 'Mon..Fri 09:00',
    onbootsec => '5min',
    onunitactivesec => '1h',
    persistent => 1,
    randomizeddelaysec => '10min',
    accuracysec => '1min',
    unit => 'demo.service',
});
like($structured_timer, qr/^OnCalendar=Mon\.\.Fri 09:00$/m,
     'structured timer writes OnCalendar');
like($structured_timer, qr/^OnBootSec=5min$/m,
     'structured timer writes OnBootSec');
like($structured_timer, qr/^OnUnitActiveSec=1h$/m,
     'structured timer writes OnUnitActiveSec');
like($structured_timer, qr/^Persistent=yes$/m,
     'structured timer writes Persistent');
like($structured_timer, qr/^RandomizedDelaySec=10min$/m,
     'structured timer writes RandomizedDelaySec');
like($structured_timer, qr/^AccuracySec=1min$/m,
     'structured timer writes AccuracySec');
like($structured_timer, qr/^Unit=demo\.service$/m,
     'structured timer writes activated unit');

my $structured_socket = render_socket_body({
    listenstream => '127.0.0.1:8080',
    listendatagram => '10514',
    listenfifo => '/run/demo.fifo',
    accept => 1,
    user => 'demo',
    group => 'demo',
    mode => '0660',
    service => 'demo.service',
});
like($structured_socket, qr/^ListenStream=127\.0\.0\.1:8080$/m,
     'structured socket writes stream listener');
like($structured_socket, qr/^ListenDatagram=10514$/m,
     'structured socket writes datagram listener');
like($structured_socket, qr/^ListenFIFO=\/run\/demo\.fifo$/m,
     'structured socket writes FIFO listener');
like($structured_socket, qr/^Accept=yes$/m,
     'structured socket writes Accept');
like($structured_socket, qr/^SocketUser=demo$/m,
     'structured socket writes SocketUser');
like($structured_socket, qr/^SocketGroup=demo$/m,
     'structured socket writes SocketGroup');
like($structured_socket, qr/^SocketMode=0660$/m,
     'structured socket writes SocketMode');
like($structured_socket, qr/^Service=demo\.service$/m,
     'structured socket writes service target');

my $structured_path = render_path_body({
    exists => '/run/demo.ready',
    existsglob => '/run/demo/*.ready',
    changed => '/etc/demo.conf',
    modified => '/etc/demo.d',
    directorynotempty => '/var/spool/demo',
    makedirectory => 1,
    unit => 'reload-demo.service',
});
like($structured_path, qr/^PathExists=\/run\/demo\.ready$/m,
     'structured path writes PathExists');
like($structured_path, qr/^PathExistsGlob=\/run\/demo\/\*\.ready$/m,
     'structured path writes PathExistsGlob');
like($structured_path, qr/^PathChanged=\/etc\/demo\.conf$/m,
     'structured path writes PathChanged');
like($structured_path, qr/^PathModified=\/etc\/demo\.d$/m,
     'structured path writes PathModified');
like($structured_path, qr/^DirectoryNotEmpty=\/var\/spool\/demo$/m,
     'structured path writes DirectoryNotEmpty');
like($structured_path, qr/^MakeDirectory=yes$/m,
     'structured path writes MakeDirectory');
like($structured_path, qr/^Unit=reload-demo\.service$/m,
     'structured path writes activated unit');

my $mount_data = render_unit({
    type => 'mount',
    description => 'Data mount',
    body => render_mount_body('/dev/disk/by-label/data', '/data',
                              'xfs', 'defaults'),
    options => {
        wantedby => 'local-fs.target',
    },
});
like($mount_data, qr/^\[Mount\]\nWhat=\/dev\/disk\/by-label\/data\nWhere=\/data/m,
     'mount body is wrapped in Mount section');
like($mount_data, qr/^Options=defaults$/m, 'mount options are written');
is(mount_where_from_data($mount_data), '/data',
   'mount Where path can be read from unit data');
like($mount_data, qr/^WantedBy=local-fs\.target$/m,
     'mount install target is written');

my $automount_data = render_unit({
    type => 'automount',
    description => 'Data automount',
    body => render_automount_body('/data', '5min', '0755'),
    options => {
        wantedby => 'local-fs.target',
    },
});
like($automount_data,
     qr/^\[Automount\]\nWhere=\/data\nTimeoutIdleSec=5min\nDirectoryMode=0755/m,
     'automount body is wrapped in Automount section');

my $swap_body = render_swap_body({
    what => '/swapfile',
    priority => '10',
    options => 'discard',
    timeoutsec => '30s',
});
like($swap_body, qr/^What=\/swapfile$/m,
     'structured swap writes What');
like($swap_body, qr/^Priority=10$/m,
     'structured swap writes Priority');
like($swap_body, qr/^Options=discard$/m,
     'structured swap writes Options');
like($swap_body, qr/^TimeoutSec=30s$/m,
     'structured swap writes TimeoutSec');

my $slice_data = render_unit({
    type => 'slice',
    description => 'Work slice',
    body => '',
    options => {
        wantedby => 'slices.target',
    },
});
unlike($slice_data, qr/^\[Slice\]$/m,
       'empty slice body does not emit an empty Slice section');
like($slice_data, qr/^WantedBy=slices\.target$/m,
     'slice install target is written');
my $slice_body = render_slice_body({
    cpuweight => '200',
    memorymax => '512M',
    tasksmax => '500',
    ioweight => '300',
});
like($slice_body, qr/^CPUWeight=200$/m,
     'structured slice writes CPUWeight');
like($slice_body, qr/^MemoryMax=512M$/m,
     'structured slice writes MemoryMax');
like($slice_body, qr/^TasksMax=500$/m,
     'structured slice writes TasksMax');
like($slice_body, qr/^IOWeight=300$/m,
     'structured slice writes IOWeight');

ok(valid_unit_name('demo.service'), 'service unit name is valid');
ok(valid_unit_name('demo@one.service'), 'instance unit name is valid');
ok(!valid_unit_name('demo@.service'), 'template unit name is rejected');
ok(!valid_unit_name('../demo.service'), 'path traversal unit name is rejected');
ok(valid_unit_name('demo.mount'), 'known storage unit name is valid');
ok(valid_creatable_unit_name('demo.mount'),
   'storage unit name is valid for creation');
ok(valid_creatable_unit_name('demo.slice'),
   'slice unit name is valid for creation');
ok(!valid_creatable_unit_name('demo.mount', 1),
   'storage unit name is not valid for user creation');
ok(valid_creatable_unit_name('demo.slice', 1),
   'slice unit name is valid for user creation');
ok(!valid_creatable_unit_name('demo.device'),
   'generated device units are not creatable');
ok(valid_unit_file_name('demo.mount'),
   'manual unit filename accepts storage unit types');
ok(valid_unit_file_name('demo@.service'),
   'manual unit filename accepts template unit files');
is(get_unit_type_from_name('demo.socket'), 'socket',
   'unit type is detected from suffix');
is(get_unit_type_from_name('demo.unknown'), undef,
   'unknown unit type suffix is ignored');
ok(unit_startable('demo.service'), 'service unit can be started');
ok(unit_restartable('demo.service'), 'service unit can be restarted');
ok(!unit_startable('session-2.scope'), 'scope unit is not startable');
ok(!unit_restartable('session-2.scope'), 'scope unit is not restartable');
ok(!unit_startable('dev-sda.device'), 'device unit is not startable');
ok(!unit_restartable('dev-sda.device'), 'device unit is not restartable');
{
    my $base = abs_path($work);
    my $local_root = "$base/root-systemd";
    my $real_root = "$base/usr-lib/systemd/system";
    my $link_parent = "$base/lib";
    my $link_root = "$link_parent/systemd/system";
    make_path($local_root, $real_root);
    symlink("$base/usr-lib", $link_parent) or die "symlink $link_parent: $!";
    local *main::get_system_unit_file_root_candidates = sub {
        return ($local_root, $link_root, $real_root);
    };
    is_deeply([ get_system_unit_file_roots() ],
              [ $local_root, $real_root ],
              'system unit roots skip symlink aliases');
    local $config{'manual_vendor_units'} = 0;
    local *main::local_unit_file_root = sub {
        my ($root) = @_;
        return $root eq $local_root;
    };
    is_deeply([ get_system_unit_file_roots() ],
              [ $local_root ],
              'system unit roots can omit vendor directories');
}
is(get_unit_section('path'), 'Path', 'path section name');
is(get_unit_section('mount'), 'Mount', 'mount section name');
is(get_unit_section('slice'), 'Slice', 'slice section name');
is(get_default_install_target('service', 0), 'multi-user.target',
   'system service default target');
is(get_default_install_target('service', 1), 'default.target',
   'user service default target');
is(get_default_install_target('timer', 0), 'timers.target',
   'timer default target');
is(get_default_install_target('mount', 0), 'local-fs.target',
   'system mount default target');
is(get_default_install_target('swap', 0), 'swap.target',
   'system swap default target');
is(get_default_install_target('slice', 0), 'slices.target',
   'slice default target');
is(index_url('demo.timer', 0, undef), 'index.cgi?mode=timer',
   'system unit return URL selects type tab');
is(index_url('mnt-data.mount', 0, undef), 'index.cgi?mode=storage',
   'system storage unit return URL selects storage tab');
is(index_url('session-1.scope', 0, undef), 'index.cgi?mode=resources',
   'system resource unit return URL selects resources tab');
is(index_url('dev-sda.device', 0, undef), 'index.cgi?mode=device',
   'system device unit return URL selects devices tab');
is(index_url('demo.service', 1, 'alice'),
   'index.cgi?mode=user&scope=user&unituser=alice',
   'user unit return URL selects user tab and owner');
ok(!get_user_details("bad/user"),
   'user details reject names that cannot be Unix users');
{
    my $login = getpwuid($>);
    SKIP: {
        skip('current UID has no passwd entry', 2) if (!$login);
        my $details = get_user_details($login);
        ok($details && $details->{'home'} =~ m{^/},
           'user details resolve current Unix user');
        is(get_user_root($login),
           $details->{'home'}.'/.config/systemd/user',
           'user root is derived from Unix home directory');
    }
}
like(get_unit_root(), qr{^/(etc|usr/lib|lib)/systemd/system$},
     'systemd root falls back to a canonical unit directory');
{
    local *main::list_units = sub {
        return ( { name => 'demo.service' } );
    };
    ok(!is_unit('demo'), 'bare service name is not treated as a unit');
    ok(is_unit('demo.service'), 'typed service name matches systemd unit');
    ok(!is_unit('missing'), 'unknown service name does not match');
}

{
    my @cmds;
    local *main::backquote_logged = sub {
        push(@cmds, $_[0]);
        $? = 0;
        return 'ok';
    };
    local *main::backquote_command = sub { return '' };
    my ($ok, $out) = start_unit('evil;touch.service');
    ok(!$ok, 'system service start rejects invalid unit names');
    is($out, 'bad unit name', 'invalid unit returns validation error');
    is(scalar(@cmds), 0, 'invalid system unit name builds no command');
    ($ok, $out) = start_unit('demo.service');
    ok($ok, 'system service start reports success from command exit');
    is($out, 'ok', 'system service start returns command output');
    like($cmds[0], qr/systemctl start demo\\.service/,
         'system service start quotes unit names');
    ($ok, $out) = stop_unit('demo.service');
    like($cmds[-1], qr/systemctl stop demo\\.service/,
         'stop command uses systemctl');
    ($ok, $out) = restart_unit('demo.service');
    like($cmds[-1], qr/systemctl restart demo\\.service/,
         'restart command uses systemctl');
    ($ok, $out) = reload_unit('demo.service');
    like($cmds[-1], qr/systemctl reload demo\\.service/,
         'reload command uses systemctl');
    ($ok, $out) = status_unit('demo.service');
    like($cmds[-1], qr/systemctl --full --no-pager status demo\\.service/,
         'status command uses full non-paged output');
    ($ok, $out) = properties_unit('demo.service');
    like($cmds[-1], qr/systemctl --full --no-pager show demo\\.service/,
         'properties command uses full non-paged output');
    ($ok, $out) = dependencies_unit('demo.service');
    like($cmds[-1],
         qr/systemctl --full --no-pager list-dependencies demo\\.service/,
         'dependency command uses full non-paged output');
}

{
    my @cmds;
    my $reloaded = 0;
    local *main::backquote_logged = sub {
        push(@cmds, $_[0]);
        $? = 0;
        return 'ok';
    };
    local *main::reload_manager = sub { $reloaded++ };
    my ($ok) = enable_unit('demo.timer');
    ok($ok, 'enable_unit reports success');
    like($cmds[0], qr/systemctl enable demo\\.timer/,
         'enable command is quoted');
    is($reloaded, 1, 'enable reloads systemd once');
    ($ok) = disable_unit('demo.timer');
    ok($ok, 'disable_unit reports success');
    is($reloaded, 2, 'disable reloads systemd once');
    ($ok) = mask_unit('demo.timer');
    ok($ok, 'mask_unit reports success');
    like($cmds[-1], qr/systemctl mask demo\\.timer/,
         'mask command is quoted');
    is($reloaded, 3, 'mask reloads systemd once');
    ($ok) = unmask_unit('demo.timer');
    ok($ok, 'unmask_unit reports success');
    like($cmds[-1], qr/systemctl unmask demo\\.timer/,
         'unmask command is quoted');
    is($reloaded, 4, 'unmask reloads systemd once');
}

{
    my $reloaded = 0;
    my $message = "The unit files have no installation config. ".
                  "This means they are not meant to be enabled or disabled.";
    local *main::backquote_logged = sub {
        $? = 0;
        return $message;
    };
    local *main::reload_manager = sub { $reloaded++ };
    my ($ok, $out) = disable_unit('static.target');
    ok(!$ok, 'disable_unit reports no change for static units');
    ok(startup_change_skipped($out),
       'static enable-disable message is detected');
    is($reloaded, 1, 'static disable still reloads after command');

    local *main::run_user_systemctl = sub {
        return (1, $message);
    };
    local *main::check_user_unit_dirs = sub {
        return (1, undef);
    };
    ($ok, $out) = enable_user_unit('alice', 'static.target');
    ok(!$ok, 'user enable reports no change for static units');
    ok(startup_change_skipped($out),
       'user static enable-disable message is detected');
}

{
    my @cmds;
    local *main::has_command = sub { $_[0] eq 'journalctl' ? '/bin/journalctl' : undef };
    local *main::backquote_logged = sub {
        push(@cmds, $_[0]);
        $? = 0;
        return "logs";
    };
    local $config{'logs_lines'} = 123;
    my ($ok, $out) = logs_unit('demo.service');
    ok($ok, 'logs_unit reports success');
    is($out, 'logs', 'logs_unit returns output');
    like($cmds[0], qr/\\\/bin\\\/journalctl --no-pager --unit demo\\.service --lines 123/,
         'journalctl command quotes unit name and uses configured line count');
    unlike($cmds[0], qr/--boot/, 'journalctl omits boot filter by default');

    local $config{'logs_current_boot'} = 1;
    logs_unit('demo.service');
    like($cmds[-1], qr/--boot/, 'journalctl adds boot filter when configured');
}

{
    local *main::backquote_command = sub { return "MainPID=1234\n" };
    is(get_unit_pid('demo.service'), 1234, 'unit PID is parsed');
}

{
    local *main::backquote_logged = sub {
        $? = 0;
        return "active\n";
    };
    ok(is_active('demo.service'), 'active unit returns true');
    my ($rv, $out) = is_active('demo.service');
    is($rv, 0, 'active command exit code returned in list context');
    is($out, 'active', 'active command output is trimmed');
}

{
    my @cmds;
    local *main::has_command = sub { $_[0] eq 'systemctl' ? '/bin/systemctl' : undef };
    local *main::system_logged = sub {
        push(@cmds, $_[0]);
        return 0;
    };
    reload_manager();
    is($cmds[0], 'systemctl daemon-reload >/dev/null 2>&1',
       'reload_manager reloads through systemctl when available');
}

{
    my $root = "$work/system-root";
    my $vendor_root = "$work/system-vendor-root";
    make_path($root, $vendor_root);
    my $reloaded = 0;
    local *main::get_local_unit_root = sub { return $root };
    local *main::get_unit_root = sub {
        my ($name) = @_;
        return $vendor_root if (defined($name) && $name eq 'vendor.service');
        return $root;
    };
    local *main::get_system_unit_file_root_candidates = sub {
        return ($root, $vendor_root);
    };
    local *main::reload_manager = sub { $reloaded++ };
    local *main::has_command = sub { return };
    my ($ok) = create_system_unit(
        'created.service',
        render_unit({
            type => 'service',
            description => 'Created',
            service => {
                start => '/bin/true',
            },
        }));
    ok($ok, 'create_system_unit reports service creation success');
    ok(-f "$root/created.service", 'create_system_unit writes service file');
    ($ok) = create_system_unit(
        'created.timer',
        render_unit({
            type => 'timer',
            description => 'Created timer',
            body => 'OnCalendar=daily',
        }));
    ok($ok, 'create_system_unit reports timer creation success');
    ok(-f "$root/created.timer", 'create_system_unit writes timer file');
    is($reloaded, 2, 'system unit creation reloads systemd');

    write_test_file("$root/demo", "bare");
    write_test_file("$root/demo.service", "typed");
    ($ok) = delete_system_unit('demo');
    ok(!$ok, 'delete_system_unit rejects bare service name');
    ok(-e "$root/demo", 'delete_system_unit leaves suffix-less file alone');
    ok(-e "$root/demo.service", 'delete_system_unit leaves typed file after bare rejection');
    ($ok) = delete_system_unit('demo.service');
    ok($ok, 'delete_system_unit accepts typed service name');
    ok(!-e "$root/demo.service", 'delete_system_unit removes service file');
    my $out;
    ($ok, $out) = delete_system_unit('demo.service');
    ok(!$ok, 'delete_system_unit rejects already-missing unit');
    is($out, $text{'systemd_egone'},
       'delete_system_unit reports stale missing unit');
    write_test_file("$vendor_root/vendor.service", "packaged");
    ($ok, $out) = delete_system_unit('vendor.service');
    ok(!$ok, 'delete_system_unit rejects packaged system unit files');
    is($out, $text{'systemd_elocaldelete'},
       'delete_system_unit reports local-only delete policy');
    ok(-e "$vendor_root/vendor.service",
       'delete_system_unit leaves packaged system unit file alone');
    {
        local $config{'delete_vendor_units'} = 1;
        ($ok, $out) = delete_system_unit('vendor.service');
        ok($ok, 'delete_system_unit can delete packaged unit files when configured');
        ok(!-e "$vendor_root/vendor.service",
           'delete_system_unit removes configured packaged unit file');
    }
}

{
    my $local_root = "$work/local-units";
    my $packaged_root = "$work/packaged-units";
    make_path($local_root, $packaged_root);
    write_test_file("$local_root/demo.service", "[Unit]\nDescription=Demo\n");
    write_test_file("$local_root/local.path", "");
    write_test_file("$local_root/work.slice", "");
    write_test_file("$local_root/template@.service", "");
    make_path("$local_root/demo.service.d");
    write_test_file("$local_root/demo.service.d/00-local.conf",
                    "[Service]\nRestart=always\n");
    write_test_file("$packaged_root/vendor.socket", "");
    write_test_file("$packaged_root/vendor.mount", "");
    symlink("$packaged_root/vendor.socket", "$local_root/vendor-link.service");
    my @commands;
    local @main::list_units_cache = ();
    local *main::get_system_unit_file_roots = sub {
        return ($local_root, $packaged_root);
    };
    local *main::get_system_unit_file_root_candidates = sub {
        return ($local_root, $packaged_root);
    };
    local *main::get_local_unit_root = sub {
        return $local_root;
    };
    local *main::get_system_dropin_roots = sub {
        return ($local_root);
    };
    local *main::list_all_user_units = sub { return ( ) };
    local *main::get_unit_root = sub {
        my ($name, $packaged) = @_;
        return $packaged ? $packaged_root : $local_root;
    };
    local *main::backquote_command = sub {
        my ($cmd) = @_;
        push(@commands, $cmd);
        $? = 0;
        return "demo.service loaded active running Demo\n".
               "dev-sda.device loaded active plugged Disk\n".
               "session-2.scope loaded active running Session\n".
               "bad;unit.service loaded inactive dead Bad\n"
            if ($cmd =~ /list-units/);
        return "late.timer disabled\n"
            if ($cmd =~ /list-unit-files/);
        return join("\n",
            "Id=demo.service",
            "Description=Demo Service",
            "UnitFileState=enabled",
            "ActiveState=active",
            "SubState=running",
            "ExecMainPID=777",
            "FragmentPath=$local_root/demo.service",
            "",
            "Id=local.path",
            "Description=Local Path",
            "UnitFileState=disabled",
            "ActiveState=inactive",
            "SubState=dead",
            "ExecMainPID=0",
            "FragmentPath=$local_root/local.path",
            "",
            "Id=vendor.socket",
            "Description=Vendor Socket",
            "UnitFileState=static",
            "ActiveState=inactive",
            "SubState=dead",
            "ExecMainPID=0",
            "FragmentPath=$packaged_root/vendor.socket",
            "",
            "Id=vendor.mount",
            "Description=Vendor Mount",
            "UnitFileState=static",
            "ActiveState=inactive",
            "SubState=dead",
            "ExecMainPID=0",
            "FragmentPath=$packaged_root/vendor.mount",
            "",
            "Id=work.slice",
            "Description=Work Slice",
            "UnitFileState=static",
            "ActiveState=active",
            "SubState=active",
            "ExecMainPID=0",
            "FragmentPath=$local_root/work.slice",
            "",
            "Id=session-2.scope",
            "Description=Session Scope",
            "UnitFileState=transient",
            "ActiveState=active",
            "SubState=running",
            "ExecMainPID=0",
            "FragmentPath=",
            "",
            "Id=dev-sda.device",
            "Description=Disk Device",
            "UnitFileState=generated",
            "ActiveState=active",
            "SubState=plugged",
            "ExecMainPID=0",
            "FragmentPath=",
            "",
            "Id=late.timer",
            "Description=Late Timer",
            "UnitFileState=disabled",
            "ActiveState=inactive",
            "SubState=dead",
            "ExecMainPID=0",
            "FragmentPath=$local_root/late.timer",
            "",
            "Id=legacy.service",
            "Description=LSB: Legacy",
            "UnitFileState=enabled",
            "ActiveState=active",
            "SubState=running",
            "ExecMainPID=1",
            "FragmentPath=$local_root/legacy.service",
            "") if ($cmd =~ /systemctl show/);
        return "";
    };
    local *main::has_command = sub { return };
    my @units = list_units();
    my ($show_command) = grep { /systemctl show/ } @commands;
    my %by = map { $_->{'name'} => $_ } @units;
    ok($by{'demo.service'}, 'list_units includes active units');
    ok($by{'local.path'}, 'list_units includes local unit files');
    ok($by{'vendor.socket'}, 'list_units includes packaged listed types');
    ok($by{'vendor.mount'}, 'list_units includes packaged storage units');
    ok($by{'work.slice'}, 'list_units includes resource-control units');
    ok($by{'session-2.scope'}, 'list_units includes transient scopes');
    ok($by{'dev-sda.device'}, 'list_units includes device units');
    is($by{'dev-sda.device'}->{'file'}, '',
       'generated device units do not get fake editable files');
    ok($by{'late.timer'}, 'list_units includes disabled unit files');
    ok(!$by{'legacy.service'}, 'list_units filters LSB wrappers');
    ok(!$by{'template@.service'}, 'list_units filters templates');
    like($show_command, qr/demo\\.service/,
         'list_units quotes names before systemctl show');
    unlike($show_command, qr/bad;unit/,
           'list_units filters invalid names before systemctl show');
    is($by{'demo.service'}->{'boot'}, 1, 'enabled unit boot status parsed');
    is($by{'vendor.socket'}->{'boot'}, 2, 'static unit boot status parsed');
    is($by{'demo.service'}->{'status'}, 1, 'active unit status parsed');
    is($by{'demo.service'}->{'unitstate'}, 'enabled',
       'enabled unit file state is preserved');
    is($by{'vendor.socket'}->{'unitstate'}, 'static',
       'static unit file state is preserved');
    is($by{'demo.service'}->{'runtime'}, 'active',
       'runtime active state is preserved');
    is($by{'demo.service'}->{'substate'}, 'running',
       'runtime sub-state is preserved');
    my %manual = map { $_->{'file'}, $_ } list_manual_unit_files();
    ok($manual{"$local_root/template@.service"},
       'manual unit files include templates');
    ok($manual{"$packaged_root/vendor.mount"},
       'manual unit files include vendor non-tab unit types');
    ok($manual{"$local_root/demo.service.d/00-local.conf"},
       'manual unit files include system drop-in override files');
    is($manual{"$local_root/demo.service.d/00-local.conf"}->{'kind'},
       'dropin', 'manual drop-in descriptor is marked');
    ok(manual_unit_file_writable($manual{"$local_root/local.path"}),
       'manual local system unit files are writable');
    ok(!manual_unit_file_writable($manual{"$packaged_root/vendor.mount"}),
       'manual packaged unit files are read-only by default');
    ok(!system_unit_file_writable({
            name => 'vendor-link.service',
            file => "$local_root/vendor-link.service",
            unitstate => 'enabled',
        }),
       'local symlink unit files are not edited directly');
    {
        local $config{'edit_vendor_units'} = 1;
        ok(manual_unit_file_writable($manual{"$packaged_root/vendor.mount"}),
           'manual packaged unit files are writable when configured');
    }
    ok(!manual_system_unit_file_safe("$local_root/../escape.service"),
       'manual system unit file safety rejects traversal');
    my $manual_info = manual_unit_file("$local_root/local.path");
    ok($manual_info, 'manual_unit_file returns allowed file descriptor');
    my ($ok, $err) = write_manual_unit_file($manual_info,
                                            "[Path]\nPathExists=/tmp\n");
    ok($ok, 'write_manual_unit_file writes system unit files');
    is(read_manual_unit_file($manual_info), "[Path]\nPathExists=/tmp\n",
       'read_manual_unit_file reads system unit files');
    my $manual_dropin_info =
        manual_unit_file("$local_root/demo.service.d/00-local.conf");
    ok($manual_dropin_info,
       'manual_unit_file returns allowed drop-in descriptor');
    ok(manual_unit_file_writable($manual_dropin_info),
       'manual system drop-in files remain writable');
    is(read_manual_unit_file($manual_dropin_info),
       "[Service]\nRestart=always\n",
       'read_manual_unit_file reads system drop-in files');
    ($ok, $err) = write_manual_unit_file(
        $manual_dropin_info, "[Service]\nRestart=on-failure\n");
    ok($ok, 'write_manual_unit_file writes system drop-in files');
    is(slurp_test_file("$local_root/demo.service.d/00-local.conf"),
       "[Service]\nRestart=on-failure\n",
       'manual system drop-in write preserves exact file');
    ($ok, $err) = write_manual_unit_file(
        $manual{"$packaged_root/vendor.mount"},
        "[Mount]\nWhat=/tmp\nWhere=/vendor\n");
    ok(!$ok, 'write_manual_unit_file rejects packaged unit writes by default');
    is($err, $text{'systemd_evendoredit'},
       'write_manual_unit_file reports packaged unit edit policy');
    unlink($main::unit_config_change_flag);
    unlink($main::daemon_reload_time_flag);
    ok(!needs_daemon_reload(), 'daemon reload is not needed initially');
    mark_units_changed();
    ok(needs_daemon_reload(), 'manual unit edits require daemon reload');
    like(action_links(), qr/restart\.cgi.*Reload/s,
         'header action links include reload when needed');
    mark_daemon_reloaded();
    ok(!needs_daemon_reload(), 'daemon reload clears manual edit reminder');
    {
        local *main::get_user_details = sub {
            return $_[0] eq 'alice' ?
                { user => 'alice', uid => 1001, gid => 1001,
                  home => "$work/alice" } : undef;
        };
        local %access = (view_user => 1, manual_user => 1,
                         mode => 1, users => 'alice');
        local %in = (unituser => 'alice');
        unlink(user_daemon_reload_flag_file('alice', 'changed'));
        unlink(user_daemon_reload_flag_file('alice', 'reloaded'));
        ok(!needs_user_daemon_reload('alice'),
           'user daemon reload is not needed initially');
        mark_user_units_changed('alice');
        ok(needs_user_daemon_reload('alice'),
           'manual user unit edits require user manager reload');
        like(action_links(), qr/restart_user\.cgi\?user=alice.*Reload User Manager/s,
             'header action links include user manager reload when needed');
        mark_user_daemon_reloaded('alice');
        ok(!needs_user_daemon_reload('alice'),
           'user manager reload clears user edit reminder');
    }
}

{
    my $verify_root = "$work/verify-units";
    make_path($verify_root);
    my @verify_commands;
    my $verify_count = 0;
    local *main::has_command = sub {
        return $_[0] eq 'systemd-analyze' ? '/bin/systemd-analyze' : undef;
    };
    local *main::tempname = sub {
        return "$verify_root/verify-".($verify_count++);
    };
    local *main::backquote_logged = sub {
        my ($cmd) = @_;
        push(@verify_commands, $cmd);
        $? = 0;
        return "";
    };
    my ($ok, $err) = verify_unit_data(
        '/etc/systemd/system/demo.service', "[Unit]\nDescription=Demo\n", 0);
    ok($ok, 'verify_unit_data accepts clean system unit data');
    like($verify_commands[-1], qr/verify .*demo\\.service/,
         'verify_unit_data preserves the real unit basename');
    unlike($verify_commands[-1], qr/--user/,
           'system unit verification does not use user mode');
    ok(!-e "$verify_root/verify-0/demo.service",
       'verify_unit_data removes successful temp files');

    ($ok, $err) = verify_unit_data(
        '/home/alice/.config/systemd/user/demo.service',
        "[Unit]\nDescription=Demo\n", 1);
    ok($ok, 'verify_unit_data accepts clean user unit data');
    like($verify_commands[-1], qr/--user verify/,
         'user unit verification uses user mode');

    local *main::backquote_logged = sub {
        my ($cmd) = @_;
        push(@verify_commands, $cmd);
        $? = 0;
        return "bad.service:1: Unknown section 'UnitX'. Ignoring.\n";
    };
    ($ok, $err) = verify_unit_data(
        '/etc/systemd/system/warn.service', "[UnitX]\nDescription=Bad\n", 0);
    ok(!$ok, 'verify_unit_data rejects analyzer warnings');
    like($err, qr/Unknown section/,
         'verify_unit_data reports analyzer warning output');
    ok(!-e "$verify_root/verify-2/warn.service",
       'verify_unit_data removes warning temp files');

    local *main::backquote_logged = sub {
        my ($cmd) = @_;
        push(@verify_commands, $cmd);
        $? = 1;
        return "<bad unit>\n";
    };
    ($ok, $err) = verify_unit_data(
        '/etc/systemd/system/bad.service', "[Service]\nBroken\n", 0);
    ok(!$ok, 'verify_unit_data rejects analyzer failures');
    like($err, qr/<tt[^>]*>&lt;bad unit&gt;/,
         'verify_unit_data escapes analyzer failure output in tt tag');
    ok(!-e "$verify_root/verify-3/bad.service",
       'verify_unit_data removes failed temp files');

    local *main::backquote_logged = sub {
        my ($cmd) = @_;
        push(@verify_commands, $cmd);
        $? = 0;
        return "";
    };
    ($ok, $err) = verify_dropin_data(
        '/etc/systemd/system/drop.service',
        "[Unit]\nDescription=Drop\n[Service]\nExecStart=/bin/true\n",
        "[Service]\nRestart=always\n", 0);
    ok($ok, 'verify_dropin_data accepts clean drop-in data');
    like($verify_commands[-1], qr/verify .*drop\\.service/,
         'verify_dropin_data verifies the base unit name');
    ok(!-e "$verify_root/verify-4/drop.service.d/override.conf",
       'verify_dropin_data removes temporary override files');
    ($ok, $err) = verify_dropin_data(
        '/etc/systemd/system/drop.service',
        "[Unit]\nDescription=Drop\n[Service]\nExecStart=/bin/true\n",
        "[Install]\nWantedBy=multi-user.target\n", 0);
    ok(!$ok, 'verify_dropin_data rejects Install sections');
    is($err, $text{'systemd_edropininstall'},
       'verify_dropin_data reports Install section policy');

    my $before_transient_verify = scalar(@verify_commands);
    ($ok, $err) = verify_dropin_data(
        '/run/systemd/transient/session-2.scope',
        "[Unit]\nDescription=Transient\n[Scope]\n",
        "[Unit]\nRequiresMountsFor=/root\n", 0, 'transient');
    ok($ok, 'verify_dropin_data skips transient unit drop-ins');
    is(scalar(@verify_commands), $before_transient_verify,
       'transient drop-in verification does not call systemd-analyze');

    my @user_verify;
    local *main::get_user_details = sub {
        my ($user) = @_;
        return $user eq 'alice' ?
            { user => 'alice', uid => 1001, gid => 1001,
              home => '/home/alice' } : undef;
    };
    local *main::set_ownership_permissions = sub { return 1 };
    local *main::user_manager_command = sub {
        my ($user, @cmd) = @_;
        push(@user_verify, [ $user, @cmd ]);
        return "as-user ".join(" ", @cmd);
    };
    ($ok, $err) = verify_unit_data(
        '/home/alice/.config/systemd/user/owned.service',
        "[Unit]\nDescription=Owned\n", 1, 'alice');
    ok($ok, 'verify_unit_data accepts user-owned unit data');
    is($user_verify[-1]->[0], 'alice',
       'verify_unit_data verifies as the target user');
    like(join(" ", @{$user_verify[-1]}), qr/--user verify .*owned\\.service/,
         'user-owned verification uses the user manager command');
    ok(!-e "$verify_root/verify-5/owned.service",
       'user-owned verification removes temporary files');

    ($ok, $err) = verify_dropin_data(
        '/home/alice/.config/systemd/user/owned.service',
        "[Unit]\nDescription=Owned\n[Service]\nExecStart=/bin/true\n",
        "[Service]\nRestart=always\n", 1, undef, 'alice');
    ok($ok, 'verify_dropin_data accepts user-owned drop-in data');
    is($user_verify[-1]->[0], 'alice',
       'verify_dropin_data verifies as the target user');
}

{
    my $dropin_root = "$work/system-dropins";
    make_path($dropin_root);
    local *main::get_system_dropin_roots = sub {
        return ($dropin_root);
    };
    local *main::system_dropin_file = sub {
        my ($unit) = @_;
        return "$dropin_root/$unit.d/override.conf";
    };
    my $template = dropin_template(
        '/etc/systemd/system/demo.service.d/override.conf',
        '/usr/lib/systemd/system/demo.service',
        "[Unit]\nDescription=Demo\n");
    like($template, qr/^### Editing .*override\.conf/m,
         'dropin_template names the override file');
    like($template, qr/^# Description=Demo$/m,
         'dropin_template comments the base unit');
    is(dropin_effective_data($template."[Service]\nRestart=always\n"),
       "### Editing /etc/systemd/system/demo.service.d/override.conf\n".
       "### Anything between here and the comment below will become ".
       "the new contents of the file\n\n\n\n",
       'dropin_effective_data discards commented base unit contents');
    ok(dropin_has_install_section("[Install]\nWantedBy=multi-user.target\n"),
       'drop-in install-section detector rejects active Install sections');
    ok(!dropin_has_install_section("# [Install]\n[Service]\nRestart=always\n"),
       'drop-in install-section detector ignores commented examples');

    my ($ok, $out) = write_system_dropin_file('demo.service', $template);
    ok($ok, 'write_system_dropin_file writes standard override files');
    is(slurp_test_file("$dropin_root/demo.service.d/override.conf"),
       $template, 'system drop-in content is written');
    write_test_file("$dropin_root/demo.service.d/10-extra.conf",
                    "[Service]\nRestartSec=5s\n");
    make_path("$dropin_root/bad.service.d");
    symlink('/tmp/evil', "$dropin_root/bad.service.d/link.conf");
    my @system_dropins = list_system_dropin_override_files();
    is_deeply([ map { $_->{'unit'}.":".$_->{'name'} } @system_dropins ],
              [ 'demo.service:10-extra.conf',
                'demo.service:override.conf' ],
              'system drop-in inventory lists safe config files');
    is(read_system_dropin_config_file(
           "$dropin_root/demo.service.d/10-extra.conf"),
       "[Service]\nRestartSec=5s\n",
       'system drop-in config reader opens exact safe file');
    ($ok, $out) = write_system_dropin_config_file(
        "$dropin_root/demo.service.d/10-extra.conf",
        "[Service]\nRestartSec=10s\n");
    ok($ok, 'system drop-in config writer updates exact safe file');
    ($ok, $out) = write_system_dropin_config_file(
        "$dropin_root/demo.service.d/10-extra.conf",
        "[Install]\nWantedBy=multi-user.target\n");
    ok(!$ok, 'system drop-in config writer rejects Install sections');
    is($out, $text{'systemd_edropininstall'},
       'system drop-in config writer reports Install section policy');
    is(slurp_test_file("$dropin_root/demo.service.d/10-extra.conf"),
       "[Service]\nRestartSec=10s\n",
       'system drop-in config writer preserves non-standard filename');
    ok(dropin_exists(0, undef, 'demo.service'),
       'dropin_exists detects system override files');
    ($ok, $out) = delete_system_dropin_file('demo.service');
    ok($ok, 'delete_system_dropin_file removes standard override files');
    ok(!-e "$dropin_root/demo.service.d/override.conf",
       'system drop-in file is removed');
    ok(!dropin_exists(0, undef, 'demo.service'),
       'dropin_exists returns false after system override deletion');

    make_path("$dropin_root/link.service.d");
    symlink('/tmp/evil', "$dropin_root/link.service.d/override.conf");
    ($ok, $out) = write_system_dropin_file('link.service', 'bad');
    ok(!$ok, 'write_system_dropin_file rejects symlink override files');
}

{
    my $home = "$work/alice-home";
    my $root = "$home/.config/systemd/user";
    make_path($root);
    my @home_st = stat($home);
    my $user_info = {
        user => 'alice',
        uid => $home_st[4],
        gid => $home_st[5],
        home => $home,
    };
    local *main::get_user_details = sub {
        my ($user) = @_;
        return $user eq 'alice' ? $user_info : undef;
    };
    local *main::eval_as_unix_user = sub {
        my ($user, $code) = @_;
        return $code->();
    };
    ok(user_root_safe('alice'), 'safe user unit root accepts real directories');
    my ($dirs_ok, $dirs_out) = check_user_unit_dirs('alice');
    ok($dirs_ok, 'check_user_unit_dirs accepts user-owned unit tree');
    my $real_uid = $user_info->{'uid'};
    $user_info->{'uid'} = $real_uid + 1;
    ($dirs_ok, $dirs_out) = check_user_unit_dirs('alice');
    ok(!$dirs_ok, 'check_user_unit_dirs rejects wrongly-owned unit tree');
    is($dirs_out, 'bad user unit dir', 'wrongly-owned dir error');
    $user_info->{'uid'} = $real_uid;
    symlink('/tmp', "$home/.config/systemd/user/link-test");
    ok(!user_unit_file_safe('alice', "$root/link-test", 1),
       'user unit file safety rejects symlink files');
    unlink("$home/.config/systemd/user/link-test");
    ok(user_unit_file_safe('alice', "$root/demo.service", 0),
       'user unit file safety accepts direct unit child');
    ok(!user_unit_file_safe('alice', "$root/../demo.service", 0),
       'user unit file safety rejects traversal');

    my ($ok, $out) = write_user_unit_file(
        'alice', "$root/demo.service", "[Unit]\nDescription=Alice\n");
    ok($ok, 'write_user_unit_file writes through dropped-user helper');
    is(slurp_test_file("$root/demo.service"), "[Unit]\nDescription=Alice\n",
       'user unit file content is written');
    is(read_user_unit_file('alice', "$root/demo.service"),
       "[Unit]\nDescription=Alice\n",
       'read_user_unit_file reads through dropped-user helper');
    is(user_file_description('alice', "$root/demo.service"), 'Alice',
       'user unit description is parsed');

    my $dropin = user_dropin_file('alice', 'demo.service');
    ($ok, $out) = write_user_dropin_file(
        'alice', 'demo.service', "[Service]\nRestart=always\n");
    ok($ok, 'write_user_dropin_file writes through dropped-user helper');
    is(slurp_test_file($dropin), "[Service]\nRestart=always\n",
       'user drop-in file content is written');
    write_test_file("$root/demo.service.d/20-local.conf",
                    "[Service]\nEnvironment=DEMO=1\n");
    my @user_dropins = list_user_dropin_override_files('alice');
    is_deeply([ map { $_->{'user'}.":".$_->{'unit'}.":".$_->{'name'} }
                @user_dropins ],
              [ 'alice:demo.service:20-local.conf',
                'alice:demo.service:override.conf' ],
              'user drop-in inventory lists safe config files');
    is(read_user_dropin_config_file('alice',
           "$root/demo.service.d/20-local.conf"),
       "[Service]\nEnvironment=DEMO=1\n",
       'user drop-in config reader opens exact safe file');
    ($ok, $out) = write_user_dropin_config_file(
        'alice', "$root/demo.service.d/20-local.conf",
        "[Service]\nEnvironment=DEMO=2\n");
    ok($ok, 'user drop-in config writer updates exact safe file');
    is(slurp_test_file("$root/demo.service.d/20-local.conf"),
       "[Service]\nEnvironment=DEMO=2\n",
       'user drop-in config writer preserves non-standard filename');
    ($ok, $out) = write_user_dropin_config_file(
        'alice', "$root/demo.service.d/20-local.conf",
        "[Install]\nWantedBy=default.target\n");
    ok(!$ok, 'user drop-in config writer rejects Install sections');
    is($out, $text{'systemd_edropininstall'},
       'user drop-in config writer reports Install section policy');
    ok(dropin_exists(1, 'alice', 'demo.service'),
       'dropin_exists detects user override files');
    is(read_user_dropin_file('alice', 'demo.service'),
       "[Service]\nRestart=always\n",
       'read_user_dropin_file reads through dropped-user helper');
    is(user_file_description('alice', "$root/demo.service", 'demo.service'),
       'Alice',
       'user unit description ignores drop-ins without descriptions');
    ($ok, $out) = write_user_dropin_file(
        'alice', 'demo.service',
        "[Unit]\nDescription=Alice Override\n[Service]\nRestart=always\n");
    ok($ok, 'write_user_dropin_file updates user override files');
    is(user_file_description('alice', "$root/demo.service", 'demo.service'),
       'Alice Override',
       'user unit description honors drop-in descriptions');
    my @dropin_local = list_user_units('alice');
    is($dropin_local[0]->{'desc'}, 'Alice Override',
       'offline user unit listing uses drop-in description');
    ($ok, $out) = delete_user_dropin_file('alice', 'demo.service');
    ok($ok, 'delete_user_dropin_file removes through dropped-user helper');
    ok(!-e $dropin, 'user drop-in file is removed');
    ok(!dropin_exists(1, 'alice', 'demo.service'),
       'dropin_exists returns false after user override deletion');

    make_path("$root/link.service.d");
    symlink('/tmp/evil', "$root/link.service.d/override.conf");
    ($ok, $out) = write_user_dropin_file('alice', 'link.service', 'bad');
    ok(!$ok, 'write_user_dropin_file rejects symlink override files');

    make_path("$root/default.target.wants");
    symlink("$root/demo.service", "$root/default.target.wants/demo.service");
    ok(user_file_enabled('alice', 'demo.service'),
       'user unit enabled state is detected from wants symlink');

    my @local = list_user_units('alice');
    is(@local, 1, 'offline user unit listing includes local file');
    is($local[0]->{'name'}, 'demo.service', 'offline user unit name');
    is($local[0]->{'desc'}, 'Alice', 'offline user unit description');
    is($local[0]->{'boot'}, 1, 'offline user unit boot state');
    is($local[0]->{'unitstate'}, 'enabled',
       'offline user unit file state is inferred');
    is($local[0]->{'runtime'}, undef,
       'offline user unit runtime state is unknown');
    is($local[0]->{'substate'}, undef,
       'offline user unit sub-state is unknown');

    ok(delete_user_unit_file('alice', "$root/demo.service"),
       'delete_user_unit_file removes safe direct unit');
    ok(!-e "$root/demo.service", 'user unit file was deleted');
}

{
    local $config{'visible_tabs'} = 'service,timer';
    is_deeply([ list_all_user_units() ], [ ],
              'list_all_user_units honors hidden user tab');
}

{
    my $home = "$work/bob-home";
    my $root = "$home/.config/systemd/user";
    make_path($home);
    my @home_st = stat($home);
    my $user_info = {
        user => 'bob',
        uid => $home_st[4],
        gid => $home_st[5],
        home => $home,
    };
    local *main::get_user_details = sub {
        my ($user) = @_;
        return $user eq 'bob' ? $user_info : undef;
    };
    local *main::eval_as_unix_user = sub {
        my ($user, $code) = @_;
        return $code->();
    };
    local *main::reload_user_manager = sub { return (1, '') };
    local *main::has_command = sub { return };
    is(make_user_root('bob'), $root,
       'make_user_root creates the user unit directory');
    ok(-d $root, 'user unit directory exists');
    my $bob_service = render_unit({
        type => 'service',
        description => 'Bob',
        service => {
            start => '/bin/true',
        },
        options => {
            wantedby => 'default.target',
        },
    });
    my ($ok, $out) = create_user_unit(
        'bob', 'bob.service', $bob_service);
    ok($ok, 'create_user_unit writes service with mocked user manager');
    ok(-f "$root/bob.service", 'user service file was created');
    like(slurp_test_file("$root/bob.service"), qr/^WantedBy=default\.target$/m,
         'user service install target written');
    my $bob_timer = render_unit({
        type => 'timer',
        description => 'Bob timer',
        body => 'OnCalendar=daily',
        options => {
            wantedby => 'timers.target',
        },
    });
    ($ok, $out) = create_user_unit(
        'bob', 'bob.timer', $bob_timer);
    ok($ok, 'create_user_unit writes timer with mocked user manager');
    ok(-f "$root/bob.timer", 'user timer file was created');
    ($ok, $out) = delete_user_unit('bob', 'bob');
    ok(!$ok, 'delete_user_unit rejects bare service name');
    ok(-e "$root/bob.service", 'delete_user_unit leaves typed file after bare rejection');
    ($ok, $out) = delete_user_unit('bob', 'bob.service');
    ok($ok, 'delete_user_unit accepts typed service name');
    ok(!-e "$root/bob.service", 'delete_user_unit removed service file');
    ($ok, $out) = delete_user_unit('bob', 'bob.service');
    ok(!$ok, 'delete_user_unit rejects already-missing unit');
    is($out, $text{'systemd_egone'},
       'delete_user_unit reports stale missing unit');
}

{
    my @args;
    local *main::get_user_details = sub {
        return { user => 'carol', uid => 1003, gid => 1003,
                 home => '/home/carol' };
    };
    local *main::command_as_user = sub {
        my ($user, $mode, $cmd) = @_;
        push(@args, [ $user, $mode, $cmd ]);
        return "as-user $cmd";
    };
    my $cmd = user_systemctl_command(
        'carol', 'start', 'bad;touch.service');
    is($args[0]->[0], 'carol', 'user command runs as selected Unix user');
    like($cmd, qr/HOME=\\\/home\\\/carol/, 'user command sets HOME');
    like($cmd, qr/XDG_RUNTIME_DIR=\\\/run\\\/user\\\/1003/,
         'user command sets runtime directory');
    like($cmd, qr/DBUS_SESSION_BUS_ADDRESS=unix\\:path\\=\\\/run\\\/user\\\/1003\\\/bus/,
         'user command sets user bus address');
    like($cmd, qr/--user start bad\\;touch\\.service/,
         'systemctl --user command quotes hostile unit names');
}

{
    my @cmds;
    local *main::user_systemctl_command = sub {
        my ($user, @args) = @_;
        push(@cmds, [ $user, @args ]);
        return "user-systemctl ".join(" ", @args);
    };
    local *main::backquote_logged = sub {
        $? = 0;
        return 'ran';
    };
    my ($ok, $out) = run_user_systemctl('alice', 'status',
                                                'demo.service');
    ok($ok, 'run_user_systemctl reports command success');
    is($out, 'ran', 'run_user_systemctl returns command output');
    is_deeply($cmds[-1], [ 'alice', 'status', 'demo.service' ],
              'run_user_systemctl builds requested arguments');
    ($ok) = reload_user_manager('alice');
    ok($ok, 'reload_user_manager runs daemon-reload');
    is_deeply($cmds[-1], [ 'alice', 'daemon-reload' ],
              'reload_user_manager reloads the user manager');
}

{
    my @run;
    local *main::run_user_systemctl = sub {
        push(@run, [ @_ ]);
        return (1, 'ok');
    };
    local *main::check_user_unit_dirs = sub {
        return (1, undef);
    };
    my ($ok) = start_user_unit('alice', 'demo.service');
    ok($ok, 'start_user_unit delegates to systemctl --user');
    is_deeply($run[-1], [ 'alice', 'start', 'demo.service' ],
              'start_user_unit arguments');
    ($ok) = stop_user_unit('alice', 'demo.service');
    is_deeply($run[-1], [ 'alice', 'stop', 'demo.service' ],
              'stop_user_unit arguments');
    ($ok) = restart_user_unit('alice', 'demo.service');
    is_deeply($run[-1], [ 'alice', 'restart', 'demo.service' ],
              'restart_user_unit arguments');
    ($ok) = status_user_unit('alice', 'demo.service');
    is_deeply($run[-1], [ 'alice', '--full', '--no-pager',
                          'status', 'demo.service' ],
              'status_user_unit arguments');
    ($ok) = properties_user_unit('alice', 'demo.service');
    is_deeply($run[-1], [ 'alice', '--full', '--no-pager',
                          'show', 'demo.service' ],
              'properties_user_unit arguments');
    ($ok) = dependencies_user_unit('alice', 'demo.service');
    is_deeply($run[-1], [ 'alice', '--full', '--no-pager',
                          'list-dependencies', 'demo.service' ],
              'dependencies_user_unit arguments');
    ($ok) = enable_user_unit('alice', 'demo.service');
    is_deeply($run[-1], [ 'alice', 'enable', 'demo.service' ],
              'enable_user_unit arguments');
    ($ok) = disable_user_unit('alice', 'demo.service');
    is_deeply($run[-1], [ 'alice', 'disable', 'demo.service' ],
              'disable_user_unit arguments');
    ($ok) = mask_user_unit('alice', 'demo.service');
    is_deeply($run[-1], [ 'alice', 'mask', 'demo.service' ],
              'mask_user_unit arguments');
    ($ok) = unmask_user_unit('alice', 'demo.service');
    is_deeply($run[-1], [ 'alice', 'unmask', 'demo.service' ],
              'unmask_user_unit arguments');
    my $before_invalid = scalar(@run);
    ($ok) = start_user_unit('alice', 'bad;touch.service');
    ok(!$ok, 'start_user_unit rejects invalid unit names');
    is(scalar(@run), $before_invalid,
       'invalid user unit name builds no systemctl command');
}

{
    my @cmds;
    local *main::has_command = sub {
        return $_[0] eq 'journalctl' ? '/bin/journalctl' : undef;
    };
    local *main::get_user_details = sub {
        return { user => 'alice', uid => 1003, gid => 1003,
                 home => '/home/alice' };
    };
    local *main::backquote_logged = sub {
        my ($cmd) = @_;
        push(@cmds, $cmd);
        $? = 0;
        return 'user logs';
    };
    local $config{'logs_lines'} = 77;
    my ($ok, $out) = logs_user_unit('alice', 'demo.service');
    ok($ok, 'logs_user_unit reports success');
    is($out, 'user logs', 'logs_user_unit returns output');
    like($cmds[-1],
         qr/\\\/bin\\\/journalctl --no-pager _UID=1003 _SYSTEMD_USER_UNIT=demo\\\.service --lines 77/,
         'logs_user_unit filters journal by owner and unit');

    local $config{'logs_current_boot'} = 1;
    logs_user_unit('alice', 'demo.service');
    like($cmds[-1], qr/--boot/,
         'logs_user_unit adds boot filter when configured');
}

{
    my @cmds;
    local *main::has_command = sub {
        return $_[0] eq 'loginctl' ? '/bin/loginctl' :
               $_[0] eq 'systemctl' ? '/bin/systemctl' : undef;
    };
    local *main::get_user_details = sub {
        return { user => 'alice', uid => 1001, gid => 1001,
                 home => '/home/alice' };
    };
    local *main::backquote_logged = sub {
        push(@cmds, $_[0]);
        $? = 0;
        return 'ok';
    };
    my ($ok) = set_user_linger('alice', 1);
    ok($ok, 'set_user_linger reports success');
    like($cmds[-1], qr/\\\/bin\\\/loginctl enable-linger alice/,
         'linger enable command is built');
    ($ok) = start_user_manager('alice');
    ok($ok, 'start_user_manager reports success');
    like($cmds[-1], qr/\\\/bin\\\/systemctl start user\\\@1001\\.service/,
         'user manager unit is started by UID');
}

{
    local *main::get_user_details = sub {
        return { user => 'unit-test-linger-user', uid => 2001,
                 gid => 2001, home => '/home/unit-test-linger-user' };
    };
    local *main::has_command = sub {
        return $_[0] eq 'loginctl' ? '/bin/loginctl' : undef;
    };
    local *main::backquote_command = sub {
        return "Linger=yes\n";
    };
    ok(user_linger_enabled('unit-test-linger-user'),
       'linger state falls back to loginctl');
}

{
    my $cat_data = <<'EOF';
# /usr/lib/systemd/system/demo.socket
[Socket]
ListenStream=80
ListenStream=443

[Install]
WantedBy=sockets.target
EOF
    local *main::open_execute_command = sub {
        my ($fh, $cmd) = @_;
        open($fh, '<', \$cat_data) or die "open scalar: $!";
        return 1;
    };
    my $conf = cat_unit('demo.socket');
    is($conf->[0]->{'file'}, '/usr/lib/systemd/system/demo.socket',
       'cat_unit captures source file');
    is_deeply($conf->[0]->{'sections'}->{'Socket'}->{'ListenStream'},
              [ '80', '443' ],
              'cat_unit captures repeated keys');
    my $filtered = cat_unit('demo.socket', 'Listen');
    ok($filtered->[0]->{'sections'}->{'Socket'}->{'ListenStream'},
       'cat_unit filter keeps matching keys');
    ok(!$filtered->[0]->{'sections'}->{'Install'},
       'cat_unit filter removes non-matching sections');
}

{
    my $override_dir = "$work/override/demo.service.d";
    my @reloads;
    make_path("$work/override");
    local *main::system_logged = sub {
        push(@reloads, $_[0]);
        return 0;
    };
    edit_unit('demo.service',
        { Service => { Environment => [ 'A=1', 'B=2' ] } },
        'override.conf', $override_dir);
    my $override = slurp_test_file("$override_dir/override.conf");
    like($override, qr/^\[Service\]\nEnvironment=A=1\nEnvironment=B=2/m,
         'edit_unit writes override settings');
    edit_unit('demo.service',
        { Service => { Environment => [ 'C=3' ] } },
        'override.conf', $override_dir);
    $override = slurp_test_file("$override_dir/override.conf");
    unlike($override, qr/Environment=A=1/, 'edit_unit replaces old key values');
    like($override, qr/Environment=C=3/, 'edit_unit keeps new key values');
    is($reloads[-1], 'systemctl daemon-reload',
       'edit_unit reloads daemon after writing override');
}

do "$bindir/../log_parser.pl";
die $@ if $@;
like(parse_webmin_log('root', '', 'create', 'systemd',
                      '<img src=x onerror=1>.service', {}),
     qr/&lt;img src&#61;x onerror&#61;1&gt;/,
     'system unit log parser escapes unit names');
like(parse_webmin_log('root', '', 'override', 'systemd',
                      'demo.service', {}),
     qr/drop-in override.*demo\.service|demo\.service.*drop-in override/i,
     'override system unit log is parsed');
like(parse_webmin_log('root', '', 'deleteoverride', 'systemd',
                      'demo.service', {}),
     qr/drop-in override.*demo\.service|demo\.service.*drop-in override/i,
     'drop-in delete system unit log is parsed');
like(parse_webmin_log('root', '', 'deps', 'systemd',
                      'demo.service', {}),
     qr/Listed dependencies.*demo\.service|demo\.service.*dependencies/i,
     'dependency system unit log is parsed');
like(parse_webmin_log('root', '', 'props', 'systemd',
                      'demo.service', {}),
     qr/Fetched properties.*demo\.service|demo\.service.*properties/i,
     'properties system unit log is parsed');
like(parse_webmin_log('root', '', 'massstart', 'systemd-user',
                      "a.service b.timer",
                      { user => '<owner>' }),
     qr/&lt;owner&gt;/,
     'user unit log parser escapes owner names');
like(parse_webmin_log('root', '', 'override', 'systemd-user',
                      "a.service",
                      { user => '<owner>' }),
     qr/&lt;owner&gt;.*a\.service|a\.service.*&lt;owner&gt;/s,
     'override user unit log is parsed');
like(parse_webmin_log('root', '', 'deleteoverride', 'systemd-user',
                      "a.service",
                      { user => '<owner>' }),
     qr/&lt;owner&gt;.*a\.service|a\.service.*&lt;owner&gt;/s,
     'drop-in delete user unit log is parsed');
like(parse_webmin_log('root', '', 'deps', 'systemd-user',
                      "a.service",
                      { user => '<owner>' }),
     qr/&lt;owner&gt;.*a\.service|a\.service.*&lt;owner&gt;/s,
     'dependency user unit log is parsed');
like(parse_webmin_log('root', '', 'props', 'systemd-user',
                      "a.service",
                      { user => '<owner>' }),
     qr/&lt;owner&gt;.*a\.service|a\.service.*&lt;owner&gt;/s,
     'properties user unit log is parsed');
like(parse_webmin_log('root', '', 'massdelete', 'systemd-user',
                      "a.service b.timer",
                      { user => '<owner>' }),
     qr/&lt;owner&gt;.*a\.service|a\.service.*&lt;owner&gt;/s,
     'mass delete user unit log is parsed');
like(parse_webmin_log('root', '', 'linger', 'systemd-user', '',
                      { user => 'alice', enabled => 1 }),
     qr/Alice|alice|Yes/,
     'linger log parser returns translated output');
like(parse_webmin_log('root', '', 'manual', 'systemd',
                      '/etc/systemd/system/demo.service', {}),
     qr/demo\.service/,
     'manual system unit file log is parsed');
like(parse_webmin_log('root', '', 'manual', 'systemd-user',
                      '/home/alice/.config/systemd/user/demo.service',
                      { user => 'alice' }),
     qr/alice.*demo\.service|demo\.service.*alice/,
     'manual user unit file log is parsed');
like(parse_webmin_log('root', '', 'reload', 'systemd', '', {}),
     qr/Reloaded|systemd/i,
     'daemon reload log is parsed');
like(parse_webmin_log('root', '', 'reload', 'systemd-user', 'alice',
                      { user => 'alice' }),
     qr/alice/,
     'user manager reload log is parsed');

do "$bindir/../backup_config.pl";
die $@ if $@;
{
    local %access = ( backup => 1, mode => 0 );
    local *main::list_units = sub {
        return (
            { name => 'demo.service',
              file => '/etc/systemd/system/demo.service' },
            { name => 'vendor.service',
              file => '/usr/lib/systemd/system/vendor.service' },
        );
    };
    local *main::list_all_user_units = sub {
        return ( { name => 'demo.service',
                   file => '/home/alice/.config/systemd/user/demo.service',
                   user => 'alice' } );
    };
    local *main::dropin_exists = sub {
        my ($user_scope, $user, $unit) = @_;
        return !$user_scope &&
               ($unit eq 'demo.service' || $unit eq 'vendor.service') ? 1 :
               $user_scope && $user eq 'alice' &&
               $unit eq 'demo.service' ? 1 : 0;
    };
    local *main::system_dropin_file = sub {
        my ($unit) = @_;
        return "/etc/systemd/system/$unit.d/override.conf";
    };
    local *main::user_dropin_file = sub {
        my ($user, $unit) = @_;
        return "/home/$user/.config/systemd/user/$unit.d/override.conf";
    };
    is_deeply([ backup_config_files() ],
              [ '/etc/systemd/system/demo.service',
                '/etc/systemd/system/demo.service.d/override.conf',
                '/etc/systemd/system/vendor.service.d/override.conf',
                '/home/alice/.config/systemd/user/demo.service',
                '/home/alice/.config/systemd/user/demo.service.d/override.conf' ],
              'backup_config_files includes local system, user and drop-in files');
    local %access = ( backup => 1, mode => 1, users => 'bob' );
    is_deeply([ backup_config_files() ],
              [ '/etc/systemd/system/demo.service',
                '/etc/systemd/system/demo.service.d/override.conf',
                '/etc/systemd/system/vendor.service.d/override.conf' ],
              'backup_config_files filters user units and drop-ins by owner ACL');
    local %access = ( backup => 0, mode => 0 );
    is_deeply([ backup_config_files() ], [],
              'backup_config_files honors backup ACL denial');
    my $reloaded = 0;
    local *main::reload_manager = sub { $reloaded++ };
    post_restore();
    is($reloaded, 1, 'post_restore reloads systemd');
    is(pre_backup(), undef, 'pre_backup has no side effects');
    is(post_backup(), undef, 'post_backup has no side effects');
    is(pre_restore(), undef, 'pre_restore has no side effects');
}

do "$bindir/../acl_security.pl";
die $@ if $@;
{
    local %in = ( mode => 1, userscan => 'alice bob',
                  view => 1, view_user => 1, create_user => 1,
                  logs => 0, logs_user => 1 );
    my %acl;
    acl_security_save(\%acl);
    is($acl{'mode'}, 1, 'ACL save stores user restriction mode');
    is($acl{'users'}, 'alice bob',
       'ACL save stores user restriction list');
    is($acl{'view'}, 1, 'ACL save stores system view permission');
    is($acl{'create_user'}, 1,
       'ACL save stores user unit create permission');
    is($acl{'logs'}, 0, 'ACL save denies missing granular permission');
    is($acl{'logs_user'}, 1,
       'ACL save stores user-scope granular permission');
    ok(!exists($acl{'units'}), 'ACL save omits removed units ACL key');
    local %in = ( mode => 99, userscan => 'alice', view_user => 1 );
    acl_security_save(\%acl);
    is($acl{'mode'}, 0, 'ACL save rejects invalid user mode');
}

do "$bindir/../install_check.pl";
die $@ if $@;
{
    local *main::has_command = sub {
        return $_[0] eq 'systemctl' ? '/bin/systemctl' : undef;
    };
    is(is_installed(0), 1, 'install check detects systemctl');
    is(is_installed(1), 2, 'configured install check reports visible module');
}
{
    local *main::has_command = sub { return };
    is(is_installed(0), 0, 'install check rejects missing systemctl');
}

do "$bindir/../syslog_logs.pl";
die $@ if $@;
{
    local *main::has_command = sub {
        return $_[0] eq 'journalctl' ? '/bin/journalctl' : undef;
    };
    my @logs = syslog_getlogs();
    is($logs[0]->{'cmd'}, 'journalctl -n 1000',
       'syslog log source exposes journalctl command');
}

my $index_source = slurp_test_file("$bindir/../index.cgi");
my $mass_source = slurp_test_file("$bindir/../mass_units.cgi");
my $save_source = slurp_test_file("$bindir/../save_unit.cgi");
my $edit_source = slurp_test_file("$bindir/../edit_unit.cgi");
my $edit_manual_source = slurp_test_file("$bindir/../edit_manual.cgi");
my $dropins_source = slurp_test_file("$bindir/../dropins.cgi");
my $save_manual_source = slurp_test_file("$bindir/../save_manual.cgi");
my $restart_source = slurp_test_file("$bindir/../restart.cgi");
my $restart_user_source = slurp_test_file("$bindir/../restart_user.cgi");
my $acl_source = slurp_test_file("$bindir/../acl_security.pl");
my $defaultacl_source = slurp_test_file("$bindir/../defaultacl");
my $safeacl_source = slurp_test_file("$bindir/../safeacl");
my $config_source = slurp_test_file("$bindir/../config.info");
my $config_info_source = slurp_test_file("$bindir/../config_info.pl");
my $lib_source = slurp_test_file("$bindir/../systemd-lib.pl");
my $type_help_source = slurp_test_file("$bindir/../help/systemd_type.html");
my $type_user_help_source =
    slurp_test_file("$bindir/../help/systemd_type_user.html");
my $path_help_source =
    slurp_test_file("$bindir/../help/systemd_pathexists.html");
my $socket_fifo_help_source =
    slurp_test_file("$bindir/../help/systemd_socketlistenfifo.html");
my $socket_user_help_source =
    slurp_test_file("$bindir/../help/systemd_socketuser.html");
my $workdir_help_source =
    slurp_test_file("$bindir/../help/systemd_workdir.html");
my $envfile_help_source =
    slurp_test_file("$bindir/../help/systemd_envfile.html");
my $limitnofile_help_source =
    slurp_test_file("$bindir/../help/systemd_limitnofile.html");
my $logstd_help_source =
    slurp_test_file("$bindir/../help/systemd_logstd.html");
my $logerr_help_source =
    slurp_test_file("$bindir/../help/systemd_logerr.html");
my $socketaccept_help_source =
    slurp_test_file("$bindir/../help/systemd_socketaccept.html");
my $socketservice_help_source =
    slurp_test_file("$bindir/../help/systemd_socketservice.html");
my $timerpersistent_help_source =
    slurp_test_file("$bindir/../help/systemd_timerpersistent.html");
my $conf_help_source =
    slurp_test_file("$bindir/../help/systemd_conf.html");
my $file_help_source =
    slurp_test_file("$bindir/../help/systemd_file.html");
my $readwritepaths_help_source =
    slurp_test_file("$bindir/../help/systemd_readwritepaths.html");
my $unitconf_help_source =
    slurp_test_file("$bindir/../help/systemd_unitconf.html");
my $slice_help_source =
    slurp_test_file("$bindir/../help/systemd_slicecpuweight.html");
foreach my $file (sort glob("$bindir/../help/systemd_*.html")) {
    my ($key) = $file =~ m{/([^/]+)\.html$};
    next if (!$key || !defined($text{$key}));
    my $source = slurp_test_file($file);
    my ($header) = $source =~ m{^<header>(.*?)</header>};
    is($header, $text{$key}, "$key help title matches field label");
}
like($config_source, qr/^logs_lines=/m,
     'module config exposes journal line count');
like($config_source, qr/^logs_current_boot=/m,
     'module config exposes journal boot filtering');
like($config_source, qr/^visible_tabs=/m,
     'module config exposes visible tab selection');
like($config_source, qr/^show_runtime_units=/m,
     'module config exposes generated and transient unit visibility');
like($config_source, qr/^default_create_scope=/m,
     'module config exposes default create scope');
like($config_source, qr/^manual_vendor_units=/m,
     'module config exposes vendor-file manual editor visibility');
like($config_source, qr/^edit_vendor_units=/m,
     'module config exposes packaged unit edit policy');
like($config_source, qr/^delete_vendor_units=/m,
     'module config exposes packaged unit delete policy');
like($config_source, qr/^default_linger=/m,
     'module config exposes default linger choice');
like($config_source, qr/^show_dropin_inventory=/m,
     'module config exposes drop-in inventory visibility');
like($config_source, qr/^create_return_index=/m,
     'module config exposes post-create redirect destination');
like($config_info_source, qr/sub parse_visible_tabs\b/,
     'module config rejects saving with every tab hidden');
like($defaultacl_source, qr/^view_user=1/m,
     'default ACL grants user unit viewing');
like($defaultacl_source, qr/^manual_user=1/m,
     'default ACL grants user unit manual editing');
like($defaultacl_source, qr/^start_user=1/m,
     'default ACL grants user unit runtime control');
like($safeacl_source, qr/^mode=3/m,
     'safe ACL scopes user units to the current Webmin user');
like($safeacl_source, qr/^view=0/m,
     'safe ACL denies system unit viewing');
like($safeacl_source, qr/^view_user=1/m,
     'safe ACL allows user unit viewing');
like($safeacl_source, qr/^create=0/m,
     'safe ACL denies system unit creation');
like($safeacl_source, qr/^create_user=1/m,
     'safe ACL allows user unit creation');
like($safeacl_source, qr/^mask_user=0/m,
     'safe ACL denies user-unit masking');
like($acl_source, qr/acl_section_users/,
     'ACL editor exposes user owner restriction section');
like($acl_source, qr/systemd_acl_keys/,
     'ACL editor saves all granular systemd permissions');
like($lib_source, qr/sub systemd_acl_user_allowed\b/,
     'library contains user owner ACL helper');
like($lib_source, qr/sub systemd_acl_default_user\b/,
     'library contains default user owner helper');
like($lib_source, qr/sub systemd_can_runtime\b/,
     'library contains runtime ACL helper');
like($lib_source, qr/sub systemd_can_manual\b/,
     'library contains manual file ACL helper');
like($index_source, qr/sub index_tabs\b/,
     'index contains tab builder helper');
like($index_source, qr/sub index_tab_groups\b/,
     'index defines grouped tabs for related unit types');
like($index_source, qr/next if \(!systemd_can_view_system\(\)\)/,
     'index shows system tabs only when system scope is allowed');
unlike($index_source, qr/next if \(!\@\$units\)/,
       'index keeps visible tabs even when they have no units');
like($index_source, qr/tab_visible\('user'\).*?systemd_can_view_user_scope/s,
     'index keeps the user tab when user scope is allowed');
like($index_source, qr/sub index_empty_message\b/,
     'index contains tab empty-state helper');
like($index_source, qr/!\@\{\$tab->\{'units'\}\}.*?index_empty_message/s,
     'index shows an empty state instead of an empty table');
like($index_source, qr/ui_tag\('p',\s*index_empty_message\(\$tab\)\)/,
     'index renders empty-state messages as paragraphs');
like($index_source, qr/sub index_create_link\b/,
     'index shares create-link logic with empty states');
like($index_source, qr/\$formno\+\+ if \(print_index_tab\(\$tab, \$formno\)\)/,
     'index form counter skips empty-state tabs');
like($index_source, qr/!\@\{\$tab->\{'units'\}\}.*?return 0;/s,
     'index empty-state tabs report no mass-action form');
like($index_source, qr/storage.*mount.*automount.*swap/s,
     'index groups storage unit types together');
like($index_source, qr/resources.*slice.*scope/s,
     'index groups resource-control unit types together');
like($index_source, qr/device.*inspect_only/s,
     'index treats device units as inspection-oriented');
like($index_source, qr/sub linger_toggle_link\b/,
     'index contains linger toggle helper');
like($index_source, qr/sub index_unit_state_column\b/,
     'index contains unit-file state formatter');
unlike($index_source, qr/sub index_boot_column\b/,
       'index no longer reduces unit state to boot yes-no values');
like($index_source, qr/ui_form_grouped_buttons/,
     'index mass actions use grouped button API');
unlike($index_source, qr/index_depsnow|index_propsnow/,
       'index mass actions omit deeper inspect buttons');
unlike($index_source, qr/addboot_start|delboot_stop/,
       'index omits combined start-enable mass actions');
like($index_source, qr/sub print_index_tools\b/,
     'index contains advanced tools block');
like($index_source, qr/dropins\.cgi.*?show_dropin_inventory/s,
     'index links configurable drop-in inventory action');
like($index_source, qr/action_links\(\)/,
     'index header includes conditional daemon reload action');
like($index_source, qr/systemd_can_enter_module/,
     'index gates module entry through granular ACLs');
like($index_source, qr/systemd_acl_user_allowed/,
     'index filters user units by ACL owner rules');
like($index_source,
     qr/my \$can_mask = \$user_tab \? 0 :\s*systemd_can_mask/s,
     'index hides mask actions on user-unit tabs');
like($index_source, qr/my \$can_delete = \$user_tab \?/,
     'index shows delete actions only on user-unit tabs');
like($index_source, qr/\[ "delete", \$text\{'index_delete'\} \]/,
     'index includes a mass delete button');
like($index_source, qr/ui_form_grouped_buttons\(\[ \[ \@action_groups \],\s*\[ \\\@delete_buttons \] \]\)/s,
     'index isolates mass delete buttons on the far side');
like($mass_source, qr/sub mass_units\b/,
     'mass action page contains selection parser helper');
like($mass_source, qr/sub mass_log\b/,
     'mass action page contains grouped logging helper');
unlike($mass_source, qr/addboot_start|delboot_stop/,
       'mass action page omits combined start-enable handling');
like($mass_source, qr/sub print_action_result\b/,
     'mass action page contains result details helper');
like($mass_source, qr/returndropin/,
     'mass action return links preserve override edit context');
like($mass_source, qr/returndropfile/,
     'mass action return links preserve exact drop-in file context');
like($mass_source, qr/returnindex/,
     'mass action page can return transient actions to the owning tab');
like($mass_source, qr/sub print_action_start\b.*data-first-print/s,
     'mass action first progress line uses progressive print marker');
like($mass_source, qr/if \(\$printed_action_result\) \{\s*print ui_tag\('div', '', \{ 'class' => 'systemd-action-break'/s,
     'mass action result spacer is emitted only before the next action');
like($mass_source, qr/'style' => 'height: 1em;'/,
     'mass action result spacer is sized for readable separation');
like($mass_source, qr/print \$title, "\\n";/,
     'mass action result without details avoids a trailing break');
unlike($mass_source, qr/ui_details\(\{.*?print ui_br\(\), "\\n";/s,
       'mass action result with folded details avoids a trailing break');
like($mass_source, qr/'class'\s*=>\s*'inline inlined'/,
     'mass action results use inline details styling');
like($mass_source, qr/ui_tag\('pre'.*?'style'\s*=>\s*'margin-left: 10px;'/s,
     'mass action output uses theme pre styling like GRUB');
unlike($mass_source, qr/data-x-br/,
       'mass action results do not add extra spacer breaks');
like($mass_source, qr/systemd_can_runtime/,
     'mass action page checks runtime ACLs');
like($mass_source, qr/systemd_can_boot/,
     'mass action page checks boot ACLs');
like($mass_source, qr/systemd_can_delete/,
     'mass action page checks delete ACLs');
like($mass_source, qr/delete_user_unit/,
     'mass action page can delete user units');
like($save_source, qr/write_user_unit_file/,
     'save page uses safe user-unit writer');
like($save_source, qr/unit_file_editable/,
     'save page rejects direct writes to runtime-managed unit files');
like($save_source, qr/system_unit_file_writable/,
     'save page rejects direct writes to packaged unit files by default');
like($save_source, qr/systemd_evendoredit/,
     'save page reports packaged unit edit policy');
like($save_source, qr/boot_state_changeable.*?\(\$user_scope \|\| system_unit_file_writable\(\$u\)\)/s,
     'save page ignores edit-form boot changes for protected packaged units');
like($save_source, qr/verify_unit_data/,
     'save page verifies raw unit edits before writing');
like($save_source, qr/dropin_template/,
     'save page can create systemctl-edit style drop-in templates');
like($save_source, qr/verify_dropin_data/,
     'save page verifies edited drop-in overrides');
like($save_source, qr/dropfile/,
     'save page preserves exact drop-in file edits');
like($save_source, qr/write_system_dropin_config_file/,
     'save page can update non-standard system drop-ins');
like($save_source, qr/write_user_dropin_config_file/,
     'save page can update non-standard user drop-ins');
like($save_source, qr/delete_user_dropin_file/,
     'save page can delete user drop-in overrides');
like($save_source, qr/delete_system_dropin_file/,
     'save page can delete system drop-in overrides');
like($save_source,
     qr/my \(\$ok, \$out\) = delete_system_unit\(\$in\{'name'\}\);\s*\$ok \|\| error\(\$out\);/s,
     'save page reports failed system unit deletes');
like($save_source, qr/stock_unit/,
     'save page can return from override edits without saving');
like($save_source, qr/returndropin/,
     'save page preserves override context through runtime actions');
like($save_source, qr/returnindex/,
     'save page avoids returning stopped runtime-managed units to edit');
like($save_source, qr/if \(!\$in\{'new'\} &&\s*\(\$in\{'start'\}/,
     'save page treats runtime actions as edit-only actions');
like($save_source, qr/\$in\{'restart'\} = \$in\{'restart_policy'\}/,
     'save page maps create-form restart policy without action collision');
like($save_source, qr/\$config\{'create_return_index'\} eq '1'.*?index_url\(\$in\{'name'\}, \$user_scope, \$unituser\)/s,
     'save page can return to index after creating a unit');
like($save_source, qr/deps=1/,
     'save page redirects dependency requests to mass action page');
like($save_source, qr/props=1/,
     'save page redirects property requests to mass action page');
unlike($save_source, qr/name="conf"|ui_textarea\("conf"/,
       'save/edit flow no longer uses conf textarea name');
like($save_source, qr/systemd_can_create/,
     'save page checks create ACLs');
like($save_source, qr/get_creatable_unit_types\(\$user_scope\)/,
     'save page rejects user-scope-only unsupported unit types');
like($save_source, qr/\$user_scope.*?socket_user.*?socket_group/s,
     'save page strips socket owner fields for user units');
like($save_source, qr/systemd_can_dropin/,
     'save page checks drop-in ACLs');
like($save_source, qr/systemd_can_delete/,
     'save page checks delete ACLs');
like($edit_source, qr/\$config\{'default_linger'\}/,
     'new user-unit form honors configured default linger setting');
like($edit_source, qr/systemd_linger_user/,
     'user-unit forms use user-friendly linger wording');
like($edit_source, qr/get_creatable_unit_types\(\$create_user_scope\)/,
     'new user-unit form limits unit types by selected scope');
like($edit_source, qr/systemd_type_user/,
     'new user-unit form links to user-scope unit type help');
like($edit_source, qr/sub path_unit_placeholders\b.*?/s,
     'new unit form has scoped path-unit placeholders');
like($edit_source, qr/\/run\/user\/.*?\.config\/my-app\.conf/s,
     'new user path-unit form suggests user runtime and home paths');
like($edit_source, qr/sub service_unit_placeholders\b.*?user_scope_example_paths.*?\.config\/my-app\/env/s,
     'new user service form suggests user runtime and home paths');
like($edit_source, qr/ui_select\("restart_policy"/,
     'new service form avoids restart action field collision');
unlike($edit_source, qr/ui_select\("restart"/,
       'new service form does not name restart policy like an action button');
like($edit_source, qr/systemdExtraPlaceholders.*?timer: 'OnUnitInactiveSec=.*?socket: 'Backlog=/s,
     'new unit form has type-specific advanced placeholders');
like($edit_source, qr/slice: 'CPUQuota=50%\\nMemoryHigh=256M'/,
     'new slice advanced placeholder avoids structured slice fields');
unlike($edit_source, qr/slice: 'CPUWeight=.*MemoryMax=.*TasksMax=/s,
       'new slice advanced placeholder does not duplicate guided fields');
unlike($edit_source,
       qr/const systemdExtraPlaceholders = \{(?:(?!\n\t\};).)*target:/s,
       'new target unit form has no invalid target-body placeholder');
like($edit_source, qr/const extra = !service && type != 'target'/,
     'new target unit form hides type-specific body field');
like($edit_source, qr/sub socket_unit_placeholders\b.*?user_scope_example_paths/s,
     'new user socket form suggests user runtime paths');
like($edit_source, qr/systemd_socket_user_row.*?showrow\('systemd_socket_user_row', !enabled && socket\)/s,
     'new user socket form hides socket ownership fields');
like($edit_source, qr/force_user_scope_create.*ui_hidden\("userservice", 1\)/s,
     'new user-unit form fixes user scope in non-root user mode');
like($edit_source, qr/force_user_scope_owner.*ui_hidden\("unituser", \$default_unituser\)/s,
     'new user-unit form hides fixed user owner in non-root user mode');
like($edit_source, qr/sub edit_runtime_state\b/,
     'edit page formats systemd runtime states');
like($edit_source, qr/systemd_runtime_state.*systemd_unit_state/s,
     'edit page shows runtime and unit-file states in display order');
like($edit_source,
     qr/systemd_runtime_state.*systemd_runtime_state.*systemd_main_pid.*systemd_main_pid.*systemd_unit_state.*systemd_unit_state/s,
     'edit page links status rows to matching help titles');
like($edit_source,
     qr/systemd_unituser.*systemd_runtime_state.*systemd_unit_state.*systemd_boot.*systemd_linger_user/s,
     'edit page orders user unit metadata rows');
like($edit_source, qr/boot_state_changeable.*?\(\$edit_user_scope \|\| \$unit_file_writable\).*?systemd_can_boot/s,
     'edit page hides boot radio for protected packaged units');
like($edit_source, qr/readonly='readonly'/,
     'edit page shows runtime-managed unit files as read-only');
like($edit_source, qr/unit_file_editable/,
     'edit page hides save and delete for runtime-managed unit files');
like($edit_source, qr/system_unit_file_writable/,
     'edit page makes packaged system unit files read-only by default');
like($edit_source, qr/system_unit_file_deletable/,
     'edit page hides delete for packaged system unit files');
like($edit_source, qr/edit_depsnow/,
     'edit page includes dependency inspect action');
like($edit_source, qr/edit_propsnow/,
     'edit page includes property inspect action');
like($edit_source, qr/edit_overridenow/,
     'edit page includes override creation action');
like($edit_source, qr/edit_editoverridenow/,
     'edit page labels existing overrides as editable');
like($edit_source, qr/edit_deleteoverridenow/,
     'edit page labels override deletes clearly');
like($edit_source, qr/edit_stockunitnow/,
     'edit page links override edits back to the stock unit');
like($edit_source, qr/edit_view_stockunitnow/,
     'edit page labels protected base units as view-only from drop-ins');
like($edit_source, qr/stock_unit/,
     'edit page uses a grouped button for stock-unit navigation');
like($edit_source, qr/systemd_can_edit/,
     'edit page gates writable unit editor controls');
like($edit_source, qr/systemd_can_linger/,
     'edit page gates linger controls');
like($lib_source, qr/sub dropin_exists\b/,
     'library detects existing override files safely');
like($lib_source, qr/sub list_system_dropin_override_files\b/,
     'library lists system drop-in override files');
like($lib_source, qr/sub list_user_dropin_override_files\b/,
     'library lists user drop-in override files');
like($lib_source, qr/sub write_system_dropin_config_file\b/,
     'library writes exact system drop-in config files');
like($lib_source, qr/sub write_user_dropin_config_file\b/,
     'library writes exact user drop-in config files');
like($edit_source, qr/dropin_exists/,
     'edit page uses shared override detection');
like($index_source, qr/index_edit_url.*dropin_exists/s,
     'index page links units with existing overrides to the override file');
like($edit_source, qr/read_system_dropin_file/,
     'edit page can open system override files');
like($edit_source, qr/read_user_dropin_file/,
     'edit page can open user override files');
like($edit_source, qr/read_system_dropin_config_file/,
     'edit page can open exact system drop-in files');
like($edit_source, qr/read_user_dropin_config_file/,
     'edit page can open exact user drop-in files');
like($edit_source, qr/ui_hidden\("dropfile"/,
     'edit page preserves exact drop-in file selections');
unlike($edit_source, qr/ui_yesno_radio\("dropin"/,
       'edit page does not use a drop-in save toggle row');
like($edit_manual_source, qr/list_manual_unit_files/,
     'manual editor lists constrained unit files');
like($lib_source, qr/list_system_dropin_override_files/,
     'manual editor allowlist can include system drop-in files');
like($lib_source, qr/list_all_user_dropin_override_files/,
     'manual editor allowlist can include user drop-in files');
like($lib_source, qr/verify_dropin_data/,
     'manual editor validates drop-in files as drop-ins');
like($edit_manual_source, qr/ui_table_start\(undef, undef, 2\)/,
     'manual editor uses plain textarea table without a header');
unlike($edit_manual_source, qr/manual_user_file/,
       'manual editor selector shows raw file paths without user prefixes');
like($edit_manual_source, qr/manual_desc_user/,
     'manual editor shows a user-specific description for user files');
like($edit_manual_source, qr/manual_desc/,
     'manual editor shows a system description for system files');
like($edit_manual_source, qr/manual_empty_message/,
     'manual editor has an empty-state message for missing files');
like($edit_manual_source, qr/manual_edit_err/,
     'manual editor uses an edit-specific error title');
unlike($edit_manual_source, qr/action_links\(/,
       'manual editor header omits daemon reload action');
like($edit_manual_source, qr/systemd_can_manual/,
     'manual editor filters files by ACL');
like($edit_manual_source, qr/manual_unit_file_writable/,
     'manual editor hides save for read-only packaged unit files');
like($dropins_source, qr/list_system_dropin_override_files/,
     'drop-in inventory lists system drop-ins');
like($dropins_source, qr/list_all_user_dropin_override_files/,
     'drop-in inventory lists user drop-ins');
like($dropins_source, qr/systemd_acl_user_allowed/,
     'drop-in inventory filters user rows by ACL owner rules');
like($dropins_source, qr/systemd_can_dropin/,
     'drop-in inventory gates edit links with drop-in ACLs');
like($dropins_source, qr/sub dropin_file_arg\b/,
     'drop-in inventory links non-standard drop-ins by exact file');
like($save_manual_source, qr/write_manual_unit_file/,
     'manual save uses constrained unit file writer');
like($lib_source, qr/sub manual_unit_file_writable\b/,
     'library distinguishes writable manual files from read-only inventory');
like($save_manual_source, qr/mark_units_changed/,
     'manual system save marks daemon reload as needed');
like($save_manual_source, qr/mark_user_units_changed/,
     'manual user save marks user manager reload as needed');
like($save_manual_source, qr/systemd_can_manual/,
     'manual save checks manual ACLs');
like($lib_source, qr/sub create_system_unit\b.*?verify_unit_data\(.*?, 0\)/s,
     'system unit creation verifies rendered unit data');
like($lib_source, qr/sub create_user_unit\b.*?verify_unit_data\(.*?, 1, \$user\)/s,
     'user unit creation verifies rendered unit data in user mode');
like($type_help_source, qr/<tt>mount<\/tt>.*<tt>swap<\/tt>.*<tt>slice<\/tt>/s,
     'system unit type help documents privileged unit types');
like($type_user_help_source, qr/<tt>service<\/tt>.*<tt>timer<\/tt>.*<tt>slice<\/tt>/s,
     'user unit type help documents available user unit types');
like($type_user_help_source, qr/Mount, automount and swap units.*not\s+available/s,
     'user unit type help explains unavailable storage unit types');
like($path_help_source, qr/For user units.*home directory.*runtime directory/s,
     'path unit help explains user-scope path location');
like($socket_fifo_help_source, qr/For user units.*\/run\/user\/UID/s,
     'socket FIFO help explains user-scope path location');
like($socket_user_help_source, qr/For user units.*owned by that user/s,
     'socket owner help explains user-scope ownership');
like($workdir_help_source, qr/For user units.*home directory/s,
     'service working directory help explains user-scope paths');
like($workdir_help_source, qr/path beginning with\s*<tt>~<\/tt>.*leading\s*<tt>-<\/tt>/s,
     'working directory help documents accepted tilde and dash prefixes');
like($envfile_help_source, qr/Absolute path.*Prefix the path with\s*<tt>-<\/tt>/s,
     'environment file help documents absolute paths and dash prefix');
unlike($envfile_help_source, qr/<tt>~\//,
       'environment file help avoids unsupported tilde-path examples');
like($limitnofile_help_source, qr/<tt>infinity<\/tt>.*soft:hard/s,
     'open-files help documents infinity and soft-hard forms');
like($logstd_help_source, qr/<tt>append:\/path\/to\/file<\/tt>.*absolute file path/s,
     'standard output help documents appended absolute paths');
like($logstd_help_source, qr/<tt>fd:name<\/tt>/,
     'standard output help documents advanced systemd targets');
like($logerr_help_source, qr/<tt>truncate:\/path\/to\/file<\/tt>.*<tt>fd:name<\/tt>/s,
     'standard error help documents accepted output targets');
like($socketaccept_help_source, qr/one service\s+instance.*incoming connection/s,
     'socket accept help explains per-connection instances');
like($socketservice_help_source, qr/<tt>Accept=yes<\/tt>.*<tt>example\@\.service<\/tt>/s,
     'socket service help documents template services for accept mode');
like($timerpersistent_help_source, qr/For calendar timers.*does not catch up monotonic/s,
     'persistent timer help distinguishes calendar and monotonic timers');
like($conf_help_source, qr/drop-in override.*system or user systemd manager/s,
     'unit configuration help covers drop-ins and scoped reloads');
like($file_help_source, qr/drop-in override file.*vendor unit files/s,
     'configuration file help explains drop-ins and vendor files');
like($readwritepaths_help_source, qr/ProtectSystem=.*optional paths/s,
     'writable paths help connects protection and optional path prefixes');
like($unitconf_help_source, qr/For user units.*\/run\/user\/UID.*?resource controls apply/s,
     'type-specific help includes user-scope socket and slice notes');
like($slice_help_source, qr/For user units.*parent cgroup/s,
     'slice help explains user-scope resource boundary');
like($restart_source, qr/daemon-reload/,
     'restart page runs systemctl daemon-reload');
like($restart_source, qr/mark_daemon_reloaded/,
     'restart page clears daemon reload reminder');
like($restart_source, qr/systemd_can_reload/,
     'restart page checks reload ACL');
like($restart_user_source, qr/reload_user_manager/,
     'user restart page reloads the user manager');
like($restart_user_source, qr/mark_user_daemon_reloaded/,
     'user restart page clears user manager reload reminder');
like($restart_user_source, qr/systemd_can_reload_user/,
     'user restart page checks scoped reload ACL');

done_testing();
