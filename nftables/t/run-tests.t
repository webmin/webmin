#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use Cwd qw(abs_path);
use File::Temp qw(tempdir);

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
my $rootdir = abs_path("$bindir/../..") or die "rootdir: $!";

my $confdir = tempdir(CLEANUP => 1);
my $vardir = tempdir(CLEANUP => 1);
open(my $cfh, ">", "$confdir/config") or die "config: $!";
print $cfh "os_type=linux\nos_version=0\n";
close($cfh);
open(my $vfh, ">", "$confdir/var-path") or die "var-path: $!";
print $vfh "$vardir\n";
close($vfh);
$ENV{'WEBMIN_CONFIG'} = $confdir;
$ENV{'WEBMIN_VAR'} = $vardir;
$ENV{'FOREIGN_MODULE_NAME'} = 'nftables';
$ENV{'FOREIGN_ROOT_DIRECTORY'} = $rootdir;

chdir("$bindir/..") or die "chdir: $!";

require "$bindir/../nftables-lib.pl";
our %access;

{
    local %access = (quick => 1);
    ok(check_quick_acl('forward'), 'quick sub-acl defaults to allowed');
    $access{quick_forward} = 0;
    ok(!check_quick_acl('forward'), 'quick sub-acl can deny one action');
    $access{quick_forward} = 1;
    ok(check_quick_acl('forward'), 'quick sub-acl can allow one action');
    $access{quick} = 0;
    ok(!check_quick_acl('forward'), 'quick master acl denies sub-actions');
}

my $services_file = "$confdir/services";
open(my $sfh, ">", $services_file) or die "services: $!";
print $sfh "customsvc 4242/tcp custom-alias\n";
print $sfh "customsvc 4243/udp\n";
close($sfh);
is(get_etc_service_port('custom-alias', 'tcp', $services_file), 4242,
   'custom services alias lookup');
is(get_etc_service_port('customsvc', 'udp', $services_file), 4243,
   'custom services udp lookup');

my $sshd_config = "$confdir/sshd_config";
open(my $sshcfh, ">", $sshd_config) or die "sshd_config: $!";
print $sshcfh "Port 2223\n";
print $sshcfh "Port 2200\n";
print $sshcfh "ListenAddress 0.0.0.0:2022\n";
close($sshcfh);
mkdir "$confdir/sshd" or die "sshd confdir: $!";
open(my $sshmodfh, ">", "$confdir/sshd/config") or die "sshd module config: $!";
print $sshmodfh "sshd_path=/bin/true\n";
print $sshmodfh "sshd_config=$sshd_config\n";
close($sshmodfh);

sub check_fields
{
    my ($name, $got, $expect) = @_;
    foreach my $k (sort keys %$expect) {
        is($got->{$k}, $expect->{$k}, "$name $k");
    }
}

sub write_ruleset
{
    my ($dir, $name, $content) = @_;
    my $file = "$dir/$name";
    open(my $fh, ">", $file) or die "$name: $!";
    print $fh $content;
    close($fh);
    return $file;
}

my @cases = (
    {
        name => 'tcp dport accept',
        line => 'tcp dport 22 accept',
        expect => { proto => 'tcp', dport => '22', action => 'accept' },
    },
    {
        name => 'iif oif drop',
        line => 'iif "eth0" oif "eth1" drop',
        expect => { iif => 'eth0', oif => 'eth1', action => 'drop' },
    },
    {
        name => 'comment with quotes',
        line => 'tcp dport 80 accept comment "a \\"quote\\""',
        expect => { proto => 'tcp', dport => '80', action => 'accept', comment => 'a "quote"' },
    },
    {
        name => 'ct state',
        line => 'ct state established,related accept',
        expect => { ct_state => 'established,related', action => 'accept' },
    },
    {
        name => 'icmp type',
        line => 'icmp type echo-request accept',
        expect => { icmp_type => 'echo-request', action => 'accept' },
    },
    {
        name => 'limit log counter',
        line => 'tcp dport 22 limit rate 10/second burst 20 packets log prefix "ssh" level info counter accept',
        expect => {
            proto => 'tcp',
            dport => '22',
            limit_rate => '10/second',
            limit_burst => '20',
            log_prefix => 'ssh',
            log_level => 'info',
            counter => 1,
            action => 'accept',
        },
    },
    {
        name => 'unknown tokens preserved',
        line => 'tcp dport 22 meta skgid 1000 accept',
        expect => { proto => 'tcp', dport => '22', action => 'accept' },
        preserve => 'meta skgid 1000',
    },
    {
        name => 'redirect target',
        line => 'tcp dport 2023 redirect to :20022 comment "Webmin quick forward"',
        expect => {
            proto => 'tcp',
            dport => '2023',
            action => 'redirect',
            nat_port => '20022',
            comment => 'Webmin quick forward',
        },
    },
    {
        name => 'dnat target',
        line => 'tcp dport 8080 dnat ip to 192.0.2.10:80 comment "Webmin quick forward"',
        expect => {
            proto => 'tcp',
            dport => '8080',
            action => 'dnat',
            nat_family => 'ip',
            nat_addr => '192.0.2.10',
            nat_port => '80',
            comment => 'Webmin quick forward',
        },
    },
);

