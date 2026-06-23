# net-detect.pl
# Helper functions for choosing the network config backend

do 'ifupdown-lib.pl' if (!defined(&ifupdown_get_interface_defs));

# net_has_network_manager_config([connections-directory])
# Returns true if NetworkManager connection profiles exist
sub net_has_network_manager_config
{
my ($dir) = @_;
$dir ||= "/etc/NetworkManager/system-connections";
my @files = glob("$dir/*.nmconnection");
return -d $dir && scalar(@files);
}

# net_has_netplan_config([netplan-directory])
# Returns true if Netplan is installed and its config directory exists
sub net_has_netplan_config
{
my ($dir) = @_;
$dir ||= "/etc/netplan";
return &has_command("netplan") &&
       -d $dir;
}

# net_has_ifupdown_config([interfaces-file])
# Returns true if ifupdown has any non-loopback iface stanzas
sub net_has_ifupdown_config
{
my ($file) = @_;
$file ||= "/etc/network/interfaces";
foreach my $iface (&ifupdown_get_interface_defs($file, undef, 1)) {
	# Loopback alone does not mean ifupdown owns real interfaces.
	return 1 if ($iface->[0] ne "lo");
	}
return 0;
}

# net_has_dhcpcd_config([dhcpcd-conf], [service-active])
# Returns true if dhcpcd appears to own interface startup config
sub net_has_dhcpcd_config
{
my ($file, $service_active) = @_;
$file ||= "/etc/dhcpcd.conf";
return 0 if (!-r $file);

# Explicit interface blocks are enough proof even if the daemon is down.
open(my $fh, "<", $file) || return 0;
while(my $line = <$fh>) {
	$line =~ s/#.*$//;
	if ($line =~ /^\s*interface\s+\S+/) {
		close($fh);
		return 1;
		}
	}
close($fh);

# Default dhcpcd configs often have no interface blocks, so require service
# evidence before treating the file as the active startup backend.
return defined($service_active) ? $service_active :
       &net_dhcpcd_service_active();
}

# net_dhcpcd_service_active()
# Returns true if the dhcpcd service is active or enabled
sub net_dhcpcd_service_active
{
if (&has_command("systemctl")) {
	foreach my $unit ("dhcpcd.service", "dhcpcd5.service") {
		my $q = quotemeta($unit);

		# Active means dhcpcd is managing interfaces right now.
		my $active = &backquote_command(
			"systemctl is-active $q 2>/dev/null </dev/null");
		return 1 if ($active =~ /^active\b/);

		# Enabled/static service units mean dhcpcd will manage them at boot.
		my $enabled = &backquote_command(
			"systemctl is-enabled $q 2>/dev/null </dev/null");
		return 1 if ($enabled =~ /^(enabled|static|indirect|alias)\b/);
		}
	}

# Non-systemd systems and some old dhcpcd packages expose a pid file.
return 1 if (-r "/run/dhcpcd.pid" || -r "/var/run/dhcpcd.pid");
return 0;
}

# net_auto_backend(os-type, [netplan-dir], [nm-dir], [ifupdown-file], [dhcpcd-conf], [dhcpcd-active])
# Returns the auto-detected backend name, or undef for the OS default
sub net_auto_backend
{
my ($os_type, $netplan_dir, $nm_conn_dir, $ifupdown_file, $dhcpcd_file,
    $dhcpcd_service_active) = @_;

# Netplan is the preferred modern Debian/Ubuntu network config backend.
return "netplan"
	if ($os_type eq "debian-linux" &&
	    &net_has_netplan_config($netplan_dir));

# NetworkManager is common on desktop/server installs and owns its profiles.
return "nm"
	if (($os_type eq "redhat-linux" || $os_type eq "debian-linux") &&
	    &net_has_network_manager_config($nm_conn_dir));

# dhcpcd is only a final Debian fallback when ifupdown is not configuring
# any real interfaces.
return "dhcpcd"
	if ($os_type eq "debian-linux" &&
	    !&net_has_ifupdown_config($ifupdown_file) &&
	    &net_has_dhcpcd_config($dhcpcd_file, $dhcpcd_service_active));
return undef;
}

1;
