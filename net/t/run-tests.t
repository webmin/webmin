#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use Cwd qw(abs_path);
use File::Basename qw(dirname);
use File::Path qw(make_path);
use File::Temp qw(tempdir);

my $root = abs_path(dirname(__FILE__)."/../..") or die "rootdir: $!";
my $tmp = tempdir(CLEANUP => 1);
my %file_cache;
my @commands;
my %command_status;
my %command_output;

sub write_text
{
my ($file, $text) = @_;
open(my $fh, ">", $file) || die "write $file: $!";
print $fh $text;
close($fh) || die "close $file: $!";
delete($file_cache{$file});
}

sub read_text
{
my ($file) = @_;
open(my $fh, "<", $file) || die "read $file: $!";
local $/ = undef;
my $text = <$fh>;
close($fh) || die "close $file: $!";
return $text;
}

sub read_file_lines
{
my ($file) = @_;
if (!exists($file_cache{$file})) {
	open(my $fh, "<", $file) || die "read_file_lines $file: $!";
	my @lines = <$fh>;
	close($fh) || die "close $file: $!";
	chomp(@lines);
	$file_cache{$file} = \@lines;
	}
return $file_cache{$file};
}

sub flush_file_lines
{
my ($file) = @_;
open(my $fh, ">", $file) || die "flush $file: $!";
foreach my $line (@{$file_cache{$file}}) {
	print $fh $line, "\n";
	}
close($fh) || die "close $file: $!";
}

sub lock_file { return 1; }
sub unlock_file { return 1; }
sub error { die join("", @_), "\n"; }
sub unflush_file_lines { delete($file_cache{$_[0]}); }
sub has_command { return $_[0] eq "netplan" ? "/usr/sbin/netplan" : undef; }
sub execute_command_logged
{
my ($cmd, undef, $stdout, $stderr) = @_;
push(@commands, $cmd);
my $out = $command_output{$cmd} || "";
$$stdout = $out if (ref($stdout));
$$stderr = $out if (ref($stderr) && $stderr ne $stdout);
return $command_status{$cmd} || 0;
}
sub backquote_logged
{
my ($cmd) = @_;
push(@commands, $cmd);
$? = $command_status{$cmd} || 0;
return $command_output{$cmd} || "";
}
sub check_ipaddress { return $_[0] =~ /^\d+\.\d+\.\d+\.\d+$/; }
sub check_ip6address { return $_[0] =~ /:/; }
sub check_ipaddress_any { return &check_ipaddress($_[0]) || &check_ip6address($_[0]); }
sub mask_to_prefix { return $_[0] eq "255.255.255.0" ? 24 : $_[0]; }
sub prefix_to_mask { return $_[0] == 24 ? "255.255.255.0" : $_[0]; }
sub indexof
{
my ($needle, @haystack) = @_;
for(my $i=0; $i<@haystack; $i++) {
	return $i if ($haystack[$i] eq $needle);
	}
return -1;
}

unshift(@INC, "$root/net", $root);
do "$root/net/net-detect.pl" || die "net-detect.pl: $@ $!";

my $detect_root = tempdir(CLEANUP => 1);
my $detect_netplan = "$detect_root/netplan";
my $detect_no_netplan = "$detect_root/no-netplan";
my $detect_nm = "$detect_root/NetworkManager/system-connections";
my $detect_nm_empty = "$detect_root/NetworkManager-empty/system-connections";
my $detect_ifupdown = "$detect_root/interfaces";
my $detect_ifupdown_empty = "$detect_root/interfaces-empty";
my $detect_ifupdown_dir = "$detect_root/interfaces.d";
my $detect_dhcpcd = "$detect_root/dhcpcd.conf";
make_path($detect_netplan, $detect_nm, $detect_nm_empty);
write_text("$detect_nm/eth0.nmconnection", "");
make_path($detect_ifupdown_dir);
write_text($detect_ifupdown, "source $detect_ifupdown_dir/*\n");
write_text($detect_ifupdown_empty, "# empty\n");
write_text($detect_dhcpcd, "# default dhcpcd configuration\nhostname\n");

is(main::net_auto_backend("debian-linux", $detect_netplan, $detect_nm_empty),
   "netplan", "Debian uses Netplan when the config directory exists");
is(main::net_auto_backend("debian-linux", $detect_no_netplan, $detect_nm),
   "nm", "Debian uses NetworkManager when only nmconnection files exist");