foreach my $c (@cases) {
    my $r = parse_rule_text($c->{line});
    ok($r && ref($r) eq 'HASH', "$c->{name} parse hash");
    check_fields($c->{name}, $r, $c->{expect});

    my $out = format_rule_text($r);
    ok($out =~ /\S/, "$c->{name} formatted non-empty");
    if ($c->{preserve}) {
        like($out, qr/\Q$c->{preserve}\E/, "$c->{name} preserves unknowns");
    }

    my $r2 = parse_rule_text($out);
    check_fields($c->{name}.' roundtrip', $r2, $c->{expect});
}

my $redirect_desc = describe_rule(parse_rule_text(
    'tcp dport 2026 redirect to :20026 comment "Webmin quick forward"'));
like($redirect_desc, qr/Redirect.*:20026.*Destination port 2026/,
     'redirect rule summary includes target port');
my $dnat_desc = describe_rule(parse_rule_text(
    'tcp dport 2024 dnat ip to 10.211.55.21:20024 comment "Webmin quick forward"'));
like($dnat_desc, qr/DNAT.*10\.211\.55\.21:20024.*Destination port 2024/,
     'dnat rule summary includes target address and port');
is(format_forward_target({ family => 'ip' }, '10.211.55.21', 'ip', '20024'),
   'dnat to 10.211.55.21:20024',
   'ip quick forward omits inet-only dnat family');

my $ruleset = write_ruleset($confdir, "basic.nft", <<'EOF');
table inet filter {
    chain input {
        type filter hook input priority 0; policy drop;
        iif "lo" accept
        ip saddr 192.168.1.0/24 tcp dport 22 accept comment "ssh"
        ct state established,related accept
    }
}
EOF
my @tables = get_nftables_save($ruleset);
ok(@tables == 1, 'ruleset table count');
my $t = $tables[0];
is($t->{family}, 'inet', 'ruleset family');
is($t->{name}, 'filter', 'ruleset name');
my $chain = $t->{chains}->{input};
ok($chain, 'input chain present');
is($chain->{type}, 'filter', 'chain type');
is($chain->{hook}, 'input', 'chain hook');
is($chain->{priority}, '0', 'chain priority');
is($chain->{policy}, 'drop', 'chain policy');

my $ruleset_prio = write_ruleset($confdir, "externally-managed-priority.nft", <<'EOF');
table inet externally_managed {
    flags owner,persist

    chain managed_INPUT {
        type filter hook input priority filter + 10; policy accept;
        ct state { established, related } accept
    }
}
EOF
my @tables_prio = get_nftables_save($ruleset_prio);
ok(@tables_prio == 1, 'externally managed priority table count');
is($tables_prio[0]->{flags}, 'owner,persist', 'externally managed table flags');
ok(table_is_externally_managed($tables_prio[0]),
   'table with owner,persist flags is externally managed');
is(active_table_status($tables_prio[0], []), 'external',
   'external active table status');
is(active_table_status({ family => 'inet', name => 'filter' }, [ $t ]), 'saved',
   'saved active table status');
is(active_table_status({ family => 'inet', name => 'loose' }, []), 'unsaved',
   'unsaved active table status');
