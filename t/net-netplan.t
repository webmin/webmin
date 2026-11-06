#!/usr/bin/perl
# Exercise Netplan deletion using temporary files only, without host configuration.
use strict;
use warnings;
no warnings 'once';
use Test::More;
use File::Temp qw(tempdir);
use FindBin;
use lib "$FindBin::Bin/../net";
require "$FindBin::Bin/../web-lib-funcs.pl";
require "$FindBin::Bin/../net/netplan-lib.pl";
local %main::gconfig = ();
local $main::readonly_mode_cache = 0;
my $root = tempdir(CLEANUP => 1);
my $file = "$root/shared.yaml";
local $main::netplan_dir = $root;

# Empty detection must retain real interface entries and global settings.
foreach my $case (
    ["network:\n  version: 2\n  ethernets:\n  bridges:\n", 1, 'empty interface groups'],
    ["network:\n  version: 2\n  ethernets:\n    eth0: {}\n", 0, 'empty Ethernet definition'],
    ["network:\n  version: 2\n  bridges:\n    br1:\n      dhcp4: true\n", 0, 'another bridge'],
    ["network:\n  version: 2\n  renderer: networkd\n", 0, 'global renderer'],
    ["network:\n  version: 2\n  vlans:\n    vlan10:\n      id: 10\n      link: eth0\n", 0, 'VLAN settings']) {
    main::write_file_contents($file, $case->[0]);
    main::unflush_file_lines($file);
    is(main::is_yaml_empty($file), $case->[1], "$case->[2] handled correctly");
}

# Deleting the last bridge must retain its port and unrelated YAML byte for byte.
my $remaining = "network:\n  version: 2\n  ethernets:\n    eth0:\n      dhcp4: true\n".
    "    eth1:\n      dhcp4: false\n";
my $original = $remaining."  bridges:\n    br0:\n      interfaces: [eth0]\n";
main::write_file_contents($file, $original);
main::unflush_file_lines($file);
main::delete_interface((grep { $_->{'fullname'} eq 'br0' } main::boot_interfaces())[0]);
ok(-f $file, 'shared YAML survives bridge deletion');
is(main::read_file_contents($file), $remaining, 'empty group removed, Ethernet settings untouched');

# Removing one bridge must preserve the group and the remaining bridge.
my $second = "    br1:\n      interfaces: [eth1]\n";
main::write_file_contents($file, $original.$second);
main::unflush_file_lines($file);
main::delete_interface((grep { $_->{'fullname'} eq 'br0' } main::boot_interfaces())[0]);
is(main::read_file_contents($file), $remaining."  bridges:\n".$second,
    'another bridge and its group remain unchanged');

# A bridge-only file is removed once its last interface is gone.
main::write_file_contents($file, "network:\n  version: 2\n  bridges:\n    br0:\n      dhcp4: true\n");
main::unflush_file_lines($file);
main::delete_interface((grep { $_->{'fullname'} eq 'br0' } main::boot_interfaces())[0]);
ok(!-e $file, 'empty bridge-only file is removed');

# Bulk deletion reuses interface details after earlier deletions shift lines.
my $global = "network:\n  version: 2\n  renderer: networkd\n";
main::write_file_contents($file, $global."  ethernets: {}\n  bridges:\n".
    "    br0:\n      dhcp4: false\n    br1:\n      dhcp4: true\n");
main::unflush_file_lines($file);
my @boot = main::boot_interfaces();
foreach my $iface (@boot) {
    main::delete_interface($iface);
}
is(main::read_file_contents($file), $global."  ethernets: {}\n",
    'bulk deletion handles line shifts and preserves unrelated settings');
done_testing();
