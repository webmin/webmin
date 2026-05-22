#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use Cwd qw(abs_path);
use File::Temp qw(tempdir);
use IPC::Open3 ();
use Symbol qw(gensym);

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

my $bindir = script_dir();
my $module_dir = abs_path("$bindir/..") or die "module dir: $!";
my $rootdir = abs_path("$bindir/../..") or die "root dir: $!";

my $confdir = tempdir(CLEANUP => 1);
my $vardir = tempdir(CLEANUP => 1);
my $keadir = "$confdir/kea";
mkdir($keadir) or die "mkdir $keadir: $!";
mkdir("$confdir/kea-dhcp") or die "mkdir module config: $!";

open(my $cfh, ">", "$confdir/config") or die "config: $!";
print $cfh "os_type=generic-linux\nos_version=0\n";
close($cfh);
open(my $vfh, ">", "$confdir/var-path") or die "var-path: $!";
print $vfh "$vardir\n";
close($vfh);

sub write_plain_file
{
    my ($file, $content) = @_;
    open(my $fh, ">", $file) or die "$file: $!";
    print $fh $content;
    close($fh);
}

my $dhcp4_conf = "$keadir/kea-dhcp4.conf";
my $dhcp6_conf = "$keadir/kea-dhcp6.conf";
my $ddns_conf = "$keadir/kea-dhcp-ddns.conf";
my $ctrl_conf = "$keadir/kea-ctrl-agent.conf";
my $api_password = "$keadir/kea-api-password";
my $dhcp4_lease_file = "$vardir/kea-leases4.csv";
my $dhcp6_lease_file = "$vardir/kea-leases6.csv";

# Keep fixture configs intentionally small: each file has the top-level Kea
# object the module validates, but still includes enough data to render every
# structured tab.
write_plain_file($dhcp4_conf, <<'EOF');
// Stock Kea configs include comments that structured saves intentionally drop.
{
  "Dhcp4": {
    "interfaces-config": { "interfaces": [] },
    "lease-database": { "type": "memfile", "lfc-interval": 3600 },
    "control-socket": { "socket-type": "unix", "socket-name": "kea4-ctrl-socket" },
    "dhcp-ddns": {
      "enable-updates": true,
      "server-ip": "127.0.0.1",
      "server-port": 53001
    },
    "loggers": [
      {
        "name": "kea-dhcp4",
        "severity": "INFO",
        "debuglevel": 0,
        "output-options": [
          { "output": "stdout", "pattern": "%-5p %m\n" }
        ]
      }
    ],
    "renew-timer": 900,
    "rebind-timer": 1800,
    "valid-lifetime": 3600,
    "option-data": [
      { "name": "domain-name-servers", "data": "192.0.2.1, 192.0.2.2" },
      { "code": 15, "data": "example.org" },
      { "name": "default-ip-ttl", "data": "0xf0" }
    ],
    "shared-networks": [],
    "subnet4": []
  }
}
EOF

write_plain_file($dhcp6_conf, <<'EOF');
{
  "Dhcp6": {
    "interfaces-config": { "interfaces": [] },
    "lease-database": { "type": "memfile", "lfc-interval": 3600 },
    "control-socket": { "socket-type": "unix", "socket-name": "kea6-ctrl-socket" },
    "dhcp-ddns": {
      "enable-updates": false,
      "server-ip": "127.0.0.1",
      "server-port": 53001
    },
    "loggers": [
      {
        "name": "kea-dhcp6",
        "severity": "INFO",
        "debuglevel": 0,
        "output-options": [
          { "output": "stdout", "pattern": "%-5p %m\n" }
        ]
      }
    ],
    "renew-timer": 1000,
    "rebind-timer": 2000,
    "preferred-lifetime": 3000,
    "valid-lifetime": 4000,
    "option-data": [
      { "name": "dns-servers", "data": "2001:db8:2::45, 2001:db8:2::100" },
      { "code": 12, "data": "2001:db8::1" }
    ],
    "shared-networks": [],
    "subnet6": []
  }
}
EOF

write_plain_file($ddns_conf, <<'EOF');
// DHCP-DDNS is a separate Kea daemon shared by DHCPv4 and DHCPv6.
{
  "DhcpDdns": {
    "ip-address": "127.0.0.1",
    "port": 53001,
    "dns-server-timeout": 500,
    "control-socket": {
      "socket-type": "unix",
      "socket-name": "kea-ddns-ctrl-socket"
    },
    "tsig-keys": [
      {
        "name": "ddns-key",
        "algorithm": "hmac-sha256",
        "secret": "ZmFrZQ=="
      }
    ],
    "forward-ddns": {
      "ddns-domains": [
        {
          "name": "example.org.",
          "key-name": "ddns-key",
          "dns-servers": [
            { "ip-address": "192.0.2.53", "port": 53 },
            { "ip-address": "192.0.2.54", "port": 5353 }
          ]
        }
      ]
    },
    "reverse-ddns": {
      "ddns-domains": [
        {
          "name": "2.0.192.in-addr.arpa.",
          "key-name": "ddns-key",
          "dns-servers": [
            { "ip-address": "192.0.2.53", "port": 53 }
          ]
        }
      ]
    },
    "loggers": [
      {
        "name": "kea-dhcp-ddns",
        "severity": "INFO",
        "debuglevel": 0,
        "output-options": [
          { "output": "stdout", "pattern": "%-5p %m\n" }
        ]
      }
    ]
  }
}
EOF

write_plain_file($ctrl_conf, <<"EOF");
{
  "Control-agent": {
    "http-host": "127.0.0.1",
    "http-port": 8000,
    "authentication": {
      "directory": "$keadir",
      "clients": [
        { "user": "kea-api", "password-file": "kea-api-password" }
      ]
    }
  }
}
EOF

# Kea memfile lease databases are CSV files. The fixtures include one active
# and one expired lease per protocol so runtime pages can prove both parsing
# and filtering behavior.
write_plain_file($dhcp4_lease_file, <<'EOF');
address,hwaddr,client_id,valid_lifetime,expire,subnet_id,fqdn_fwd,fqdn_rev,hostname,state,user_context
192.0.2.50,00:11:22:33:44:55,01:00:11:22:33:44:55,3600,4102444800,1,0,0,alpha,0,
192.0.2.51,00:11:22:33:44:66,01:00:11:22:33:44:66,3600,1,1,0,0,expired,0,
EOF

write_plain_file($dhcp6_lease_file, <<'EOF');
address,duid,valid_lifetime,expire,subnet_id,pref_lifetime,lease_type,iaid,prefix_len,fqdn_fwd,fqdn_rev,hostname,hwaddr,state,user_context,pool_id
2001:db8:1::50,00:01:02:03,4000,4102444800,1,3000,0,1,128,0,0,bravo,00:11:22:33:44:77,0,,0
2001:db8:1::51,00:01:02:04,4000,1,1,3000,0,2,128,0,0,expired6,00:11:22:33:44:88,0,,0
EOF

sub write_module_config_dir
{
    my ($dir, $paths) = @_;
    $paths ||= { };
    my $dhcp4_path = $paths->{dhcp4_path} || $^X;
    my $dhcp6_path = $paths->{dhcp6_path} || $^X;
    my $ddns_path = $paths->{ddns_path} || $^X;
    my $ctrl_agent_path = $paths->{ctrl_agent_path} || $^X;
    my $keactrl_path = $paths->{keactrl_path} || $^X;
    write_plain_file("$dir/kea-dhcp/config", <<"EOF");
dhcp4_conf=$dhcp4_conf
dhcp6_conf=$dhcp6_conf
ddns_conf=$ddns_conf
ctrl_agent_conf=$ctrl_conf
dhcp4_path=$dhcp4_path
dhcp6_path=$dhcp6_path
ddns_path=$ddns_path
ctrl_agent_path=$ctrl_agent_path
keactrl_path=$keactrl_path
dhcp4_lease_file=$dhcp4_lease_file
dhcp6_lease_file=$dhcp6_lease_file
dhcp4_pid_file=$vardir/kea-dhcp4.pid
dhcp6_pid_file=$vardir/kea-dhcp6.pid
ddns_pid_file=$vardir/kea-dhcp-ddns.pid
ctrl_agent_pid_file=$vardir/kea-ctrl-agent.pid
start_cmd=/bin/true
stop_cmd=/bin/true
restart_cmd=/bin/true
EOF
}