my $managed_chain = $tables_prio[0]->{chains}->{managed_INPUT};
ok($managed_chain, 'externally managed priority chain present');
is($managed_chain->{type}, 'filter', 'externally managed priority chain type');
is($managed_chain->{hook}, 'input', 'externally managed priority chain hook');
is($managed_chain->{priority}, 'filter + 10',
   'externally managed symbolic priority preserved');
is($managed_chain->{policy}, 'accept',
   'externally managed priority chain policy');
is(scalar @{$tables_prio[0]->{rules}}, 1,
   'externally managed chain definition is not parsed as a rule');

my @rules = @{$t->{rules}};
check_fields('ruleset r1', $rules[0], { iif => 'lo', action => 'accept' });
check_fields('ruleset r2', $rules[1], { saddr => '192.168.1.0/24', proto => 'tcp', dport => '22', action => 'accept', comment => 'ssh' });
check_fields('ruleset r3', $rules[2], { ct_state => 'established,related', action => 'accept' });

my $ruleset_sets = write_ruleset($confdir, "sets.nft", <<'EOF');
table inet filter {
    set trusted_v4 {
        type ipv4_addr;
        flags interval;
        elements = { 192.168.1.0/24, 10.0.0.1 }
    }
    set web_ports {
        type inet_service;
        elements = {
            80,
            443
        }
    }
    chain input {
        type filter hook input priority 0; policy drop;
        ip saddr @trusted_v4 tcp dport @web_ports accept
    }
}
EOF
my @tables_sets = get_nftables_save($ruleset_sets);
ok(@tables_sets == 1, 'sets ruleset table count');
my $ts = $tables_sets[0];
ok($ts->{sets} && $ts->{sets}->{trusted_v4}, 'trusted_v4 set present');
is($ts->{sets}->{trusted_v4}->{type}, 'ipv4_addr', 'trusted_v4 type');
is($ts->{sets}->{trusted_v4}->{flags}, 'interval', 'trusted_v4 flags');
is_deeply($ts->{sets}->{trusted_v4}->{elements},
          [ '192.168.1.0/24', '10.0.0.1' ],
          'trusted_v4 elements');
ok($ts->{sets}->{web_ports}, 'web_ports set present');
is($ts->{sets}->{web_ports}->{type}, 'inet_service', 'web_ports type');
is_deeply($ts->{sets}->{web_ports}->{elements},
          [ '80', '443' ],
          'web_ports elements');

my $rset = $ts->{rules}->[0];
check_fields('set rule', $rset,
             { saddr => '@trusted_v4', proto => 'tcp', dport => '@web_ports', action => 'accept' });
my $rset_out = format_rule_text($rset);
like($rset_out, qr/\@trusted_v4/, 'set rule format preserves address set');
like($rset_out, qr/\@web_ports/, 'set rule format preserves port set');

ok(validate_chain_base('filter', 'input', '0', 'accept'),
   'chain base allows zero priority');
ok(!validate_chain_base('filter', 'input', undef, 'accept'),
   'chain base missing priority invalid');
ok(validate_chain_base(undef, undef, undef, undef),
   'chain base none set valid');

my $table_move = {
    rules => [
        { chain => 'input', index => 0, text => 'r0' },
        { chain => 'input', index => 1, text => 'r1' },
        { chain => 'forward', index => 2, text => 'r2' },
        { chain => 'input', index => 3, text => 'r3' },
    ],
};
ok(move_rule_in_chain($table_move, 'input', 1, 'down'),
   'move rule down returns true');
is($table_move->{rules}->[1]->{text}, 'r3', 'rule moved down in array');
is($table_move->{rules}->[3]->{text}, 'r1', 'rule swapped down in array');
is($table_move->{rules}->[1]->{index}, 1, 'moved rule index updated');
is($table_move->{rules}->[3]->{index}, 3, 'swapped rule index updated');

my $table_move2 = {
    rules => [
        { chain => 'input', index => 0, text => 'r0' },
        { chain => 'input', index => 1, text => 'r1' },
    ],
};
is(move_rule_in_chain($table_move2, 'input', 0, 'up'), 0,
   'top rule cannot move up');

