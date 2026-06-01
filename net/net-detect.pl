# net-detect.pl
# Helper functions for choosing the network config backend

sub net_has_network_manager_config
{
my ($dir) = @_;
$dir ||= "/etc/NetworkManager/system-connections";
my @files = glob("$dir/*.nmconnection");
return -d $dir && scalar(@files);
}

sub net_has_netplan_config
{
my ($dir) = @_;
$dir ||= "/etc/netplan";
return &has_command("netplan") &&
       -d $dir;
}

sub net_auto_backend
{
my ($os_type, $netplan_dir, $nm_conn_dir) = @_;
return "netplan"
	if ($os_type eq "debian-linux" &&
	    &net_has_netplan_config($netplan_dir));
return "nm"
	if (($os_type eq "redhat-linux" || $os_type eq "debian-linux") &&
	    &net_has_network_manager_config($nm_conn_dir));
return undef;
}

1;
