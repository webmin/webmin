#!/usr/bin/perl
# Run with WEBMIN_NETPLAN_VM_TEST=1 on a Linux debug VM with Netplan installed.
use strict;
use warnings;
no warnings 'once';
use Test::More;
use File::Path qw(make_path);
use File::Temp qw(tempdir);
use FindBin;
use lib "$FindBin::Bin/../net";

plan skip_all => 'Set WEBMIN_NETPLAN_VM_TEST=1 on a Linux debug VM'
    unless ($ENV{'WEBMIN_NETPLAN_VM_TEST'} || '') eq '1';
$^O eq 'linux' or die 'Linux VM required';
require "$FindBin::Bin/../web-lib-funcs.pl";
require "$FindBin::Bin/../net/netplan-lib.pl";
local %main::gconfig = ();
local $main::readonly_mode_cache = 0;

# Load real address helpers without initializing the VM's Webmin configuration.
my $net_lib = main::read_file_contents("$FindBin::Bin/../net/net-lib.pl");
foreach my $name (qw(prefix_to_mask mask_to_prefix log2)) {
    my ($code) = $net_lib =~ /^(sub \Q$name\E\n\{.*?^\})/ms;
    $code or die "Cannot find $name";
    eval "no strict; $code";
    die $@ if $@;
}

# Keep realistic addresses, DNS, routes, and comments in the surviving port.
my $header = "network:\n  version: 2\n";
my $global = $header."  renderer: networkd\n";
my $ethernet = <<'YAML';
  ethernets:
    eth0:
      # Preserve the port's static settings.
      addresses: [192.0.2.10/24, '2001:db8::10/64']
      nameservers:
        addresses: [192.0.2.53]
        search: [example.test]
      routes:
        - to: default
          via: 192.0.2.1
    eth1:
      dhcp4: true
YAML
my $bridge0 = "    br0:\n      interfaces: [eth0]\n";
my $bridge1 = "    br1:\n      interfaces: [eth1]\n";
my $standalone = "    br0:\n      interfaces: []\n      dhcp4: true\n";
my $other_groups = <<'YAML';
  vlans:
    vlan10:
      id: 10
      link: eth0
  bonds:
    bond0:
      interfaces: [eth1]
      parameters:
        mode: active-backup
YAML
my $inline = "  ethernets: {eth0: {dhcp4: true}}\n";
my $bulk = $global."  ethernets: {}\n  bridges:\n".
    "    br0:\n      dhcp4: false\n    br1:\n      dhcp4: true\n";

# Each case supplies valid input, deletion order, and exact expected contents.
foreach my $case (
    ['shared bridge', $header.$ethernet."  bridges:\n".$bridge0,
        ['br0'], $header.$ethernet],
    ['remaining bridge', $header.$ethernet."  bridges:\n".$bridge0.$bridge1,
        ['br0'], $header.$ethernet."  bridges:\n".$bridge1],
    ['last Ethernet', $header."  ethernets:\n    eth0: {}\n",
        ['eth0'], undef],
    ['last bridge', $header."  bridges:\n".$standalone,
        ['br0'], undef],
    ['VLAN and bond settings', $header.$ethernet.$other_groups.
        "  bridges:\n".$standalone, ['br0'], $header.$ethernet.$other_groups],
    ['inline Ethernet mapping', $header.$inline."  bridges:\n".$bridge0,
        ['br0'], $header.$inline],
    ['bulk deletion preserves existing empty groups', $bulk, ['br1', 'br0'],
        $global."  ethernets: {}\n"],
    ['bulk deletion follows display order',
        $global."  ethernets:\n    eth0: {}\n  bridges:\n".$standalone,
        ['eth0', 'br0'], $global],
    ['virtual IPv4 address', $header."  ethernets:\n    eth0:\n".
        "      addresses: [192.0.2.10/24, 192.0.2.11/24]\n",
        ['eth0:0'], $header."  ethernets:\n    eth0:\n".
        "      addresses: ['192.0.2.10/24']\n"],
) {
    subtest $case->[0] => sub {
        # Generate only beneath this temporary root, without applying networking.
        my $root = tempdir(CLEANUP => 1);
        local $main::netplan_dir = "$root/etc/netplan";
        make_path($main::netplan_dir);
        my $file = "$main::netplan_dir/shared.yaml";
        my $control = "$main::netplan_dir/00-renderer.yaml";
        main::write_file_contents($file, $case->[1]);
        main::write_file_contents($control, $global);
        chmod(0600, $file, $control) == 2 or die "chmod: $!";
        is(system('netplan', 'generate', '--root-dir', $root), 0,
            'original configuration passes Netplan');

        # Match the UI's reuse of one interface list throughout bulk deletion.
        my @boot = main::boot_interfaces();
        foreach my $name (@{$case->[2]}) {
            my ($iface) = grep { $_->{'fullname'} eq $name } @boot;
            $iface or die "Fixture interface $name not found";
            main::delete_interface($iface);
        }
        if (defined($case->[3])) {
            # Surviving settings and comments must retain their exact contents.
            is(main::read_file_contents($file), $case->[3],
                'remaining configuration is unchanged');
        }
        else {
            # No interface or global setting remains in this file.
            ok(!-e $file, 'empty file is removed');
        }
        is(main::read_file_contents($control), $global,
            'another YAML file is untouched');
        is(system('netplan', 'generate', '--root-dir', $root), 0,
            'resulting configuration passes Netplan');
    };
}
done_testing();