is(main::net_auto_backend("redhat-linux", $detect_no_netplan, $detect_nm),
   "nm", "Red Hat still uses NetworkManager when nmconnection files exist");
write_text("$detect_netplan/50-cloud-init.yaml", "");
is(main::net_auto_backend("debian-linux", $detect_netplan, $detect_nm),
   "netplan", "Debian prefers Netplan over NetworkManager when YAML exists");
unlink("$detect_netplan/50-cloud-init.yaml");
is(main::net_auto_backend("debian-linux", $detect_no_netplan, $detect_nm_empty,
			  $detect_ifupdown_empty, $detect_dhcpcd, 0),
   undef, "Debian falls back when no Netplan or NetworkManager config exists");
is(main::net_auto_backend("debian-linux", $detect_no_netplan, $detect_nm_empty,
			  $detect_ifupdown_empty, $detect_dhcpcd, 0),
   undef, "Debian does not use inactive default dhcpcd config");
is(main::net_auto_backend("debian-linux", $detect_no_netplan, $detect_nm_empty,
			  $detect_ifupdown_empty, $detect_dhcpcd, 1),
   "dhcpcd", "Debian uses active dhcpcd service with default config");
write_text($detect_dhcpcd, "interface eth0\n");
is(main::net_auto_backend("debian-linux", $detect_no_netplan, $detect_nm_empty,
			  $detect_ifupdown_empty, $detect_dhcpcd, 0),
   "dhcpcd", "Debian uses dhcpcd only as a final configured backend");
write_text($detect_ifupdown_empty, "auto lo\niface lo inet loopback\n");
is(main::net_auto_backend("debian-linux", $detect_no_netplan, $detect_nm_empty,
			  $detect_ifupdown_empty, $detect_dhcpcd),
   "dhcpcd", "Debian loopback-only ifupdown config does not block dhcpcd");
write_text("$detect_ifupdown_dir/eth0", "iface eth0 inet dhcp\n");
is(main::net_auto_backend("debian-linux", $detect_no_netplan, $detect_nm_empty,
			  $detect_ifupdown, $detect_dhcpcd),
   undef, "Debian does not prefer dhcpcd over ifupdown iface stanzas");
write_text("$detect_ifupdown_dir/eth0", "iface eth0 inet dhcp # uplink\n");
is(main::net_auto_backend("debian-linux", $detect_no_netplan, $detect_nm_empty,
			  $detect_ifupdown, $detect_dhcpcd),
   undef, "Debian ifupdown detection tolerates inline iface comments");

do "$root/net/netplan-lib.pl" || die "netplan-lib.pl: $@ $!";

{
	no warnings 'once';
	$main::netplan_dir = $tmp;
}

is(main::linux_nsswitch_hosts_line("hosts:          files dns\n",
				   "files dns"),
   "hosts:          files dns\n",
   "Linux DNS save preserves nsswitch hosts spacing");
is(main::linux_nsswitch_hosts_line("hosts:\tfiles dns # local policy\n",
				   "files mdns4 dns"),
   "hosts:\tfiles mdns4 dns # local policy\n",
   "Linux DNS save preserves nsswitch hosts comments");

my $netplan = "$tmp/50-cloud-init.yaml";
write_text($netplan, <<'YAML');
network:
  version: 2
  ethernets:
    eth0:
      dhcp4: true
      nameservers:
        addresses:
          - 1.1.1.1
        search:
          - example.com
    eth1:
      dhcp4: true
YAML

my @boot = main::boot_interfaces();
is(scalar(grep { !defined($_->{'virtual'}) || $_->{'virtual'} eq '' } @boot),
   2, "parsed two boot interfaces");
my ($eth0) = grep { $_->{'fullname'} eq "eth0" } @boot;
$eth0->{'nameserver'} = [ "127.0.0.1", "2001:4860:4860::8888" ];
$eth0->{'search'} = [ "example.com" ];
main::save_interface($eth0, \@boot);

my $saved = read_text($netplan);
like($saved, qr/^    eth0:\n      dhcp4: true\n      nameservers:\n        addresses: \[127\.0\.0\.1, '2001:4860:4860::8888'\]\n        search: \[example\.com\]/m,
     "save_interface preserves existing two-space Netplan hierarchy");
like($saved, qr/^    eth1:\n      dhcp4: true/m,
     "untouched sibling interface keeps matching indentation");
unlike($saved, qr/^        eth0:/m,
       "rewritten interface is not moved to an eight-space sibling indent");