sub write_module_config
{
    my ($paths) = @_;
    write_module_config_dir($confdir, $paths);
}
write_module_config();

$ENV{'WEBMIN_CONFIG'} = $confdir;
$ENV{'WEBMIN_VAR'} = $vardir;
$ENV{'FOREIGN_MODULE_NAME'} = 'kea-dhcp';
$ENV{'FOREIGN_ROOT_DIRECTORY'} = $rootdir;

chdir($module_dir) or die "chdir $module_dir: $!";
require "$module_dir/kea-dhcp-lib.pl";
our (%config, %in, %text);
our (%kea_component_status_cache);

$INC{'kea-dhcp-lib.pl'} ||= "$module_dir/kea-dhcp-lib.pl";
{
    local @INC = ($module_dir, @INC);
    require "$module_dir/acl_security.pl";
}

sub urlenc
{
    my $s = shift;
    $s = '' if !defined $s;
    $s =~ s/([^A-Za-z0-9._~-])/sprintf('%%%02X', ord($1))/ge;
    return $s;
}

sub query_string
{
    my ($params) = @_;
    return join('&', map {
        urlenc($_).'='.urlenc($params->{$_})
    } sort keys %{$params || {}});
}

# Execute real Kea CGIs under a disposable Webmin environment. This catches
# missing globals, broken tab rendering, and invalid UI helper calls.
sub run_cgi
{
    my ($cgi, $params, $extra_env) = @_;
    my $query = query_string($params || {});
    my %env = (
        PATH                   => '/bin:/usr/bin',
        WEBMIN_CONFIG          => $confdir,
        WEBMIN_VAR             => $vardir,
        FOREIGN_MODULE_NAME    => 'kea-dhcp',
        FOREIGN_ROOT_DIRECTORY => $rootdir,
        REQUEST_METHOD         => 'GET',
        SCRIPT_NAME            => "/kea-dhcp/$cgi",
        QUERY_STRING           => $query,
        SERVER_NAME            => 'localhost',
        SERVER_PORT            => '10000',
        HTTP_HOST              => 'localhost:10000',
        REMOTE_USER            => 'admin',
        BASE_REMOTE_USER       => 'admin',
    );
    if ($extra_env) {
        foreach my $key (keys %$extra_env) {
            $env{$key} = $extra_env->{$key};
        }
    }

    my $errfh = gensym();
    local %ENV = %env;
    my $pid = IPC::Open3::open3(my $in, my $out, $errfh,
                                $^X, "-I$rootdir", "$module_dir/$cgi");
    close($in);
    local $/;
    my $stdout = <$out>;
    my $stderr = <$errfh>;
    $stdout = '' if !defined $stdout;
    $stderr = '' if !defined $stderr;
    close($out);
    close($errfh);
    waitpid($pid, 0);
    return {
        out    => $stdout,
        err    => $stderr,
        status => $? >> 8,
    };
}

sub cgi_ok
{
    my ($cgi, $params, $name, $extra_env) = @_;
    my $res = run_cgi($cgi, $params, $extra_env);
    is($res->{status}, 0, "$name exits cleanly") or diag($res->{err});
    like($res->{out}, qr/Content-type:/i, "$name returns a CGI response");
    return $res->{out};
}

sub html_has
{
    my ($html, $pattern, $name) = @_;
    like($html, $pattern, $name);
}

foreign_require('kea-dhcp', 'log_parser.pl');
is(foreign_call('kea-dhcp', 'parse_webmin_log',
                'root', 'save_options.cgi', 'modify', 'global-options',
                'dhcp4', {}),
   'Saved DHCPv4 global settings',
   'Webmin log parser formats global settings changes');
like(foreign_call('kea-dhcp', 'parse_webmin_log',
                  'root', 'save_shared.cgi', 'create', 'shared-network',
                  'office', {}),
     qr/^Created shared network <tt\b[^>]*>office<\/tt>\s*$/,
     'Webmin log parser formats shared-network changes');
is(foreign_call('kea-dhcp', 'parse_webmin_log',
                'root', 'delete_objects.cgi', 'delete', 'objects', 3, {}),
   'Deleted 3 Kea DHCP objects',
   'Webmin log parser formats bulk delete changes');
is(foreign_call('kea-dhcp', 'parse_webmin_log',
                'root', 'delete_objects.cgi', 'delete', 'objects', 1, {}),
   'Deleted 1 Kea DHCP object',
   'Webmin log parser formats singular bulk delete changes');

my @passwords = kea_control_agent_password_files();
is_deeply(\@passwords, [ $api_password ],
          'Control Agent password file is discoverable');
ok(scalar(grep { $_ eq $api_password } get_all_config_files()),
   'configuration backups include Control Agent password file');
ok(scalar(grep { $_->{file} eq $api_password && $_->{type} eq 'password' }
          kea_manual_edit_files()),
   'manual editor allow-list includes Control Agent password file');
is(kea_component('dhcp4')->{'unit'}, 'kea-dhcp4-server.service',
   'default service unit follows Debian Kea package naming');
{
    my %el_config;
    read_file("$module_dir/config-redhat-linux", \%el_config);
    is($el_config{'dhcp4_unit'}, 'kea-dhcp4.service',
       'modern RPM config uses EL Kea DHCPv4 unit name');
    like($el_config{'stop_cmd'}, qr/\bkea-dhcp4\.service\b/,
         'modern RPM config stop command uses EL Kea unit names');
}
{
    no warnings 'redefine';
    local *has_command = sub {
        my ($cmd) = @_;
        return '/bin/systemctl' if ($cmd eq 'systemctl');
        return;
    };
    local $config{'dhcp4_unit'} = 'kea-dhcp4.service';
    local $config{'dhcp6_unit'} = 'kea-dhcp6.service';
    local $config{'ddns_unit'} = 'kea-dhcp-ddns.service';
    local $config{'ctrl_agent_unit'} = 'kea-ctrl-agent.service';
    local $config{'stop_cmd'} = '';
    is(kea_component_systemd_unit(kea_component('dhcp4')), 'kea-dhcp4.service',
       'systemd unit lookup uses the configured DHCPv4 unit');
    like(kea_action_command('stop'),
       qr{systemctl stop kea-dhcp4\.service kea-dhcp6\.service kea-dhcp-ddns\.service kea-ctrl-agent\.service},
       'generated systemctl action uses configured unit names');
}
{
    no warnings qw(redefine once);
    local %kea_component_status_cache;
    local *has_command = sub {
        my ($cmd) = @_;
        return '/bin/systemctl' if ($cmd eq 'systemctl');
        return;
    };
    local *kea_component_pid = sub { return 0; };
    local *kea_systemd_unit_properties = sub {
        my ($unit) = @_;
        return {
            LoadState      => 'loaded',
            ActiveState    => 'active',
            Result         => 'success',
            MainPID        => 12345,
            ExecMainStatus => 0,
            ConditionResult => 'yes',
        } if ($unit eq 'kea-dhcp4.service');
        return { LoadState => 'not-found' };
    };
    local $config{'dhcp4_unit'} = 'kea-dhcp4.service';
    is(kea_component_systemd_unit(kea_component('dhcp4')), 'kea-dhcp4.service',
       'systemd unit comes from configured Kea unit name');
    my $status = kea_component_status(kea_component('dhcp4'));
    is($status->{'unit'}, 'kea-dhcp4.service',
       'component status uses the configured Kea unit name');
    is($status->{'state'}, 'running',
       'component status is read from the configured Kea unit');
}