my $quick_table = {
    family => 'inet',
    name => 'quick',
    chains => {
        input => { hook => 'input' },
    },
    rules => [
        { chain => 'input', index => 0, text => 'ct state established,related accept' },
    ],
};
is(add_quick_ip_rule($quick_table, '192.0.2.1', 'block'), undef,
   'quick block rule added');
is($quick_table->{rules}->[0]->{text},
   'ip saddr 192.0.2.1 drop comment "Webmin quick block"',
   'quick block inserted before normal input rules');
is(add_quick_ip_rule($quick_table, '192.0.2.1', 'allow'), undef,
   'quick allow rule added');
is($quick_table->{rules}->[0]->{text},
   'ip saddr 192.0.2.1 accept comment "Webmin quick allow"',
   'quick allow inserted before quick block rules');
like(add_quick_ip_rule($quick_table, '192.0.2.1', 'allow'), qr/exists/,
     'duplicate quick rule rejected');
my $quick_ip_table = {
    family => 'ip',
    name => 'quick',
    chains => { input => { hook => 'input' } },
    rules => [ ],
};
like(add_quick_ip_rule($quick_ip_table, '2001:db8::1/64', 'allow'),
     qr/cannot contain/, 'wrong address family rejected');

my $quick_port_table = {
    family => 'inet',
    name => 'quickports',
    chains => {
        input => { hook => 'input' },
    },
    sets => {
        allowed_tcp => {
            name => 'allowed_tcp',
            type => 'inet_service',
            elements => [ '22' ],
            raw_lines => [ ],
        },
    },
    rules => [
        {
            chain => 'input',
            index => 0,
            proto => 'tcp',
            dport => '@allowed_tcp',
            action => 'accept',
            text => 'tcp dport @allowed_tcp accept',
        },
    ],
};
is(add_quick_port_rule($quick_port_table, '8443', 'tcp'), undef,
   'quick port added to accepted set');
is_deeply($quick_port_table->{sets}->{allowed_tcp}->{elements},
          [ '22', '8443' ], 'quick port set extended');
like(add_quick_port_rule($quick_port_table, '8443', 'tcp'), qr/exists/,
     'duplicate quick port rejected');

my ($customsvc) = grep { $_->{id} eq 'customsvc' }
                  read_etc_service_defs($services_file);
ok($customsvc, '/etc/services service parsed');
is($customsvc->{id}, 'customsvc', '/etc/services service id');
like($customsvc->{label}, qr/customsvc \(4242 TCP; 4243 UDP\)/,
     '/etc/services service label includes ports and protocol');
is_deeply([ sort { $a cmp $b } quick_service_rules($customsvc) ],
          [ 'tcp dport 4242 accept',
            'udp dport 4243 accept' ],
          '/etc/services service rules generated');
my @service_matches = search_quick_services('customsvc', 5, $services_file);
ok(@service_matches, 'quick service search returns matches');
is($service_matches[0]->{id}, 'customsvc',
   'quick service search ranks exact service IDs first');
my @alias_service_matches = search_quick_services('custom-alias', 5, $services_file);
is($alias_service_matches[0]->{id}, 'customsvc',
   'quick service search matches /etc/services aliases');
is(quick_service_by_id('custom-alias', $services_file)->{id}, 'customsvc',
   'quick service lookup accepts /etc/services aliases');
my @empty_service_matches = search_quick_services('', 5, $services_file);
is(scalar(@empty_service_matches), 0,
   'empty quick service search returns no matches');

my $forward_table = {
    family => 'inet',
    name => 'forward',
    chains => {
        input => { type => 'filter', hook => 'input', priority => 0, policy => 'drop' },
        forward => { type => 'filter', hook => 'forward', priority => 0, policy => 'drop' },
    },
    sets => {},
    rules => [],
};
is(add_quick_forward_rule($forward_table, '8080', 'tcp', '80', '192.0.2.10'), undef,
   'quick forward added');
ok($forward_table->{chains}->{prerouting}, 'quick forward created prerouting chain');
is($forward_table->{chains}->{prerouting}->{type}, 'nat',
   'quick forward prerouting chain is nat');
ok(scalar(grep {
        $_->{chain} eq 'prerouting' &&
        $_->{text} eq 'tcp dport 8080 dnat ip to 192.0.2.10:80 comment "Webmin quick forward"'
    } @{$forward_table->{rules}}),
   'quick forward DNAT rule added');