write_text($netplan, <<'YAML');
network:
  version: 2
  ethernets:
    eth0:
      dhcp4: true
      nameservers:
        addresses:
          - 1.1.1.1
    eth1:
      dhcp4: true
YAML
@boot = main::boot_interfaces();
my ($need_apply, $generated_resolv) =
	main::os_save_dns_config({ 'nameserver' => [ "127.0.0.1" ],
				   'domain' => [ "example.com" ] });
ok($need_apply, "DNS changes request a netplan apply");
ok($generated_resolv, "Netplan DNS save reports resolv.conf as generated");
$saved = read_text($netplan);
like($saved, qr/^    eth0:\n      dhcp4: true\n      nameservers:\n        addresses: \[127\.0\.0\.1\]\n        search: \[example\.com\]/m,
     "os_save_dns_config updates existing nameservers block");
unlike($saved, qr/eth1:\n(?:.*\n)*?\s+nameservers:/,
       "os_save_dns_config does not add nameservers to every interface");

@commands = ( );
%command_status = (
	"(cd / && /usr/sbin/netplan generate)" => 1,
	);
%command_output = (
	"(cd / && /usr/sbin/netplan generate)" => "bad yaml\n",
	);
is(main::apply_network(), "bad yaml\n",
   "apply_network returns validation errors");
is_deeply(\@commands, [ "(cd / && /usr/sbin/netplan generate)" ],
	  "apply_network skips apply when generate fails");

@commands = ( );
%command_status = ( );
%command_output = ( );
is(main::apply_network(), undef, "apply_network applies after validation");
is_deeply(\@commands,
	  [ "(cd / && /usr/sbin/netplan generate)",
	    "(cd / && /usr/sbin/netplan apply)" ],
	  "apply_network validates before applying");

do "$root/net/nm-lib.pl" || die "nm-lib.pl: $@ $!";
my $nmfile = "$tmp/eth0.nmconnection";
write_text($nmfile, <<'NM');
[connection]
id=eth0
uuid=11111111-2222-3333-4444-555555555555
type=ethernet
interface-name=eth0

[ipv4]
method=auto

[ipv6]
method=disabled
NM
my $nmcfg = main::read_nm_config($nmfile);
my $nmiface = {
	'name' => 'eth0',
	'fullname' => 'eth0',
	'file' => $nmfile,
	'cfg' => $nmcfg,
	'edit' => 1,
	'up' => 1,
	'dhcp' => 1,
	'address6' => [ ],
	'netmask6' => [ ],
	'nameserver' => [ "2001:4860:4860::8888" ],
	};
@commands = ( );
main::save_interface($nmiface, [ $nmiface ]);
like(join("\n", @commands), qr/ipv6\.dns/,
     "NetworkManager save_interface writes IPv6 nameservers");

do "$root/net/dhcpcd-lib.pl" || die "dhcpcd-lib.pl: $@ $!";
my $dhcpcd = "$tmp/dhcpcd.conf";
write_text($dhcpcd, <<'DHCPCD');
# global option
hostname

interface eth0
static ip_address=192.168.1.10/24
static routers=192.168.1.1
static routes=10.10.0.0/16 192.168.1.254 10.20.30.0/24 192.168.1.253
static domain_name_servers=1.1.1.1 2001:4860:4860::8888
static domain_search=example.com
static ip6_address=2001:db8::10/64
mtu 1400
noipv6rs

interface wlan0
# DHCP by default
DHCPCD

{
	no warnings 'once';
	$main::dhcpcd_config = $dhcpcd;
	$main::dhcpcd_synthesize_implicit = 0;
}

@boot = main::boot_interfaces();
is(scalar(grep { $_->{'virtual'} eq '' } @boot), 2,
   "dhcpcd parses two real interfaces");
my ($dh0) = grep { $_->{'fullname'} eq "eth0" } @boot;
is($dh0->{'address'}, "192.168.1.10", "dhcpcd parses static IPv4");
is($dh0->{'netmask'}, "255.255.255.0", "dhcpcd parses IPv4 prefix");
is($dh0->{'gateway'}, "192.168.1.1", "dhcpcd parses router");
is_deeply($dh0->{'routes'},
	  [ "10.10.0.0/16,192.168.1.254",
	    "10.20.30.0/24,192.168.1.253" ],
	  "dhcpcd parses static routes");
is_deeply($dh0->{'nameserver'},
	  [ "1.1.1.1", "2001:4860:4860::8888" ],
	  "dhcpcd parses nameservers");
is_deeply($dh0->{'address6'}, [ "2001:db8::10" ],
	  "dhcpcd parses static IPv6");
