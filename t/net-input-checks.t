#!/usr/bin/perl
# Checks for interface names and values written to shell-sourced files.
use strict;
use warnings;
use Test::More;
use Cwd qw(abs_path);
use File::Basename qw(dirname);

# Load only the checks, without detecting the network configuration
my $root = abs_path(dirname(__FILE__)."/..") or die "rootdir: $!";
open(my $lib, '<', "$root/net/net-lib.pl") or die "net-lib.pl: $!";
my $source = do { local $/; <$lib> };
close($lib);
foreach my $sub ('valid_iface_name', 'valid_env_value') {
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

foreach my $ok ('System eth0', 'Uplink (primary)', 'Office #2', 'a+b=c',
		'') {
	ok(valid_env_value($ok), "description '$ok' is accepted");
	}
foreach my $bad ('$(id>/tmp/p)', '`id`', 'a;b', 'a&b', 'a|b', 'a>b',
		 'a<b', 'a"b', "a'b", 'a\\b', "a\nb") {
	ok(!valid_env_value($bad), "description '$bad' is rejected");
	}

done_testing();
