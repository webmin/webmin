#!/usr/bin/perl
# Input checks for the IPv4 and IPv6 firewall modules.
use strict;
use warnings;
no warnings qw(once redefine);
use Test::More;
use Cwd qw(abs_path);
use File::Basename qw(dirname);
use File::Temp qw(tempdir);

my $root = abs_path(dirname(__FILE__)."/..") or die "rootdir: $!";
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
$ENV{'FOREIGN_MODULE_NAME'} = 'firewall6';
$ENV{'FOREIGN_ROOT_DIRECTORY'} = $root;

chdir("$root/firewall6") or die "chdir: $!";
require './firewall-lib.pl';
require './firewall6-lib.pl';

# Hostname lookups would need DNS, so only literal addresses are tested
*WebminCore::supports_ipv6 = sub { 0 };

# IPv6 sources and destinations accept what ip6tables accepts
foreach my $ok ('2001:db8::1', '2001:db8::/32', '2001:db8::/ffff:ffff::',
		'::ffff:192.0.2.1', '::ffff:192.0.2.0/120',
		'2001:db8::1,2001:db8::2', "2001:db8::1 2001:db8::/64\n::1") {
	ok(main::check_ipmask($ok), "IPv6 mask check accepts $ok");
	}
foreach my $bad ('192.0.2.1', '2001:db8::/129', '2001:db8::/',
		 '2001:db8::/ffff::/12', '::1;id', '::1/64"',
		 '2001:db8::/xyz') {
	ok(!main::check_ipmask($bad), "IPv6 mask check rejects $bad");
	}

# Extra parameters cannot set a target through any spelling iptables accepts
foreach my $bad ('-j ACCEPT', '--jump ACCEPT', '--jump=ACCEPT', '--ju ACCEPT',
		 '-g other', '--goto other', '--go other', '-fj ACCEPT',
		 '"-j" ACCEPT', '-"j" ACCEPT', '--log-prefix x -j ACCEPT') {
	ok(main::args_set_target($bad), "target option found in: $bad");
	}
foreach my $ok ('', '--log-prefix "web traffic"', '-m string --algo bm',
		'--gid-owner 100', '--state NEW') {
	ok(!main::args_set_target($ok), "no target option in: $ok");
	}

# Line breaks cannot add save file lines, and only extra parameters may
# carry quotes or backslashes
ok(main::check_rule_inputs({ 'cmt' => 'web server', 'args' => '--x "a b"',
			     'source' => "2001:db8::1\n2001:db8::2" }),
   'normal rule inputs are accepted');
ok(!main::check_rule_inputs({ 'cmt' => "x\n-A INPUT -j ACCEPT" }),
   'a line break in a comment is rejected');
ok(!main::check_rule_inputs({ 'args' => "x\nCOMMIT" }),
   'a line break in extra parameters is rejected');
ok(!main::check_rule_inputs({ 'cmt' => '"x" -j ACCEPT' }),
   'a double quote in a comment is rejected');
ok(!main::check_rule_inputs({ 'in' => 'eth0\\' }),
   'a backslash in an interface is rejected');

done_testing();