ok(scalar(grep {
        $_->{chain} eq 'forward' &&
        $_->{text} eq 'ct state established,related accept comment "Webmin quick forward"'
    } @{$forward_table->{rules}}),
   'quick forward established rule added');
ok(scalar(grep {
        $_->{chain} eq 'forward' &&
        $_->{text} eq 'ip daddr 192.0.2.10 tcp dport 80 accept comment "Webmin quick forward"'
    } @{$forward_table->{rules}}),
   'quick forward destination accept added');

my $redirect_table = {
    family => 'inet',
    name => 'redirect',
    chains => {
        input => { type => 'filter', hook => 'input', priority => 0, policy => 'drop' },
        forward => { type => 'filter', hook => 'forward', priority => 0, policy => 'drop' },
    },
    sets => {},
    rules => [],
};
is(add_quick_forward_rule($redirect_table, '2023', 'tcp', '20022', ''), undef,
   'quick local redirect added');
my ($redirect_rule) = grep {
        $_->{chain} eq 'prerouting' &&
        $_->{text} eq 'tcp dport 2023 redirect to :20022 comment "Webmin quick forward"'
    } @{$redirect_table->{rules}};
ok($redirect_rule, 'quick local redirect rule added');
check_fields('quick local redirect rule', $redirect_rule,
             { proto => 'tcp', dport => '2023', action => 'redirect', nat_port => '20022' });

my %setup_services = map { $_->{id} => $_ } setup_services();
is($setup_services{ssh}->{port}, '2022, 2200, 2223',
   'ssh service uses configured sshd ports');
ok(scalar(grep { $_ eq 'tcp dport 2022 accept' }
          @{$setup_services{ssh}->{rules}}),
   'ssh service includes ListenAddress port');
ok(scalar(grep { $_ eq 'tcp dport 443 accept' }
          @{$setup_services{https}->{rules}}),
   'https service allows TCP');
ok(scalar(grep { $_ eq 'udp dport 443 accept' }
          @{$setup_services{https}->{rules}}),
   'https service allows HTTP/3 over UDP');

my $profile_table = create_profile_ruleset('profile_virtualmin', 'virtualmin', '*');
is($profile_table->{family}, 'inet', 'profile helper family');
is($profile_table->{name}, 'profile_virtualmin', 'profile helper table name');
ok($profile_table->{sets}->{profile_hosting_tcp_ports},
   'profile helper tcp port set');
is($profile_table->{sets}->{profile_hosting_tcp_ports}->{flags}, 'interval',
   'profile helper tcp port set interval flag');
is_deeply($profile_table->{sets}->{profile_hosting_udp_ports}->{elements},
          [ '53', '443' ], 'profile helper udp port set elements');
ok(scalar(grep { $_->{text} eq 'tcp dport @profile_hosting_tcp_ports accept' }
          @{$profile_table->{rules}}),
   'profile helper tcp set rule');
ok(scalar(grep { $_->{text} eq 'ip6 daddr fe80::/64 udp dport 546 accept' }
          @{$profile_table->{rules}}),
   'profile helper special dhcpv6 rule');
ok(scalar(grep { $_ eq '2022' }
          @{$profile_table->{sets}->{profile_hosting_tcp_ports}->{elements}}),
   'profile helper includes dynamic ssh port');

# The saved configuration is now the system's own nftables file, so re-writing
# it must not discard anything the module does not model
my $sysfile = write_ruleset($confdir, 'system.nft', <<'EOF');
#!/usr/sbin/nft -f
# system firewall

flush ruleset

define lan = 192.168.0.0/24

table inet filter {
	set trusted {
		type ipv4_addr
		flags interval
		elements = { 10.0.0.0/8 }
	}

	map porttoip {
		type inet_service : ipv4_addr
		elements = { 80 : 10.0.0.1 }
	}

	counter http_hits {
	}

	chain input {
		type filter hook input priority 0; policy drop;
		tcp dport 22 accept
	}

	chain output {
		type filter hook output priority 0; policy accept;
	}
}

table ip nat {
	chain prerouting {
		type nat hook prerouting priority -100; policy accept;
	}
}