my ($wlan0) = grep { $_->{'fullname'} eq "wlan0" } @boot;
ok($wlan0->{'dhcp'}, "dhcpcd treats no static address as DHCP");

$dh0->{'address'} = "192.168.1.20";
$dh0->{'gateway'} = "192.168.1.254";
$dh0->{'routes'} = [ "172.16.0.0/12,192.168.1.253" ];
$dh0->{'nameserver'} = [ "9.9.9.9" ];
$dh0->{'search'} = [ "example.net" ];
main::save_interface($dh0, \@boot);
$saved = read_text($dhcpcd);
like($saved, qr/interface eth0\nnoipv6rs\nstatic ip_address=192\.168\.1\.20\/24\nstatic routers=192\.168\.1\.254\nstatic routes=172\.16\.0\.0\/12 192\.168\.1\.253\nstatic domain_name_servers=9\.9\.9\.9\nstatic domain_search=example\.net\nstatic ip6_address=2001:db8::10\/64\nmtu 1400/s,
     "dhcpcd save_interface rewrites managed values and preserves extras");
like($saved, qr/interface wlan0\n# DHCP by default/s,
     "dhcpcd save_interface preserves sibling DHCP block");

my ($dhwlan0) = grep { $_->{'fullname'} eq "wlan0" } main::boot_interfaces();
push(@boot, { 'name' => 'wlan0',
	      'fullname' => 'wlan0:0',
	      'virtual' => 0,
	      'address' => '192.168.2.10',
	      'netmask' => '255.255.255.0' });
main::save_interface($dhwlan0, \@boot);
$saved = read_text($dhcpcd);
like($saved, qr/interface wlan0\nstatic ip_address=192\.168\.2\.10\/24/s,
     "dhcpcd writes virtual static address for DHCP parent interface");

write_text($dhcpcd, <<'DHCPCD');
interface enp0s5
static ip_address=10.211.55.20/24
static domain_name_servers=1.1.1.1 8.8.8.8
DHCPCD
my ($dhneed, $dhgenerated) = main::os_save_dns_config(
	{ 'nameserver' => [ "1.1.1.1", "8.8.1.1" ],
	  'domain' => [ "example.test" ] });
ok($dhneed, "dhcpcd DNS save requests dhcpcd apply");
ok($dhgenerated, "dhcpcd DNS save reports resolv.conf as generated");
$saved = read_text($dhcpcd);
like($saved, qr/static domain_name_servers=1\.1\.1\.1 8\.8\.1\.1\nstatic domain_search=example\.test/,
     "dhcpcd DNS save updates interface DNS settings");

@commands = ( );
($dhneed, $dhgenerated) = main::os_save_dns_config(
	{ 'nameserver' => [ "1.1.1.1", "8.8.1.1" ],
	  'domain' => [ "example.test" ] });
ok(!$dhneed, "dhcpcd DNS save skips apply when unchanged");
ok($dhgenerated, "dhcpcd unchanged DNS still suppresses resolv.conf rewrite");
is_deeply(\@commands, [ ], "dhcpcd unchanged DNS does not rewrite config");

write_text($dhcpcd, <<'DHCPCD');
# default dhcpcd configuration
hostname
DHCPCD
{
	no warnings 'once';
	$main::dhcpcd_synthesize_implicit = 1;
	$main::dhcpcd_test_active_interfaces = [
		{ 'name' => 'lo', 'fullname' => 'lo', 'virtual' => '',
		  'up' => 1 },
		{ 'name' => 'enp0s5', 'fullname' => 'enp0s5',
		  'virtual' => '', 'up' => 1 },
		{ 'name' => 'wlan0', 'fullname' => 'wlan0',
		  'virtual' => '', 'up' => 1 },
		];
}
@boot = main::boot_interfaces();
is_deeply([ map { $_->{'fullname'} } @boot ], [ "enp0s5", "wlan0" ],
	  "dhcpcd synthesizes implicit DHCP boot interfaces");
ok((grep { $_->{'fullname'} eq "enp0s5" && $_->{'dhcp'} &&
	   $_->{'implicit'} } @boot),
   "dhcpcd marks synthesized interface as implicit DHCP");

my ($implicit) = grep { $_->{'fullname'} eq "enp0s5" } @boot;
main::delete_interface($implicit);
$saved = read_text($dhcpcd);
like($saved, qr/^denyinterfaces enp0s5\n# default dhcpcd configuration/m,
     "dhcpcd delete of implicit interface writes denyinterfaces");

