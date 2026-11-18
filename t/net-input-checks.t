#!/usr/bin/perl
# Checks for interface names and values written to shell-sourced files.
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use Cwd qw(abs_path);
use File::Basename qw(dirname);

# Load only the checks, without detecting the network configuration
my $root = abs_path(dirname(__FILE__)."/..") or die "rootdir: $!";
open(my $lib, '<', "$root/net/net-lib.pl") or die "net-lib.pl: $!";
my $source = do { local $/; <$lib> };
close($lib);
require "$root/web-lib-funcs.pl";
our %text;
foreach my $sub (qw(valid_iface_name read_interface_config write_interface_config)) {
	$source =~ /(^sub \Q$sub\E\n\{.*?^\})/ms or die "Missing $sub";
	eval $1;
	die $@ if ($@);
	}

foreach my $ok ('eth0', 'enp0s3', 'br-1', 'wg0', 'eth0.100', 'eth0:1',
		'vlan_10', 'bond0') {
	ok(valid_iface_name($ok), "interface name $ok is accepted");
	}
foreach my $bad ('', '-eth0', 'eth0;id', 'eth0 eth1', '$(id)', "eth0\n",
		 '../eth0', 'eth0/1') {
	ok(!valid_iface_name($bad), "interface name '$bad' is rejected");
	}

my $tmp = tempdir(CLEANUP => 1);
my $file = "$tmp/ifcfg-eth0";
for my $name ("Sales & Support", "Owner's uplink", "R&D", 'Office #2',
	      'Cost $5', 'Uplink (primary)', 'Path "C:\Docs"', '') {
	write_interface_config($file, { NAME => $name, DEVICE => 'eth0' });
	my %config;
	read_interface_config($file, \%config);
	is($config{'NAME'}, $name, 'Webmin reads the original description');
	open(my $sh, '-|', 'sh', '-c', '. "$1"; printf %s "$NAME"', 'sh', $file)
		or die $!;
	my $got = do { local $/; <$sh> };
	ok(close($sh), 'shell can read the interface file');
	is($got, $name, 'shell reads the original description');
	}

{
	no warnings qw(once redefine);
	local *main::error = sub { die "Invalid description\n" };
	for my $bad ("first\nsecond", "first\0second") {
		ok(!eval { write_interface_config($file, { NAME => $bad }); 1 },
		   'a multiline or binary description is rejected before writing');
		}
	}

done_testing();