my $index = cgi_ok('index.cgi', { mode => 'dhcp4' }, 'index DHCPv4 tab');
html_has($index, qr/No shared networks are defined\. Use the button above to create one\./,
         'index empty shared-network text is concise');
html_has($index, qr/No subnets are defined\. Use the button above to create one\./,
         'index empty subnet text is concise');
html_has($index, qr/DHCPv4 Global Settings/s,
         'index links to DHCPv4 global settings');
html_has($index, qr/Runtime Status/s,
         'index links to runtime status details');
html_has($index, qr/Edit Config Files/s,
         'index links to raw config editor');
html_has($index, qr/The Kea configuration file\s*<tt\b[^>]*>\Q$dhcp4_conf\E<\/tt>\s*contains comments.*Webmin saves changes from these settings pages/s,
         'index warns that DHCPv4 config comments will be removed');

my $ddns_index = cgi_ok('index.cgi', { mode => 'ddns' }, 'index DHCP-DDNS tab');
html_has($ddns_index, qr/Manage the standalone Kea DHCP-DDNS daemon/s,
         'index renders the DHCP-DDNS tab');
html_has($ddns_index, qr/127\.0\.0\.1:53001.*example\.org\./s,
         'DHCP-DDNS tab summarizes listener and forward zone');
html_has($ddns_index, qr/DHCPv4 sender.*Enabled.*127\.0\.0\.1:53001.*matches D2 listener/s,
         'DHCP-DDNS tab shows matching DHCPv4 sender status');
html_has($ddns_index, qr/DHCPv6 sender.*Disabled/s,
         'DHCP-DDNS tab shows disabled DHCPv6 sender status');
html_has($ddns_index, qr/DHCP-DDNS Settings/s,
         'index links to DHCP-DDNS settings');

my $services_index = cgi_ok('index.cgi', { mode => 'services' },
                            'index services tab');
my $dhcp4_conf_url = urlize($dhcp4_conf);
unlike($services_index, qr/systemd unit/s,
       'services table does not expose Linux-specific unit column');
html_has($services_index,
         qr/edit_text\.cgi\?file=\Q$dhcp4_conf_url\E.*\Q$dhcp4_conf\E/s,
         'services table links config files to manual editor when ACL allows');
html_has($services_index, qr/Configured endpoint: 127\.0\.0\.1:8000/s,
         'Control Agent summary describes configured endpoint without implying runtime');

my $missing_confdir = tempdir(CLEANUP => 1);
mkdir("$missing_confdir/kea-dhcp")
    or die "mkdir missing module config: $!";
write_plain_file("$missing_confdir/config", "os_type=generic-linux\nos_version=0\n");
write_plain_file("$missing_confdir/var-path", "$vardir\n");
write_module_config_dir($missing_confdir, {
    dhcp4_path       => "$confdir/missing-kea-dhcp4",
    dhcp6_path       => "$confdir/missing-kea-dhcp6",
    ddns_path        => "$confdir/missing-kea-dhcp-ddns",
    ctrl_agent_path  => "$confdir/missing-kea-ctrl-agent",
    keactrl_path     => "$confdir/missing-keactrl",
});
my $missing_index = cgi_ok('index.cgi', { mode => 'dhcp4' },
                           'index missing-install page',
                           { WEBMIN_CONFIG => $missing_confdir });
html_has($missing_index, qr/Kea DHCP executables do not exist/,
         'missing-install page explains missing executables');
