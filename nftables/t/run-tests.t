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

sub check_fields
{
    my ($name, $got, $expect) = @_;
    foreach my $k (sort keys %$expect) {
        is($got->{$k}, $expect->{$k}, "$name $k");
    }
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

my $ruleset = "$bindir/rulesets/basic.nft";
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

my $ruleset_prio = "$bindir/rulesets/firewalld-priority.nft";
my @tables_prio = get_nftables_save($ruleset_prio);
ok(@tables_prio == 1, 'firewalld priority table count');
my $fw_chain = $tables_prio[0]->{chains}->{filter_INPUT};
ok($fw_chain, 'firewalld priority chain present');
is($fw_chain->{type}, 'filter', 'firewalld priority chain type');
is($fw_chain->{hook}, 'input', 'firewalld priority chain hook');
is($fw_chain->{priority}, 'filter + 10', 'firewalld priority chain priority');
is($fw_chain->{policy}, 'accept', 'firewalld priority chain policy');
is(scalar @{$tables_prio[0]->{rules}}, 1,
   'firewalld priority chain definition is not parsed as a rule');

my @rules = @{$t->{rules}};
check_fields('ruleset r1', $rules[0], { iif => 'lo', action => 'accept' });
check_fields('ruleset r2', $rules[1], { saddr => '192.168.1.0/24', proto => 'tcp', dport => '22', action => 'accept', comment => 'ssh' });
check_fields('ruleset r3', $rules[2], { ct_state => 'established,related', action => 'accept' });

my $ruleset_sets = "$bindir/rulesets/sets.nft";
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

done_testing();
