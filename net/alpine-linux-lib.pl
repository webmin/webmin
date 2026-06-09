# Networking functions for Alpine Linux

do 'debian-linux-lib.pl';

$network_interfaces_config = '/etc/network/interfaces';

# apply_network()
# Apply the interface and routing settings
sub apply_network
{
if (&has_command("rc-service")) {
	&system_logged("(cd / ; rc-service networking restart) >/dev/null 2>&1");
	}
elsif (-x "/etc/init.d/networking") {
	&system_logged("(cd / ; /etc/init.d/networking restart) >/dev/null 2>&1");
	}
else {
	&system_logged("(cd / ; ifdown -a ; ifup -a) >/dev/null 2>&1");
	}
}

sub network_config_files
{
return ( "/etc/hostname", "/etc/HOSTNAME", "/etc/mailname",
	 $network_interfaces_config );
}

sub supports_bonding
{
return &has_command("ifenslave");
}

sub supports_vlans
{
return &has_command("vconfig");
}

1;