unlike($missing_index, qr/class=["'][^"']*\btab-pane\b/,
       'missing-install page does not render module tabs');
unlike($missing_index, qr/Edit Config Files|Start all Kea services|Stop all Kea services/,
       'missing-install page does not render normal module actions');

my $orig_dhcp4_conf;
{
    open(my $orig4fh, "<", $dhcp4_conf) or die "$dhcp4_conf: $!";
    local $/;
    $orig_dhcp4_conf = <$orig4fh>;
    close($orig4fh);
}
write_plain_file($dhcp4_conf, <<'EOF');
{
  "Dhcp4": {
    "shared-networks": [
      {
        "name": "lan",
        "subnet4": [
          { "id": 1, "subnet": "192.0.2.0/24" }
        ]
      }
    ],
    "subnet4": []
  }
}
EOF
my $blocked_delete = run_cgi('delete_objects.cgi', { version => 4, d_shared => 0 });
like($blocked_delete->{out}, qr/still contains subnets/,
     'bulk delete refuses to remove a non-empty shared network');
my $blocked_negative_shared_edit = run_cgi('edit_shared.cgi',
                                           { version => 4, idx => -1 });
like($blocked_negative_shared_edit->{out}, qr/requested shared network was not found/,
     'shared-network editor rejects negative indexes');
my $blocked_negative_delete = run_cgi('delete_objects.cgi',
                                      { version => 4, d_subnet => '-1:0' });
like($blocked_negative_delete->{out}, qr/requested subnet was not found/,
     'bulk delete rejects negative shared-network subnet indexes');
my $blocked_negative_edit = run_cgi('edit_subnet.cgi',
                                    { version => 4, sidx => -1, idx => 0 });
like($blocked_negative_edit->{out}, qr/requested subnet was not found/,
     'subnet editor rejects negative shared-network indexes');
my $blocked_negative_save = run_cgi('save_subnet.cgi',
                                    { version => 4, delete => 1, sidx => -1, idx => 0 });
like($blocked_negative_save->{out}, qr/requested subnet was not found/,
     'subnet save rejects negative shared-network indexes');
my $interfaces_warning = cgi_ok('index.cgi', { mode => 'dhcp4' },
                                'index warns about empty interfaces');
html_has($interfaces_warning, qr/no listening interfaces are configured/s,
         'DHCP tab warns when subnets exist without listening interfaces');
my $services_warning = cgi_ok('index.cgi', { mode => 'services' },
                              'services warn about empty interfaces');
html_has($services_warning,
         qr/Subnets exist, but no listening interfaces are configured/s,
         'services table warns when a DHCP service has subnets but no interfaces');
write_plain_file($dhcp4_conf, $orig_dhcp4_conf);

my $orig_dhcp6_conf;
{
    open(my $orig6fh, "<", $dhcp6_conf) or die "$dhcp6_conf: $!";
    local $/;
    $orig_dhcp6_conf = <$orig6fh>;
    close($orig6fh);
}
write_plain_file($dhcp4_conf, <<'EOF');
{
  "Dhcp4": {
    "lease-database": { "type": "memfile" },
    "subnet4": [
      {
        "id": 1,
        "subnet": "192.0.2.0/24",
        "pools": [ { "pool": "192.0.2.10 - 192.0.2.100" } ],
        "reservations": [
          { "hw-address": "00:11:22:33:44:55", "ip-address": "192.0.2.60" }
        ]
      }
    ]
  }
}
EOF
write_plain_file($dhcp6_conf, <<'EOF');
{
  "Dhcp6": {
    "lease-database": { "type": "memfile" },
    "subnet6": [
      {
        "id": 1,
        "subnet": "2001:db8:1::/64",
        "pools": [ { "pool": "2001:db8:1::/80" } ],
        "pd-pools": [
          { "prefix": "2001:db8:8::", "prefix-len": 56, "delegated-len": 64 }
        ],
        "reservations": [
          { "duid": "00:01:02:03", "ip-addresses": [ "2001:db8:1::60" ] }
        ]
      }
    ]
  }
}
EOF

# Runtime pages are intentionally read-only: they expose useful operational
# data from memfile leases without inventing a DHCP "connections" concept.
my $leases_active = cgi_ok('runtime.cgi', { mode => 'active' },
                           'active leases page');
html_has($leases_active, qr/192\.0\.2\.50.*alpha/s,
         'active leases show DHCPv4 memfile lease');
html_has($leases_active, qr/2001:db8:1::50.*bravo/s,
         'active leases show DHCPv6 memfile lease');
unlike($leases_active, qr/192\.0\.2\.51|expired6/,
       'active leases omit expired memfile rows');
html_has($leases_active,
         qr/used by DHCPv4.*\Q$dhcp4_lease_file\E.*DHCPv6.*\Q$dhcp6_lease_file\E/s,
         'active leases intro shows configured DHCPv4 and DHCPv6 lease files');
unlike($leases_active, qr/Lease file:\s/,
       'active leases do not repeat lease file labels per service');
my $leases_pools = cgi_ok('runtime.cgi', { mode => 'pools' },
                          'pool usage page');
html_has($leases_pools, qr/192\.0\.2\.0\/24.*1/s,
         'pool usage counts active DHCPv4 leases by subnet ID');
html_has($leases_pools, qr/2001:db8:1::\/64.*1.*1.*1/s,
         'pool usage shows DHCPv6 pools, prefix pools, reservations, and leases');
my $leases_stats = cgi_ok('runtime.cgi', { mode => 'stats' },
                          'lease statistics page');
html_has($leases_stats, qr/\Q$dhcp4_lease_file\E/s,
         'lease statistics show the configured DHCPv4 lease file');
html_has($leases_stats, qr/\Q$dhcp6_lease_file\E/s,
         'lease statistics show the configured DHCPv6 lease file');
html_has($leases_stats, qr/DHCPv4.*1.*2.*1/s,
         'lease statistics count DHCPv4 active, total, and inactive leases');
html_has($leases_stats, qr/DHCPv6.*1.*2.*1/s,
         'lease statistics count DHCPv6 active, total, and inactive leases');
my $leases_logs = cgi_ok('runtime.cgi', { mode => 'logs' },
                         'recent Kea logs page');
html_has($leases_logs, qr/No recent log lines were found|DHCPv4/s,
         'recent logs page renders even without journal output');
write_plain_file($dhcp4_conf, $orig_dhcp4_conf);
write_plain_file($dhcp6_conf, $orig_dhcp6_conf);

my %global_modes = (
    ddns_sender => qr/Name-change request destination.*Enable updates.*Update behavior/s,
    interfaces => qr/Listen on interfaces/,
    storage    => qr/Lease database.*Control socket/s,
    logging    => qr/Loggers.*kea-dhcp4.*INFO.*stdout/s,
    timers     => qr/Renew timer.*Valid lifetime/s,
    options    => qr/Common options.*Additional option data/s,
    advanced   => qr/Authoritative.*DHCP server identifier/s,
);
foreach my $mode (sort keys %global_modes) {
    my $html = cgi_ok('edit_options.cgi',
                      { version => 4, mode => $mode },
                      "DHCPv4 global $mode tab");
    html_has($html, $global_modes{$mode},
             "DHCPv4 global $mode tab renders expected controls");
    if ($mode eq 'advanced') {
        unlike($html, qr/Usually leave empty\. An incorrect server identifier/,
               'advanced option warnings are not printed inline');
        html_has($html, qr/opt_dhcp_server_identifier/,
                 'advanced DHCP option label links to help');
    }
    if ($mode eq 'interfaces') {
        html_has($html, qr/The Kea configuration file\s*<tt\b[^>]*>\Q$dhcp4_conf\E<\/tt>\s*contains comments.*Webmin saves changes from these settings pages/s,
                 'global editor names the commented DHCPv4 config file');
        html_has($html, qr/field_interfaces.*field_dhcp_socket_type/s,
                 'interface settings labels link to help');
    }
    if ($mode eq 'storage') {
        html_has($html, qr/field_lease_database_type.*field_control_socket_name/s,
                 'storage and control socket labels link to help');
    }
    if ($mode eq 'logging') {
        html_has($html, qr/field_logger_name.*field_logger_pattern/s,
                 'logger table headings link to help');
    }
    if ($mode eq 'ddns_sender') {
        html_has($html,
                 qr/field_ddns_enable_updates.*field_ddns_server_ip.*field_ddns_send_updates/s,
                 'DHCP-DDNS sender labels link to help');
    }
}

my $v6_interfaces = cgi_ok('edit_options.cgi',
                           { version => 6, mode => 'interfaces' },
                           'DHCPv6 global interfaces tab warning check');
html_has($v6_interfaces, qr/DHCPv6 does not provide the default router/s,
         'DHCPv6 settings warn that Router Advertisements provide the default route');
my $v6_index = cgi_ok('index.cgi', { mode => 'dhcp6' },
                      'DHCPv6 index tab warning check');
html_has($v6_index, qr/DHCPv6 does not provide the default router/s,
         'DHCPv6 index tab warns that Router Advertisements provide the default route');
my $v6_ddns_sender_tab = cgi_ok('edit_options.cgi',
                                { version => 6, mode => 'ddns_sender' },
                                'DHCPv6 DDNS sender tab');
html_has($v6_ddns_sender_tab,
         qr/Configure how DHCPv6 sends DNS update requests.*Name-change request destination/s,
         'DHCPv6 DDNS sender tab renders sender controls');

my $v6_options = cgi_ok('edit_options.cgi',
                        { version => 6, mode => 'options' },
                        'DHCPv6 global options tab');
html_has($v6_options, qr/DNS servers.*Unicast address/s,
         'DHCPv6 named common options render');
html_has($v6_options, qr/2001:db8::1/s,
         'DHCPv6 numeric option code 12 is promoted to unicast field');
html_has($v6_options, qr/class=["'][^"']*\boption-data-table\b/s,
         'additional option editor uses option-data-table wrapper');
html_has($v6_options, qr/field_option_name.*field_option_data/s,
         'additional option-data headings link to help');

my %ddns_modes = (
    listener => qr/Listener.*IP address.*DNS server timeout.*Control socket/s,
    zones    => qr/Forward DDNS.*example\.org\..*Reverse DDNS/s,
    tsig     => qr/TSIG keys.*ddns-key.*hmac-sha256/s,
    logging  => qr/Loggers.*kea-dhcp-ddns.*INFO.*stdout/s,
);
foreach my $mode (sort keys %ddns_modes) {
    my $html = cgi_ok('edit_ddns.cgi',
                      { mode => $mode },
                      "DHCP-DDNS $mode tab");
    html_has($html, $ddns_modes{$mode},
             "DHCP-DDNS $mode tab renders expected controls");
    if ($mode eq 'listener') {
        html_has($html, qr/The Kea configuration file\s*<tt\b[^>]*>\Q$ddns_conf\E<\/tt>\s*contains comments/s,
                 'DHCP-DDNS editor names the commented D2 config file');
        html_has($html, qr/field_ddns_ip_address.*field_ddns_timeout.*field_control_socket_name/s,
                 'DHCP-DDNS listener labels link to help');
        html_has($html, qr/<select[^>]+name=["']ncr_protocol["'].*value=["']UDP["']/s,
                 'DHCP-DDNS listener constrains NCR protocol values');
        html_has($html, qr/<select[^>]+name=["']ncr_format["'].*value=["']JSON["']/s,
                 'DHCP-DDNS listener constrains NCR format values');
    }
    if ($mode eq 'zones') {
        html_has($html, qr/field_ddns_domain_name.*field_ddns_domain_port/s,
                 'DHCP-DDNS zone headings link to help');
        html_has($html, qr/Mixed per-server ports/s,
                 'DHCP-DDNS zones make mixed server ports visible');
    }
    if ($mode eq 'tsig') {
        html_has($html, qr/field_tsig_key_name.*field_tsig_key_secret/s,
                 'DHCP-DDNS TSIG headings link to help');
        html_has($html, qr/<select[^>]+name=["']key_algorithm_0["'].*hmac-sha256/s,
                 'DHCP-DDNS TSIG editor constrains algorithm values');
        unlike($html, qr/ZmFrZQ==/,
               'DHCP-DDNS TSIG editor does not print existing secrets');
    }
}

my $ddns_listener_only_save = run_cgi('save_ddns.cgi', {
    ip_address          => '127.0.0.2',
    port                => 53002,
    dns_server_timeout  => 750,
    control_socket_type => 'unix',
    control_socket_name => 'kea-ddns-ctrl-socket',
});
is($ddns_listener_only_save->{status}, 0,
   'DHCP-DDNS listener-only save exits cleanly')
    or diag($ddns_listener_only_save->{err});
my ($listener_only_ddns, $listener_only_ddns_err) =
    kea_read_component_config(kea_component('ddns'));
ok(!defined($listener_only_ddns_err),
   'listener-only DHCP-DDNS save reads back cleanly');
is($listener_only_ddns->{'forward-ddns'}->{'ddns-domains'}->[0]->{'name'},
   'example.org.',
   'listener-only save preserves forward DDNS domains');
is($listener_only_ddns->{'reverse-ddns'}->{'ddns-domains'}->[0]->{'name'},
   '2.0.192.in-addr.arpa.',
   'listener-only save preserves reverse DDNS domains');
is($listener_only_ddns->{'tsig-keys'}->[0]->{'secret'}, 'ZmFrZQ==',
   'listener-only save preserves TSIG keys');
is($listener_only_ddns->{'loggers'}->[0]->{'name'}, 'kea-dhcp-ddns',
   'listener-only save preserves loggers');
is($listener_only_ddns->{'dns-server-timeout'}, 750,
   'listener-only save stores the D2 DNS server timeout');
my $ddns_non_default_loopback = cgi_ok('index.cgi', { mode => 'ddns' },
                                      'DHCP-DDNS non-default loopback summary');
html_has($ddns_non_default_loopback,
         qr/Non-default loopback address.*sender settings point to the same listener/s,
         'DHCP-DDNS summary explains non-default loopback listener');
unlike($ddns_non_default_loopback,
       qr/D2 is normally bound to loopback\./,
       'DHCP-DDNS summary does not show the stronger non-loopback warning for 127.0.0.2');

my $ddns_zone_only_save = run_cgi('save_ddns.cgi', {
    fwd_name_0    => 'example.org.',
    fwd_key_0     => 'ddns-key',
    fwd_servers_0 => '192.0.2.53 192.0.2.54',
    fwd_port_0    => '',
});
is($ddns_zone_only_save->{status}, 0,
   'DHCP-DDNS zone-only save exits cleanly')
    or diag($ddns_zone_only_save->{err});
my ($zone_only_ddns, $zone_only_ddns_err) =
    kea_read_component_config(kea_component('ddns'));
ok(!defined($zone_only_ddns_err),
   'zone-only DHCP-DDNS save reads back cleanly');
is_deeply(
    [ map { $_->{'port'} }
      @{$zone_only_ddns->{'forward-ddns'}->{'ddns-domains'}->[0]->{'dns-servers'}} ],
    [ 53, 5353 ],
    'zone-only save preserves mixed DNS server ports when shared port is blank');
is($zone_only_ddns->{'ip-address'}, '127.0.0.2',
   'zone-only save preserves listener fields');

my $ddns_unknown_key_save = run_cgi('save_ddns.cgi', {
    fwd_name_0    => 'missing-key.example.',
    fwd_key_0     => 'missing-key',
    fwd_servers_0 => '192.0.2.53',
});
like($ddns_unknown_key_save->{out}.$ddns_unknown_key_save->{err},
     qr/no TSIG key with that name is defined/,
     'DHCP-DDNS save rejects domains that reference unknown TSIG keys');

my $ddns_bad_server_save = run_cgi('save_ddns.cgi', {
    fwd_name_0    => 'bad-server.example.',
    fwd_servers_0 => 'ns1.example.org',
});
like($ddns_bad_server_save->{out}.$ddns_bad_server_save->{err},
     qr/must be an IPv4 or IPv6 address/,
     'DHCP-DDNS save rejects DNS server hostnames');

my $ddns_blank_algorithm_save = run_cgi('save_ddns.cgi', {
    key_name_0   => 'new-ddns-key',
    key_secret_0 => 'ZmFrZQ==',
});
like($ddns_blank_algorithm_save->{out}.$ddns_blank_algorithm_save->{err},
     qr/must select an algorithm/,
     'DHCP-DDNS save rejects filled TSIG rows without an algorithm');

my $ddns_tsig_blank_save = run_cgi('save_ddns.cgi', {
    key_name_0      => 'ddns-key',
    key_algorithm_0 => 'hmac-sha256',
    key_secret_0    => '',
});
is($ddns_tsig_blank_save->{status}, 0,
   'DHCP-DDNS TSIG save with blank existing secret exits cleanly')
    or diag($ddns_tsig_blank_save->{err});
my ($blank_secret_ddns, $blank_secret_ddns_err) =
    kea_read_component_config(kea_component('ddns'));
ok(!defined($blank_secret_ddns_err),
   'blank-secret DHCP-DDNS save reads back cleanly');
is($blank_secret_ddns->{'tsig-keys'}->[0]->{'secret'}, 'ZmFrZQ==',
   'blank TSIG secret keeps the existing secret');

my $ddns_bad_debug_save = run_cgi('save_ddns.cgi', {
    log_name_0       => 'kea-dhcp-ddns',
    log_severity_0   => 'INFO',
    log_debuglevel_0 => 4,
    log_output_0     => 'stdout',
    log_pattern_0    => '%-5p %m\n',
});
like($ddns_bad_debug_save->{out}.$ddns_bad_debug_save->{err},
     qr/debug level can only be non-zero when severity is DEBUG/,
     'DHCP-DDNS save rejects non-zero debug level below DEBUG severity');

my $argument_check_ddns_binary = "$confdir/kea-dhcp-ddns";
write_plain_file($argument_check_ddns_binary, <<'EOF');
#!/bin/sh
if [ "$1" = "-t" ] && [ -r "$2" ] && [ -z "$3" ]; then
    exit 0
fi
echo "bad validation arguments: $*" >&2
exit 1
EOF
chmod(0755, $argument_check_ddns_binary)
    or die "chmod $argument_check_ddns_binary: $!";
write_module_config({ ddns_path => $argument_check_ddns_binary });
my $ddns_validation_args = run_cgi('save_ddns.cgi', {
    ip_address => '127.0.0.3',
});
is($ddns_validation_args->{status}, 0,
   'DHCP-DDNS native validation passes a readable config file to the test flag')
    or diag($ddns_validation_args->{out}.$ddns_validation_args->{err});
my ($after_validation_args, $after_validation_args_err) =
    kea_read_component_config(kea_component('ddns'));
ok(!defined($after_validation_args_err),
   'DHCP-DDNS config reads after argument-order validation');
is($after_validation_args->{'ip-address'}, '127.0.0.3',
   'successful native validation saves DHCP-DDNS config');

my $failing_ddns_binary = "$confdir/kea-dhcp-ddns";
write_plain_file($failing_ddns_binary, <<'EOF');
#!/bin/sh
echo "intentional D2 validation failure" >&2
exit 1
EOF
chmod(0755, $failing_ddns_binary) or die "chmod $failing_ddns_binary: $!";
write_module_config({ ddns_path => $failing_ddns_binary });
my $ddns_validation_fail = run_cgi('save_ddns.cgi', {
    ip_address => '127.0.0.99',
});
like($ddns_validation_fail->{out}.$ddns_validation_fail->{err},
     qr/intentional D2 validation failure/,
     'DHCP-DDNS save reports native Kea validation errors');
my ($after_validation_fail, $after_validation_fail_err) =
    kea_read_component_config(kea_component('ddns'));
ok(!defined($after_validation_fail_err),
   'DHCP-DDNS config still reads after validation failure');
is($after_validation_fail->{'ip-address'}, '127.0.0.3',
   'failed native validation leaves existing DHCP-DDNS config unchanged');
write_module_config();

my $ddns_sender_save = run_cgi('save_options.cgi', {
    version                       => 4,
    interfaces                    => '*',
    lease_type                    => 'memfile',
    lease_lfc_interval            => 3600,
    control_socket_type           => 'unix',
    control_socket_name           => 'kea4-ctrl-socket',
    ddns_enable_updates           => 'true',
    ddns_server_ip                => '127.0.0.3',
    ddns_server_port              => 53002,
    ddns_sender_ip                => '127.0.0.1',
    ddns_sender_port              => 53003,
    ddns_max_queue_size           => 2048,
    ddns_ncr_protocol             => 'UDP',
    ddns_ncr_format               => 'JSON',
    'ddns-send-updates'           => 'true',
    'ddns-override-no-update'     => 'false',
    'ddns-override-client-update' => 'true',
    'ddns-update-on-renew'        => 'true',
    'ddns-replace-client-name'    => 'when-present',
    'ddns-generated-prefix'       => 'host',
    'ddns-qualifying-suffix'      => 'example.org.',
    'ddns-conflict-resolution-mode' => 'check-with-dhcid',
    'hostname-char-set'           => '[^A-Za-z0-9.-]',
    'hostname-char-replacement'   => '-',
});
is($ddns_sender_save->{status}, 0,
   'DHCPv4 DDNS sender settings save exits cleanly')
    or diag($ddns_sender_save->{out}.$ddns_sender_save->{err});
my ($saved_ddns_sender_root, $saved_ddns_sender_err) =
    kea_read_component_config(kea_dhcp_component(4));
ok(!defined($saved_ddns_sender_err),
   'DHCPv4 config reads after DDNS sender save');
is($saved_ddns_sender_root->{'dhcp-ddns'}->{'server-ip'}, '127.0.0.3',
   'DDNS sender save stores D2 server address');
is($saved_ddns_sender_root->{'dhcp-ddns'}->{'server-port'}, 53002,
   'DDNS sender save stores D2 server port as an integer');
is($saved_ddns_sender_root->{'dhcp-ddns'}->{'enable-updates'}, 1,
   'DDNS sender save stores enable-updates boolean');
is($saved_ddns_sender_root->{'dhcp-ddns'}->{'max-queue-size'}, 2048,
   'DDNS sender save stores max queue size');
is($saved_ddns_sender_root->{'ddns-send-updates'}, 1,
   'DDNS sender save stores update behavior booleans');
is($saved_ddns_sender_root->{'ddns-override-no-update'}, 0,
   'DDNS sender save stores false update behavior booleans');
is($saved_ddns_sender_root->{'ddns-replace-client-name'}, 'when-present',
   'DDNS sender save stores client-name replacement policy');
is($saved_ddns_sender_root->{'hostname-char-replacement'}, '-',
   'DDNS sender save stores hostname replacement character');

my $v6_ddns_sender_save = run_cgi('save_options.cgi', {
    version              => 6,
    interfaces           => '*',
    lease_type           => 'memfile',
    lease_lfc_interval   => 3600,
    control_socket_type  => 'unix',
    control_socket_name  => 'kea6-ctrl-socket',
    ddns_enable_updates  => 'true',
    ddns_server_ip       => '127.0.0.3',
    ddns_server_port     => 53002,
    ddns_ncr_protocol    => 'UDP',
    ddns_ncr_format      => 'JSON',
    'ddns-send-updates'  => 'true',
    'ddns-update-on-renew' => 'true',
});
is($v6_ddns_sender_save->{status}, 0,
   'DHCPv6 DDNS sender settings save exits cleanly')
    or diag($v6_ddns_sender_save->{out}.$v6_ddns_sender_save->{err});
my ($saved_v6_ddns_sender_root, $saved_v6_ddns_sender_err) =
    kea_read_component_config(kea_dhcp_component(6));
ok(!defined($saved_v6_ddns_sender_err),
   'DHCPv6 config reads after DDNS sender save');
is($saved_v6_ddns_sender_root->{'dhcp-ddns'}->{'server-ip'}, '127.0.0.3',
   'DHCPv6 DDNS sender save stores D2 server address');
is($saved_v6_ddns_sender_root->{'dhcp-ddns'}->{'enable-updates'}, 1,
   'DHCPv6 DDNS sender save stores enable-updates boolean');
is($saved_v6_ddns_sender_root->{'ddns-send-updates'}, 1,
   'DHCPv6 DDNS sender save stores DDNS behavior');

my ($password_c, $password_root, $password_data, $password_err) =
    kea_read_dhcp_config(4);
ok(!defined($password_err), 'DHCPv4 config reads before password preservation test');
$password_root->{'lease-database'}->{'password'} = 'oldsecret';
write_plain_file($dhcp4_conf, kea_encode_config($password_data));
my $storage_with_secret = cgi_ok('edit_options.cgi',
                                 { version => 4, mode => 'storage' },
                                 'DHCPv4 storage tab with existing secret');
unlike($storage_with_secret, qr/oldsecret/,
       'lease database editor does not print existing database passwords');
html_has($storage_with_secret, qr/Configured; leave blank to keep unchanged/,
         'lease database editor explains blank password preservation');
my $password_blank_save = run_cgi('save_options.cgi', {
    version            => 4,
    interfaces         => '*',
    lease_type         => 'memfile',
    lease_lfc_interval => 3600,
    lease_password     => '',
});
is($password_blank_save->{status}, 0,
   'DHCPv4 storage save with blank existing password exits cleanly')
    or diag($password_blank_save->{out}.$password_blank_save->{err});
my ($after_password_root, $after_password_err) =
    kea_read_component_config(kea_dhcp_component(4));
ok(!defined($after_password_err),
   'DHCPv4 config reads after blank password save');
is($after_password_root->{'lease-database'}->{'password'}, 'oldsecret',
   'blank database password keeps the existing secret');

my %subnet_modes = (
    general      => qr/Subnet details.*Shared network/s,
    pools        => qr/Pools.*Address pool.*Prefix delegation pools/s,
    reservations => qr/Identifier.*Identifier value.*Hostname/s,
    options      => qr/Common options/s,
    advanced     => qr/Interface.*Relay IP addresses/s,
);
foreach my $mode (sort keys %subnet_modes) {
    my $html = cgi_ok('edit_subnet.cgi',
                      { version => 6, new => 1, mode => $mode },
                      "DHCPv6 subnet $mode tab");
    html_has($html, $subnet_modes{$mode},
             "DHCPv6 subnet $mode tab renders expected controls");
    unlike($html, qr/Authoritative/,
           "DHCPv6 subnet $mode tab omits DHCPv4-only authoritative control")
        if ($mode eq 'advanced');
}
my $v4_subnet_general = cgi_ok('edit_subnet.cgi',
                               { version => 4, new => 1, mode => 'general' },
                               'DHCPv4 subnet general tab');
html_has($v4_subnet_general, qr/Calculated subnet mask/s,
         'DHCPv4 subnet form shows calculated mask as non-editable data');
html_has($v4_subnet_general, qr/field_subnet_id.*field_calculated_subnet_mask/s,
         'subnet general labels link to help');
my $subnet_pools = cgi_ok('edit_subnet.cgi',
                          { version => 6, new => 1, mode => 'pools' },
                          'DHCPv6 subnet pools tab wrapper check');
html_has($subnet_pools, qr/class=["'][^"']*\boption-data-table\b/s,
         'prefix delegation pools use option-data-table wrapper');
html_has($subnet_pools, qr/field_address_pool.*field_pd_prefix/s,
         'pool labels link to help');
my $subnet_reservations = cgi_ok('edit_subnet.cgi',
                                 { version => 6, new => 1, mode => 'reservations' },
                                 'DHCPv6 subnet reservations tab help check');
html_has($subnet_reservations,
         qr/field_reservation_identifier_type.*field_reservation_prefixes/s,
         'reservation labels link to help');
my $v4_subnet_advanced = cgi_ok('edit_subnet.cgi',
                                { version => 4, new => 1, mode => 'advanced' },
                                'DHCPv4 subnet advanced tab help check');
html_has($v4_subnet_advanced, qr/field_next_server.*field_server_hostname.*field_boot_file_name/s,
         'advanced subnet fields link to help files');
html_has($v4_subnet_advanced, qr/Authoritative/,
         'DHCPv4 subnet advanced tab includes authoritative control');
my $v6_global_advanced = cgi_ok('edit_options.cgi',
                                { version => 6, mode => 'advanced' },
                                'DHCPv6 global advanced tab');
unlike($v6_global_advanced, qr/Authoritative/,
       'DHCPv6 global advanced tab omits DHCPv4-only authoritative control');
my $v6_shared_advanced = cgi_ok('edit_shared.cgi',
                                { version => 6, new => 1, mode => 'advanced' },
                                'DHCPv6 shared advanced tab');
unlike($v6_shared_advanced, qr/Authoritative/,
       'DHCPv6 shared advanced tab omits DHCPv4-only authoritative control');
ok(-r "$module_dir/help/opt_dhcp_server_identifier.html",
   'DHCP server identifier help file exists');
ok(-r "$module_dir/help/field_interfaces.html" &&
   -r "$module_dir/help/field_logger_pattern.html" &&
   -r "$module_dir/help/field_reservation_identifier_type.html",
   'new structured field help files exist');
ok(-r "$module_dir/help/field_ddns_enable_updates.html" &&
   -r "$module_dir/help/field_ddns_server_ip.html" &&
   -r "$module_dir/help/field_hostname_char_replacement.html",
   'DHCP-DDNS sender help files exist');

my %shared_modes = (
    general  => qr/Shared network details.*Relay IP addresses/s,
    options  => qr/Common options/s,
    advanced => qr/Advanced shared network settings|Authoritative/s,
);
foreach my $mode (sort keys %shared_modes) {
    my $html = cgi_ok('edit_shared.cgi',
                      { version => 4, new => 1, mode => $mode },
                      "DHCPv4 shared $mode tab");
    html_has($html, $shared_modes{$mode},
             "DHCPv4 shared $mode tab renders expected controls");
    if ($mode eq 'general') {
        html_has($html, qr/field_shared_network_name.*field_description/s,
                 'shared-network general labels link to help');
    }
}

my $manual = cgi_ok('edit_text.cgi', {}, 'manual file editor');
html_has($manual, qr/\Q$api_password\E/,
         'manual file editor lists Control Agent password file');
unlike($manual, qr/Webmin saves changes from these settings pages/s,
       'manual file editor does not warn about comment loss');

my $acl_html = '';
{
    open(my $capture, ">", \$acl_html) or die "capture ACL HTML: $!";
    my $oldfh = select($capture);
    print ui_table_start('ACL', undef, 4);
    acl_security_form({ view => 1, edit => 0, apply => 1 });
    print ui_table_end();
    select($oldfh);
}
my @acl_full_width_rows = ($acl_html =~ /\bcolspan=['"]?3['"]?/g);
is(scalar(@acl_full_width_rows), 11,
   'ACL permissions render as full-width table rows');
unlike($acl_html, qr/name="view"/,
       'ACL form does not render a module-wide view switch');
html_has($acl_html,
	 qr/name="dhcp4".*name="dhcp6".*name="ddns".*name="services".*name="runtime".*name="edit4".*name="edit6".*name="editddns".*name="manual".*name="apply".*name="install"/s,
         'ACL form renders all Kea permission radios');
# Parser/UI helper contract checks. These are not full Kea validation, but they
# protect the Webmin-specific mapping between named fields and raw option-data.
my $opts = [
    { name => 'domain-name-servers', data => '192.0.2.1' },
    { code => 15, data => 'example.org' },
    { name => 'default-ip-ttl', data => '0xf0' },
    { name => 'subnet-mask', data => '255.255.255.0' },
];
is(kea_option_value($opts, 'domain-name', 4), 'example.org',
   'numeric DHCPv4 option code is readable through named common field');
is_deeply(kea_other_options($opts, 4),
          [ { name => 'default-ip-ttl', data => '0xf0' } ],
          'other option-data excludes common and Kea-managed options');

{
    local %in = (
        'opt_name_0' => '',
        'opt_code_0' => 12,
        'opt_data_0' => '2001:db8::1',
        'opt_space_0' => '',
    );
    my $parsed = kea_parse_other_option_rows([], 6, 'opt_');
    is_deeply($parsed, [ { code => 12, data => '2001:db8::1' } ],
              'numeric DHCPv6 option code 12 is accepted without duplication');
is(kea_option_value($parsed, 'unicast', 6), '2001:db8::1',
       'numeric DHCPv6 option code 12 maps back to the unicast field');
}

{
    local %in = (
        'log_name_0'       => 'kea-dhcp4',
        'log_severity_0'   => 'DEBUG',
        'log_debuglevel_0' => '50',
        'log_output_0'     => 'stdout',
        'log_pattern_0'    => '%-5p %m\n',
    );
    my $parsed = kea_parse_logger_rows([], 'log_');
    is($parsed->[0]->{'name'}, 'kea-dhcp4',
       'logger parser keeps the logger name');
    is($parsed->[0]->{'output-options'}->[0]->{'pattern'}, "%-5p %m\n",
       'logger parser converts visible newline escapes back to JSON values');
}

{
    local %in = (
        'fwd_name_0'    => 'example.net.',
        'fwd_key_0'     => 'ddns-key',
        'fwd_servers_0' => '192.0.2.53 192.0.2.54',
        'fwd_port_0'    => '53',
    );
    my $parsed = kea_parse_ddns_domain_rows([], 'fwd_');
    is($parsed->[0]->{'name'}, 'example.net.',
       'DDNS domain parser keeps the domain name');
    is_deeply([ map { $_->{'ip-address'} } @{$parsed->[0]->{'dns-servers'}} ],
              [ '192.0.2.53', '192.0.2.54' ],
              'DDNS domain parser stores multiple DNS servers');
    is($parsed->[0]->{'dns-servers'}->[0]->{'port'}, 53,
       'DDNS domain parser applies the DNS server port');
}

{
    local %in = (
        'fwd_name_0'    => 'default-port.example.',
        'fwd_servers_0' => '192.0.2.55',
        'fwd_port_0'    => '',
    );
    my $parsed = kea_parse_ddns_domain_rows([], 'fwd_');
    is($parsed->[0]->{'dns-servers'}->[0]->{'port'}, 53,
       'DDNS domain parser defaults blank server port to DNS port 53');
}

ok(kea_ddns_listener_loopback({ 'ip-address' => '127.0.0.2' }),
   'D2 listener helper treats all 127/8 addresses as loopback');
ok(kea_ddns_listener_non_default_loopback({ 'ip-address' => '127.0.0.2' }),
   'D2 listener helper flags non-default loopback addresses');
ok(!kea_ddns_listener_non_loopback({ 'ip-address' => '127.0.0.2' }),
   'D2 listener helper does not treat 127.0.0.2 as non-loopback');
ok(kea_ddns_listener_non_loopback({ 'ip-address' => '192.0.2.10' }),
   'D2 listener helper flags non-loopback listener addresses');

my $ddns_save = run_cgi('save_ddns.cgi', {
    ip_address              => '127.0.0.1',
    port                    => 53001,
    dns_server_timeout      => 500,
    ncr_protocol            => 'UDP',
    ncr_format              => 'JSON',
    control_socket_type     => 'unix',
    control_socket_name     => 'kea-ddns-ctrl-socket',
    fwd_name_0              => 'example.net.',
    fwd_key_0               => 'ddns-key',
    fwd_servers_0           => '192.0.2.53',
    fwd_port_0              => 53,
    rev_name_0              => '',
    key_name_0              => 'ddns-key',
    key_algorithm_0         => 'hmac-sha256',
    key_secret_0            => 'ZmFrZQ==',
    log_name_0              => 'kea-dhcp-ddns',
    log_severity_0          => 'INFO',
    log_debuglevel_0        => 0,
    log_output_0            => 'stdout',
    log_pattern_0           => '%-5p %m\n',
});
is($ddns_save->{status}, 0, 'DHCP-DDNS settings save exits cleanly')
    or diag($ddns_save->{err});
my ($saved_ddns, $saved_ddns_err) = kea_read_component_config(kea_component('ddns'));
ok(!defined($saved_ddns_err), 'saved DHCP-DDNS config reads back cleanly');
is($saved_ddns->{'forward-ddns'}->{'ddns-domains'}->[0]->{'name'},
   'example.net.',
   'saved DHCP-DDNS config preserves edited forward domain');
is($saved_ddns->{'dns-server-timeout'}, 500,
   'saved DHCP-DDNS config preserves DNS server timeout');
is($saved_ddns->{'ncr-protocol'}, 'UDP',
   'saved DHCP-DDNS config stores NCR protocol');
is($saved_ddns->{'ncr-format'}, 'JSON',
   'saved DHCP-DDNS config stores NCR format');

my $v6_authoritative_global_save = run_cgi('save_options.cgi', {
    version       => 6,
    authoritative => 'true',
});
is($v6_authoritative_global_save->{status}, 0,
   'DHCPv6 global save ignores stale authoritative submission')
    or diag($v6_authoritative_global_save->{err});
my ($saved_v6_global, $saved_v6_global_err) =
    kea_read_component_config(kea_dhcp_component(6));
ok(!defined($saved_v6_global_err), 'DHCPv6 global config reads after save');
ok(!exists($saved_v6_global->{'authoritative'}),
   'DHCPv6 global save does not write DHCPv4-only authoritative key');

my $v6_authoritative_shared_save = run_cgi('save_shared.cgi', {
    version       => 6,
    new           => 1,
    name          => 'v6-shared',
    authoritative => 'true',
});
is($v6_authoritative_shared_save->{status}, 0,
   'DHCPv6 shared-network save ignores stale authoritative submission')
    or diag($v6_authoritative_shared_save->{err});
my ($saved_v6_shared_root, $saved_v6_shared_err) =
    kea_read_component_config(kea_dhcp_component(6));
ok(!defined($saved_v6_shared_err), 'DHCPv6 shared-network config reads after save');
ok(!exists($saved_v6_shared_root->{'shared-networks'}->[0]->{'authoritative'}),
   'DHCPv6 shared-network save does not write DHCPv4-only authoritative key');

my $v6_authoritative_subnet_save = run_cgi('save_subnet.cgi', {
    version       => 6,
    new           => 1,
    id            => 42,
    subnet        => '2001:db8:42::/64',
    authoritative => 'true',
});
is($v6_authoritative_subnet_save->{status}, 0,
   'DHCPv6 subnet save ignores stale authoritative submission')
    or diag($v6_authoritative_subnet_save->{err});
my ($saved_v6_subnet_root, $saved_v6_subnet_err) =
    kea_read_component_config(kea_dhcp_component(6));
ok(!defined($saved_v6_subnet_err), 'DHCPv6 subnet config reads after save');
ok(!exists($saved_v6_subnet_root->{'subnet6'}->[0]->{'authoritative'}),
   'DHCPv6 subnet save does not write DHCPv4-only authoritative key');

{
    no warnings qw(redefine once);
    my $fake_dhcp4_binary = "$keadir/kea-dhcp4";
    write_plain_file($fake_dhcp4_binary, "#!/bin/sh\nexit 0\n");
    chmod(0755, $fake_dhcp4_binary) or die "chmod $fake_dhcp4_binary: $!";

    my ($seen_cmd, $seen_tmp, $tmp_existed, $tmp_mode);
    my @real_st = stat($dhcp4_conf);
    local $config{'dhcp4_path'} = $fake_dhcp4_binary;
    local *execute_command = sub {
        my ($cmd, $stdin, $out, $err) = @_;
        $seen_cmd = $cmd;
        my $unquoted = $cmd;
        $unquoted =~ s/\\(.)/$1/g;
        ($seen_tmp) = $unquoted =~ /\s-t\s+(\S+)/;
        $tmp_existed = defined($seen_tmp) && -e $seen_tmp ? 1 : 0;
        if ($tmp_existed) {
            my @tmp_st = stat($seen_tmp);
            $tmp_mode = $tmp_st[2] & 07777;
            }
        $$out = '';
        $$err = '';
        return 0;
    };

    my $test_err = kea_validate_component_json(
        kea_dhcp_component(4), "{ \"Dhcp4\": {} }\n");
    ok(!defined($test_err),
       'native validation succeeds when the test command exits cleanly');
    like($seen_cmd, qr/\s-t\s+\S+/,
         'native validation passes the temporary config to Kea test mode');
    like($seen_tmp, qr/^\Q$keadir\E\/kea-dhcp4-test-[a-f0-9]{6}\.conf$/,
         'native validation uses a visible Kea config-directory test file');
    ok($tmp_existed, 'native validation temp config exists during test command');
    is($tmp_mode, $real_st[2] & 07777,
       'native validation temp config copies real config permissions');
    ok(!-e $seen_tmp, 'native validation removes the temporary config');
}

# Exercise the write path with the same temporary configs used by the UI tests.
# This catches strict-mode filehandle regressions in Webmin's tempfile helpers.
my $save_err = kea_save_component_config(kea_dhcp_component(4), {
    Dhcp4 => {
        'interfaces-config' => { interfaces => [ '*' ] },
        subnet4 => [],
    },
});
ok(!defined($save_err), 'structured Kea config saves without an error');
my ($saved_root, $saved_err) = kea_read_component_config(kea_dhcp_component(4));
ok(!defined($saved_err), 'saved structured Kea config reads back cleanly');
is_deeply($saved_root->{'interfaces-config'}->{'interfaces'}, [ '*' ],
          'saved structured Kea config preserves edited data');

done_testing();