@boot = main::boot_interfaces();
is_deeply([ map { $_->{'fullname'} } @boot ], [ "wlan0" ],
	  "dhcpcd does not synthesize denied interfaces");

my $newif = { 'name' => 'enp0s5',
	      'fullname' => 'enp0s5',
	      'virtual' => '',
	      'dhcp' => 1,
	      'address6' => [ ],
	      'netmask6' => [ ] };
main::save_interface($newif, \@boot);
$saved = read_text($dhcpcd);
unlike($saved, qr/^denyinterfaces/m,
       "dhcpcd save removes denyinterfaces for managed interface");
like($saved, qr/interface enp0s5\n(?:\n|$)/,
     "dhcpcd save creates explicit DHCP interface block");

write_text($dhcpcd, <<'DHCPCD');
denyinterfaces eth0 wlan0
interface eth0
static ip_address=192.168.1.30/24
DHCPCD
{
	no warnings 'once';
	$main::dhcpcd_synthesize_implicit = 0;
}
@boot = main::boot_interfaces();
my ($denied_eth0) = grep { $_->{'fullname'} eq "eth0" } @boot;
$denied_eth0->{'address'} = "192.168.1.31";
main::save_interface($denied_eth0, \@boot);
$saved = read_text($dhcpcd);
like($saved, qr/^denyinterfaces wlan0\ninterface eth0\nstatic ip_address=192\.168\.1\.31\/24/m,
     "dhcpcd save removes one denyinterfaces word without shifting block replacement");

write_text($dhcpcd, <<'DHCPCD');
denyinterfaces enp0s6 wlan0
interface enp0s6
static ip_address=10.211.55.21/24
DHCPCD
@boot = main::boot_interfaces();
my ($removed_enp0s6) = grep { $_->{'fullname'} eq "enp0s6" } @boot;
main::delete_interface($removed_enp0s6);
$saved = read_text($dhcpcd);
like($saved, qr/^denyinterfaces wlan0\n/m,
     "dhcpcd delete of explicit interface removes stale denyinterfaces word");
unlike($saved, qr/^interface enp0s6/m,
       "dhcpcd delete of explicit interface removes its block entirely");

write_text($dhcpcd, <<'DHCPCD');
allowinterfaces eth0
interface eth0
DHCPCD
@boot = main::boot_interfaces();
my $allowed_new = { 'name' => 'wlan0',
		    'fullname' => 'wlan0',
		    'virtual' => '',
		    'dhcp' => 1,
		    'address6' => [ ],
		    'netmask6' => [ ] };
main::save_interface($allowed_new, \@boot);
$saved = read_text($dhcpcd);
like($saved, qr/^allowinterfaces eth0 wlan0\ninterface eth0\n\ninterface wlan0/m,
     "dhcpcd save adds new explicit interface to existing allowinterfaces");

{
	no warnings 'once';
	$main::dhcpcd_test_active_interfaces = [
		{ 'name' => 'enp0s5', 'fullname' => 'enp0s5',
		  'virtual' => '', 'up' => 1 },
		];
}
@commands = ( );
like(main::apply_interface({ 'name' => 'enp0s6',
			     'fullname' => 'enp0s6',
			     'virtual' => '' }),
     qr/Cannot find device "enp0s6"/,
     "dhcpcd apply reports missing real device");
is_deeply(\@commands, [ ], "dhcpcd apply skips restart for missing device");

@commands = ( );
is(main::apply_interface({ 'name' => 'enp0s5',
			   'fullname' => 'enp0s5',
			   'virtual' => '' }),
   undef, "dhcpcd apply restarts service for existing device");
is_deeply(\@commands, [ "/etc/init.d/dhcpcd restart 2>&1 </dev/null" ],
	  "dhcpcd apply runs restart command for existing device");

@commands = ( );
write_text($dhcpcd, <<'DHCPCD');
interface enp0s5
static ip_address=10.211.55.20/24
DHCPCD
{
	no warnings 'redefine';
	no warnings 'once';
	$main::dhcpcd_synthesize_implicit = 0;
	$main::dhcpcd_test_active_interfaces = [
		{ 'name' => 'enp0s5',
		  'fullname' => 'enp0s5',
		  'virtual' => '',
		  'address' => '10.211.55.20',
		  'netmask' => '255.255.255.0',
		  'address6' => [ ],
		  'netmask6' => [ ],
		  'up' => 1 },
		{ 'name' => 'enp0s5',
		  'fullname' => 'enp0s5:1',
		  'virtual' => 1,
		  'address' => '10.211.55.21',
		  'netmask' => '255.255.255.0',
		  'address6' => [ ],
		  'netmask6' => [ ],
		  'up' => 1 },
		];
	local *main::has_command = sub {
		return $_[0] eq "ip" ? "/sbin/ip" : undef;
		};
	is(main::apply_network(), undef,
	   "dhcpcd global apply removes virtual alias missing from config");
	}
