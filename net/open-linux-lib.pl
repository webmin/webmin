# open-linux.pl
# Networking functions for openlinux

$net_scripts_dir = "/etc/sysconfig/network-scripts";
$network_config = "/etc/sysconfig/network";
$static_route_config = "/etc/sysconfig/network-scripts/ifcfg-routes";
$nis_conf = "/etc/nis.conf";

do 'linux-lib.pl';

# boot_interfaces()
# Returns a list of interfaces brought up at boot time
sub boot_interfaces
{
local(@rv, $f);
opendir(CONF, &translate_filename($net_scripts_dir));
while($f = readdir(CONF)) {
	next if ($f !~ /^ifcfg-(\S+)/ || $f eq 'ifcfg-routes' ||
		 $f =~ /\.sample$/);
	local (%conf, $b);
	&read_env_file("$net_scripts_dir/$f", \%conf);
	$b->{'fullname'} = $conf{'DEVICE'} ? $conf{'DEVICE'} : $1;
	if ($b->{'fullname'} =~ /(\S+):(\d+)/) {
		$b->{'name'} = $1;
		$b->{'virtual'} = $2;
		}
	else { $b->{'name'} = $b->{'fullname'}; }
	$b->{'up'} = ($conf{'ONBOOT'} eq 'yes');
	$b->{'address'} = $conf{'IPADDR'} ? $conf{'IPADDR'} : "Automatic";
	$b->{'netmask'} = $conf{'NETMASK'} ? $conf{'NETMASK'} : "Automatic";
	$b->{'broadcast'} = $conf{'BROADCAST'} ? $conf{'BROADCAST'}
					       : "Automatic";
	$b->{'dhcp'} = $conf{'DYNAMIC'} eq 'dhcp';
	$b->{'edit'} = ($b->{'name'} !~ /^ppp|plip/);
	$b->{'desc'} = $conf{'NAME'};
	$b->{'index'} = scalar(@rv);
	$b->{'file'} = "$net_scripts_dir/$f";
	push(@rv, $b);
	}
closedir(CONF);
return @rv;
}

# save_interface(&details)
# Create or update a boot-time interface
sub save_interface
{
local(%conf);
local $name = $_[0]->{'virtual'} ne "" ? $_[0]->{'name'}.":".$_[0]->{'virtual'}
				       : $_[0]->{'name'};
&lock_file("$net_scripts_dir/ifcfg-$name");
&read_env_file("$net_scripts_dir/ifcfg-$name", \%conf);
$conf{'DEVICE'} = $name;
if ($_[0]->{'dhcp'}) {
	$conf{'DYNAMIC'} = 'dhcp';
	}
else {
	$conf{'IPADDR'} = $_[0]->{'address'};
	delete($conf{'DYNAMIC'});
	}
local($ip1, $ip2, $ip3, $ip4) = split(/\./, $_[0]->{'address'});
$conf{'NETMASK'} = $_[0]->{'netmask'};
local($nm1, $nm2, $nm3, $nm4) = split(/\./, $_[0]->{'netmask'});
$conf{'NETWORK'} = sprintf "%d.%d.%d.%d",
			($ip1 & int($nm1))&0xff,
			($ip2 & int($nm2))&0xff,
			($ip3 & int($nm3))&0xff,
			($ip4 & int($nm4))&0xff;
$conf{'BROADCAST'} = $_[0]->{'broadcast'};
$conf{'ONBOOT'} = $_[0]->{'up'} ? "yes" : "no";
$conf{'NAME'} = $_[0]->{'desc'};
&write_env_file("$net_scripts_dir/ifcfg-$name", \%conf);
&unlock_file("$net_scripts_dir/ifcfg-$name");
}

# delete_interface(&details)
# Delete a boot-time interface
sub delete_interface
{
local $name = $_[0]->{'virtual'} ne "" ? $_[0]->{'name'}.":".$_[0]->{'virtual'}
				       : $_[0]->{'name'};
&unlink_logged("$net_scripts_dir/ifcfg-$name");
}

# can_edit(what)
# Can some boot-time interface parameter be edited?
sub can_edit
{
return $_[0] ne "bootp" && $_[0] ne "mtu";
}

# can_iface_desc([&iface])
# Returns 1 if boot-interfaces can have comments
sub can_iface_desc
{
return 1;
}

# valid_boot_address(address)
# Is some address valid for a bootup interface
sub valid_boot_address
{
return &check_ipaddress($_[0]);
}

sub get_hostname
{
local %conf;
&read_env_file($network_config, \%conf);
if ($conf{'HOSTNAME'}) {
	return $conf{'HOSTNAME'};
	}
return &get_system_hostname(1);
}

# save_hostname(name)
sub save_hostname
{
local %conf;
&system_logged("hostname $_[0] >/dev/null 2>&1");
&open_lock_tempfile(HOST, ">/etc/HOSTNAME");
&print_tempfile(HOST, $_[0],"\n");
&close_tempfile(HOST);
&lock_file($network_config);
&read_file($network_config, \%conf);
$conf{'HOSTNAME'} = $_[0];
&write_file($network_config, \%conf);
&unlock_file($network_config);
undef(@main::get_system_hostname);      # clear cache
}