include "/etc/nftables.d/*.nft"

define wan = eth0

table inet extra {
	comment "hand written"

	chain forward {
		type filter hook forward priority 0; policy drop;
	}
}

# trailing note
include "/etc/nftables.d/late.nft"
EOF

my @systables = get_nftables_save($sysfile);
is(scalar(@systables), 3, 'system ruleset table count');
is(scalar(@{$systables[0]->{raw_blocks} || []}), 2,
   'unmodelled table objects are captured');
ok(exists($systables[0]->{chains}->{output}),
   'chain following an unmodelled object is still parsed');
is(scalar(@{$systables[0]->{rules}}), 1,
   'unmodelled objects are not parsed as rules');

my ($pre, $post) = get_nftables_extras($sysfile);
like($pre, qr/^\#\!\/usr\/sbin\/nft -f/, 'shebang kept ahead of the tables');
like($pre, qr/flush ruleset/, 'flush ruleset kept ahead of the tables');
like($pre, qr/define lan = /, 'defines kept ahead of the tables');
like($pre, qr/include "\/etc\/nftables\.d\/\*\.nft"/,
     'include between tables kept ahead of them');
like($post, qr/include "\/etc\/nftables\.d\/late\.nft"/,
     'trailing include kept after the tables');

my $rewritten = $pre.dump_nftables_save(@systables).$post;
like($rewritten, qr/map porttoip \{/, 'map survives a re-write');
like($rewritten, qr/counter http_hits \{/, 'named counter survives a re-write');
like($rewritten, qr/table ip nat \{/, 'second table survives a re-write');
like($rewritten, qr/comment "hand written"/, 'table comment survives a re-write');
is(scalar(() = $rewritten =~ /define wan = eth0/g), 1,
   'content between tables is kept exactly once');
like($pre, qr/define wan = eth0/, 'content between tables is kept ahead of them');

is_deeply([ map { $_->[0] }
            sort { $a->[1] <=> $b->[1] }
            map { [ $_, $systables[0]->{chains}->{$_}->{order} ] }
            keys %{$systables[0]->{chains}} ],
          [ 'input', 'output' ], 'chain order in the file is recorded');
like($rewritten, qr/chain input \{.*chain output \{/s,
     'chains are written back in the order they were read');

my $twicefile = write_ruleset($confdir, 'twice.nft', $rewritten);
my @twice = get_nftables_save($twicefile);
my ($tpre, $tpost) = get_nftables_extras($twicefile);
is($tpre.dump_nftables_save(@twice).$tpost, $rewritten,
   're-writing an already written file changes nothing');

# A file with no tables at all, such as a stock /etc/sysconfig/nftables.conf,
# keeps its comments and takes new tables at the end
my $emptyfile = write_ruleset($confdir, 'empty.nft', <<'EOF');
# Uncomment the include statement here to load the default config sample
#include "/etc/nftables/main.nft"
EOF
my ($epre, $epost) = get_nftables_extras($emptyfile);
like($epre, qr/Uncomment the include statement/,
     'comment-only file is kept ahead of new tables');
is($epost, '', 'comment-only file leaves nothing trailing');

our ($module_config_directory, $nftables_rules_file_cache);

# A ruleset spread over a main file and the files it includes has to be read
# from, and written back to, the file each table actually lives in
my $incdir = "$confdir/nftables.d";
mkdir($incdir);
my $incmain = write_ruleset($confdir, 'main.nft', <<'EOF');
#!/usr/sbin/nft -f
flush ruleset

define lan = 192.168.0.0/24

include "nftables.d/*.nft"

table inet main_table {
	chain input {
		type filter hook input priority 0; policy drop;
	}
}
EOF
write_ruleset($incdir, '10-web.nft', <<'EOF');
# web rules
table inet web {
	chain input {
		type filter hook input priority 10; policy accept;
		tcp dport 80 accept
	}
}
EOF
# Deliberately non-canonical spacing, so that a needless re-write would show
write_ruleset($incdir, '20-mail.nft', <<'EOF');
table inet mail {
      chain input {
            type filter hook input priority 20; policy accept;
            tcp dport 25 accept
      }
}
EOF

is_deeply([ nftables_include_files($incmain) ],
          [ "$incdir/10-web.nft", "$incdir/20-mail.nft" ],
          'relative include glob is expanded in order');

{
    local $nftables_rules_file_cache = $incmain;
    my @inctables = get_nftables_save();
    is_deeply([ map { $_->{name} } @inctables ],
              [ 'main_table', 'web', 'mail' ],
              'tables are read from the main file and its includes');
    is($inctables[0]->{file}, $incmain, 'main table is tagged with its file');
    is($inctables[1]->{file}, "$incdir/10-web.nft",
       'included table is tagged with the file it came from');
    is_deeply([ get_nftables_config_files() ],
              [ $incmain, "$incdir/10-web.nft", "$incdir/20-mail.nft" ],
              'the manual editor offers exactly the files that are loaded');

    # An included table is saved, so it must not be offered for import
    is(active_table_status({ family => 'inet', name => 'web' }, \@inctables),
       'saved', 'a table from an included file counts as saved');

    my $main_before = read_file_contents($incmain);
    my $mail_before = read_file_contents("$incdir/20-mail.nft");

    # Editing a table in an included file writes it back there
    my ($web) = grep { $_->{name} eq 'web' } @inctables;
    push(@{$web->{rules}}, {'text' => 'tcp dport 443 accept',
                            'chain' => 'input', 'index' => 99});
    write_configuration(@inctables);
    like(read_file_contents("$incdir/10-web.nft"), qr/tcp dport 443 accept/,
         'edit lands in the included file');
    unlike(read_file_contents($incmain), qr/table inet web/,
           'edit is not copied into the main file');
    is(read_file_contents($incmain), $main_before,
       'the main file is left alone');
    is(read_file_contents("$incdir/20-mail.nft"), $mail_before,
       'an untouched included file is not re-written');

    # Deleting it empties that file without disturbing the others
    my @keep = grep { $_->{name} ne 'web' } get_nftables_save();
    write_configuration(@keep);
    unlike(read_file_contents("$incdir/10-web.nft"), qr/table\s/,
           'deleted table is removed from its own file');
    like(read_file_contents("$incdir/10-web.nft"), qr/# web rules/,
         'the emptied file keeps its own comments');
    is(read_file_contents($incmain), $main_before,
       'deleting from an include leaves the main file alone');
    is_deeply([ map { $_->{name} } get_nftables_save() ],
              [ 'main_table', 'mail' ], 'the deleted table is gone');
}

# An include loop must not send the parser into a spin
my $loop_a = write_ruleset($confdir, 'loop-a.nft', "include \"loop-b.nft\"\n");
write_ruleset($confdir, 'loop-b.nft', "include \"loop-a.nft\"\n");
is_deeply([ nftables_include_files($loop_a) ],
          [ "$confdir/loop-b.nft", "$confdir/loop-a.nft" ],
          'an include loop terminates');

# Upgrades have to move rules out of the module's old private file, or the
# firewall silently disappears once the private boot action is gone
mkdir($module_config_directory) if (!-d $module_config_directory);
my $legacy = write_ruleset($module_config_directory, 'rules.conf', <<'EOF');
# This file was auto-generated by the module.
# Manual changes may be overwritten.

table inet webmin {
	chain input {
		type filter hook input priority 0; policy drop;
		tcp dport 10000 accept
	}
}
EOF
my $target = write_ruleset($confdir, 'migrate-target.nft', <<'EOF');
# Uncomment the include statement here to load the default config sample
#include "/etc/nftables/main.nft"
EOF
{
    local $nftables_rules_file_cache = $target;
    is(migrate_legacy_nftables_config(), 1, 'legacy table is migrated');
    ok(!-e $legacy, 'legacy rules file is moved aside');
    ok(-e $legacy.'.migrated', 'legacy rules file is kept as a backup');
    my @moved = get_nftables_save($target);
    is(scalar(@moved), 1, 'migrated table lands in the system file');
    is($moved[0]->{name}, 'webmin', 'migrated table keeps its name');
    like(read_file_contents($target), qr/Uncomment the include statement/,
         'migration keeps the system file comments');
    is(migrate_legacy_nftables_config(), 0, 'migration only runs once');
}

done_testing();