is_deeply(\@commands,
	  [ "ip addr del 10\\.211\\.55\\.21\\/24 dev enp0s5 2>&1",
	    "/etc/init.d/dhcpcd restart 2>&1 </dev/null" ],
	  "dhcpcd global apply removes live virtual address before restart");

@commands = ( );
write_text($dhcpcd, <<'DHCPCD');
interface enp0s5
static ip_address=10.211.55.20/24
static ip_address=10.211.55.23/24
DHCPCD
{
	no warnings 'redefine';
	no warnings 'once';
	$main::dhcpcd_synthesize_implicit = 0;
	$main::dhcpcd_test_active_interfaces = [
		{ 'name' => 'enp0s5',
		  'fullname' => 'enp0s5',
		  'virtual' => '',
		  'address' => '10.211.55.20',
		  'netmask' => '255.255.255.0',
		  'address6' => [ ],
		  'netmask6' => [ ],
		  'up' => 1 },
		{ 'name' => 'enp0s5',
		  'fullname' => 'enp0s5:0',
		  'virtual' => 0,
		  'address' => '10.211.55.24',
		  'netmask' => '255.255.255.0',
		  'address6' => [ ],
		  'netmask6' => [ ],
		  'up' => 1 },
		{ 'name' => 'enp0s5',
		  'fullname' => 'enp0s5:1',
		  'virtual' => 1,
		  'address' => '10.211.55.23',
		  'netmask' => '255.255.255.0',
		  'address6' => [ ],
		  'netmask6' => [ ],
		  'up' => 1 },
		];
	local *main::has_command = sub {
		return $_[0] eq "ip" ? "/sbin/ip" : undef;
		};
	is(main::delete_active_interface($main::dhcpcd_test_active_interfaces->[2]),
	   undef,
	   "dhcpcd active delete removes matching boot virtual alias");
	}
$saved = read_text($dhcpcd);
unlike($saved, qr/static ip_address=10\.211\.55\.23\/24/,
       "dhcpcd active delete removes alias from config");
is_deeply(\@commands,
	  [ "ip addr del 10\\.211\\.55\\.23\\/24 dev enp0s5 2>&1" ],
	  "dhcpcd active delete drops only the selected live virtual alias");
do "$root/net/linux-lib.pl" || die "linux-lib.pl: $@ $!";

@commands = ( );
{
	no warnings 'redefine';
	local *main::has_command = sub {
		return $_[0] eq "ip" ? "/sbin/ip" : undef;
		};
	local *main::active_interfaces = sub {
		return ( );
		};
	main::activate_interface({ 'name' => 'enp0s5',
				   'fullname' => 'enp0s5:1',
				   'virtual' => 1,
				   'address' => '10.211.55.25',
				   'netmask' => '255.255.255.0',
				   'address6' => [ ],
				   'netmask6' => [ ],
				   'up' => 0 });
	}
is_deeply(\@commands, [ ],
	  "Linux active virtual interface stays absent when created down");

@commands = ( );
{
	no warnings 'redefine';
	local *main::has_command = sub {
		return $_[0] eq "ip" ? "/sbin/ip" : undef;
		};
	local *main::active_interfaces = sub {
		return ({ 'name' => 'enp0s5',
			  'fullname' => 'enp0s5:1',
			  'virtual' => 1,
			  'address' => '10.211.55.25',
			  'netmask' => '255.255.255.0',
			  'address6' => [ ],
			  'netmask6' => [ ],
			  'up' => 1 });
		};
	main::activate_interface({ 'name' => 'enp0s5',
				   'fullname' => 'enp0s5:1',
				   'virtual' => 1,
				   'address' => '10.211.55.25',
				   'netmask' => '255.255.255.0',
				   'address6' => [ ],
				   'netmask6' => [ ],
				   'up' => 0 });
	}
is_deeply(\@commands,
	  [ "ip addr del 10\\.211\\.55\\.25\\/24 dev enp0s5 2>&1" ],
	  "Linux active virtual interface is removed when saved down");

done_testing();