# get_domainname()
sub get_domainname
{
local $d;
&execute_command("domainname", undef, \$d, undef);
chop($d);
return $d;
}

# save_domainname(domain)
sub save_domainname
{
local %conf;
&execute_command("domainname ".quotemeta($_[0]));
&read_env_file($network_config, \%conf);
if ($_[0]) {
	$conf{'NISDOMAIN'} = $_[0];
	}
else {
	delete($conf{'NISDOMAIN'});
	}
&write_env_file($network_config, \%conf);
}

sub routing_config_files
{
return ( $network_config,
	 map { $_->{'file'} } &boot_interfaces() );
}

sub routing_input
{
local (%conf, %ifc, $f, $gateway, $gatewaydev);
&read_file($network_config, \%conf);
local ($gateway, $gatewaydev) = &get_default_gateway();

# Default router and device
print &ui_table_row($text{'routes_default'},
	&ui_radio("gateway_def", $gateway ? 0 : 1,
		  [ [ 1, $text{'routes_none'} ],
		    [ 0, $text{'routes_gateway'}." ".
			 &ui_textbox("gateway", $gateway, 15)." ".
			 $text{'routes_device'}." ".
			 &ui_textbox("gatewaydev", $gatewaydev, 6) ] ]));

# Forward traffic
print &ui_table_row($text{'routes_forward'},
	&ui_yesno_radio("forward", $conf{'IPFORWARDING'} =~ /yes|true/i));

# Additional routes script
print &ui_table_row($text{'routes_script'},
	&ui_textarea("script", &read_file_contents($static_route_config),
		     4, 60));
}

sub parse_routing
{
local %conf;
&lock_file($network_config);
&read_file($network_config, \%conf);
if ($in{'forward'}) { $conf{'IPFORWARDING'} = 'yes'; }
else { delete($conf{'IPFORWARDING'}); }
local %ifcs = map { $_->{'fullname'}, 1 } &all_interfaces();

if (!$in{'gateway_def'}) {
	&to_ipaddress($in{'gateway'}) ||
		&error(&text('routes_edefault', $in{'gateway'}));
	$ifcs{$in{'gatewaydev'}} ||
		&error(&text('routes_edevice', $in{'gatewaydev'}));
	}

&set_default_gateway($in{'gateway_def'} ? ( ) :
			( $in{'gateway'}, $in{'gatewaydev'} ) );

&write_file($network_config, \%conf);
&unlock_file($network_config);

&open_lock_tempfile(SCRIPT, ">$static_route_config");
$in{'script'} =~ s/\r//g;
&print_tempfile(SCRIPT, $in{'script'});
&close_tempfile(SCRIPT);
&system_logged("chmod +x $static_route_config");
}

# apply_network()
# Apply the interface and routing settings
sub apply_network
{
&system_logged("(cd / ; /etc/rc.d/init.d/network stop ; /etc/rc.d/init.d/network start) >/dev/null 2>&1");
}

# apply_interface(&iface)
# Calls an OS-specific function to make a boot-time interface active
sub apply_interface
{
local $out = &backquote_logged("cd / ; ifup '$_[0]->{'fullname'}' 2>&1 </dev/null");
return $? ? $out : undef;
}

# get_default_gateway()
# Returns the default gateway IP (if one is set) and device (if set) boot time
# settings.
sub get_default_gateway
{
&read_file($network_config, \%conf);
opendir(CONF, &translate_filename($net_scripts_dir));
local $f;
while($f = readdir(CONF)) {
	next if ($f !~ /^ifcfg-(\S+)/);
	local %ifc;
	&read_file("$net_scripts_dir/$f", \%ifc);
	if (&check_ipaddress($ifc{'GATEWAY'})) {
		return ( $ifc{'GATEWAY'}, $ifc{'DEVICE'} );
		}
	}
closedir(CONF);
return ( );
}

# set_default_gateway([gateway, device])
# Sets the default gateway to the given IP accessible via the given device,
# in the boot time settings.
sub set_default_gateway
{
opendir(CONF, &translate_filename($net_scripts_dir));
local $f;
while($f = readdir(CONF)) {
	next if ($f !~ /^ifcfg-(\S+)/);
	local %ifc;
	&lock_file("$net_scripts_dir/$f");
	&read_file("$net_scripts_dir/$f", \%ifc);
	if (!$_[0] || $ifc{'DEVICE'} ne $_[1]) {
		delete($ifc{'GATEWAY'});
		}
	else {
		$ifc{'GATEWAY'} = $_[0];
		}
	&write_file("$net_scripts_dir/$f", \%ifc);
	&unlock_file("$net_scripts_dir/$f");
	}
closedir(CONF);
}

# supports_address6([&iface])
# Returns 1 if managing IPv6 interfaces is supported
sub supports_address6
{
local ($iface) = @_;
return 0;
}

1;

