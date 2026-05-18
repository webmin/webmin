#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use Cwd qw(abs_path);
use File::Basename qw(dirname);
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
do "$root/net/netplan-lib.pl" || die "netplan-lib.pl: $@ $!";

{
	no warnings 'once';
	$main::netplan_dir = $tmp;
}

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
	"(cd / && \\/usr\\/sbin\\/netplan generate)" => 1,
	);
%command_output = (
	"(cd / && \\/usr\\/sbin\\/netplan generate)" => "bad yaml\n",
	);
is(main::apply_network(), "bad yaml\n",
   "apply_network returns validation errors");
is_deeply(\@commands, [ "(cd / && \\/usr\\/sbin\\/netplan generate)" ],
	  "apply_network skips apply when generate fails");

@commands = ( );
%command_status = ( );
%command_output = ( );
is(main::apply_network(), undef, "apply_network applies after validation");
is_deeply(\@commands,
	  [ "(cd / && \\/usr\\/sbin\\/netplan generate)",
	    "(cd / && \\/usr\\/sbin\\/netplan apply)" ],
	  "apply_network validates before applying");

done_testing();
