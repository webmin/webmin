# suse-linux-9.0-lib.pl
# Networking functions for SuSE linux 9.0 and above

$net_scripts_dir = "/etc/sysconfig/network";
$routes_config = "/etc/sysconfig/network/routes";
$sysctl_config = "/etc/sysconfig/sysctl";

do 'linux-lib.pl';

# boot_interfaces()
# Returns a list of interfaces brought up at boot time
sub boot_interfaces
{
local(@rv, $f);
local @active = &active_interfaces();
opendir(CONF, &translate_filename($net_scripts_dir));
while($f = readdir(CONF)) {
	if ($f =~ /^ifcfg-eth-id-([a-f0-9:]+)$/i) {
		# An interface identified by MAC address!
		local (%conf, $b);
		$b->{'mac'} = $1;
		local ($a) = grep { lc($_->{'ether'}) eq lc($b->{'mac'}) }
				  @active;
		next if (!$a);
		&read_env_file("$net_scripts_dir/$f", \%conf);
		$b->{'fullname'} = $a->{'fullname'};
		$b->{'name'} = $a->{'name'};
		$b->{'up'} = ($conf{'STARTMODE'} eq 'onboot');
		local $pfx;
		if ($conf{'IPADDR'} =~ /^(\S+)\/(\d+)$/) {
			$b->{'address'} = $1;
			$pfx = $2;
			}
		else {
			$b->{'address'} = $conf{'IPADDR'};
			}
		$pfx = $conf{'PREFIXLEN'} if (!$pfx);
		if ($pfx) {
			$b->{'netmask'} = &prefix_to_mask($pfx);
			}
		else {
			$b->{'netmask'} = $conf{'NETMASK'};
			}
		$b->{'broadcast'} = $conf{'BROADCAST'};
		$b->{'dhcp'} = ($conf{'BOOTPROTO'} eq 'dhcp');
		$b->{'mtu'} = $conf{'MTU'};
		$b->{'edit'} = ($b->{'name'} !~ /^ppp|irlan/);
		$b->{'index'} = scalar(@rv);
		$b->{'file'} = "$net_scripts_dir/$f";
		push(@rv, $b);
		}
	elsif ($f =~ /^ifcfg-([a-z0-9:\.]+)$/) {
		# A normal interface file
		local (%conf, $b);
		$b->{'fullname'} = $1;
		&read_env_file("$net_scripts_dir/$f", \%conf);
		if ($b->{'fullname'} =~ /(\S+):(\d+)/) {
			$b->{'name'} = $1;
			$b->{'virtual'} = $2;
			}
		else { $b->{'name'} = $b->{'fullname'}; }
		$b->{'up'} = ($conf{'STARTMODE'} eq 'onboot');
		local $pfx;
		if ($conf{'IPADDR'} =~ /^(\S+)\/(\d+)$/) {
			$b->{'address'} = $1;
			$pfx = $2;
			}
		else {
			$b->{'address'} = $conf{'IPADDR'};
			}
		$pfx = $conf{'PREFIXLEN'} if (!$pfx);
		if ($pfx) {
			$b->{'netmask'} = &prefix_to_mask($pfx);
			}
		else {
			$b->{'netmask'} = $conf{'NETMASK'};
			}
		$b->{'broadcast'} = $conf{'BROADCAST'};
		$b->{'dhcp'} = ($conf{'BOOTPROTO'} eq 'dhcp');
		$b->{'mtu'} = $conf{'MTU'};
		$b->{'edit'} = ($b->{'name'} !~ /^ppp|irlan/);
		$b->{'index'} = scalar(@rv);
		$b->{'file'} = "$net_scripts_dir/$f";
		push(@rv, $b);
		}
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
local $file = $_[0]->{'file'} || "$net_scripts_dir/ifcfg-$name";
&lock_file($file);
&read_env_file($file, \%conf);
$conf{'IPADDR'} = $_[0]->{'address'};
local($ip1, $ip2, $ip3, $ip4) = split(/\./, $_[0]->{'address'});
$conf{'NETMASK'} = $_[0]->{'netmask'};
local($nm1, $nm2, $nm3, $nm4) = split(/\./, $_[0]->{'netmask'});
if ($_[0]->{'address'} && $_[0]->{'netmask'}) {
	$conf{'NETWORK'} = sprintf "%d.%d.%d.%d",
				($ip1 & int($nm1))&0xff,
				($ip2 & int($nm2))&0xff,
				($ip3 & int($nm3))&0xff,
				($ip4 & int($nm4))&0xff;
	}
else {
	$conf{'NETWORK'} = '';
	}
delete($conf{'PREFIXLEN'});
$conf{'BROADCAST'} = $_[0]->{'broadcast'};
$conf{'STARTMODE'} = $_[0]->{'up'} ? "onboot" :
		     $conf{'STARTMODE'} eq "onboot" ? "manual" :
						      $conf{'STARTMODE'};
$conf{'BOOTPROTO'} = $_[0]->{'dhcp'} ? "dhcp" : "static";
$conf{'MTU'} = $_[0]->{'mtu'};
$conf{'UNIQUE'} ||= time();
&write_env_file($file, \%conf);
&unlock_file($file);
}

# delete_interface(&details)
# Delete a boot-time interface
sub delete_interface
{
local $name = $_[0]->{'virtual'} ne "" ? $_[0]->{'name'}.":".$_[0]->{'virtual'}
				       : $_[0]->{'name'};
local $file = $_[0]->{'file'} || "$net_scripts_dir/ifcfg-$name";
&unlink_logged($file);
}

# can_edit(what)
# Can some boot-time interface parameter be edited?
sub can_edit
{
return $_[0] ne "bootp";
}

# valid_boot_address(address)
# Is some address valid for a bootup interface
sub valid_boot_address
{
return &check_ipaddress($_[0]);
}

# get_hostname()
sub get_hostname
{
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
undef(@main::get_system_hostname);      # clear cache
}

sub routing_config_files
{
return ( $routes_config, $sysctl_config );
}

# get_routes_config()
# Returns the list of save static routes
sub get_routes_config
{
local (@routes);
&open_readfile(ROUTES, $routes_config);
while(<ROUTES>) {
	s/#.*$//;
	s/\r|\n//g;
	local @r = map { $_ eq '-' ? undef : $_ } split(/\s+/, $_);
	push(@routes, \@r) if (@r);
	}
close(ROUTES);
return @routes;
}

# save_routes_config(&routes)
sub save_routes_config
{
&open_tempfile(ROUTES, ">$routes_config");
foreach $r (@{$_[0]}) {
	&print_tempfile(ROUTES, join(" ",
		$r->[0] || "-",
		$r->[1] || "-",
		$r->[2] || "-",
		$r->[3] || "-"),"\n");
	}
&close_tempfile(ROUTES);
}

sub routing_input
{
local @routes = &get_routes_config();

# show default router and device
local ($def) = grep { $_->[0] eq "default" } @routes;
print "<tr> <td><b>$text{'routes_default'}</b></td> <td>\n";
printf "<input type=radio name=gateway_def value=1 %s> $text{'routes_none'}\n",
	$def->[1] ? "" : "checked";
printf "<input type=radio name=gateway_def value=0 %s>\n",
	$def->[1] ? "checked" : "";
printf "<input name=gateway size=15 value=\"%s\"></td> </tr>\n",
	$def->[1];

print "<tr> <td><b>$text{'routes_device2'}</b></td> <td>\n";
printf "<input type=radio name=gatewaydev_def value=1 %s> $text{'routes_none'}\n",
	$def->[3] ? "" : "checked";
printf "<input type=radio name=gatewaydev_def value=0 %s>\n",
	$def->[3] ? "checked" : "";
printf "<input name=gatewaydev size=6 value=\"%s\"></td> </tr>\n",
	$def->[3];

&read_env_file($sysctl_config, \%sysctl);
print "<tr> <td><b>$text{'routes_forward'}</b></td> <td>\n";
printf "<input type=radio name=forward value=1 %s> $text{'yes'}\n",
	$sysctl{'IP_FORWARD'} eq 'yes' ? "checked" : "";
printf "<input type=radio name=forward value=0 %s> $text{'no'}</td> </tr>\n",
	$sysctl{'IP_FORWARD'} eq 'yes' ? "" : "checked";

# show static network routes
print "<tr> <td valign=top><b>$text{'routes_static'}</b></td>\n";
print "<td><table border>\n";
print "<tr $tb> <td><b>$text{'routes_ifc'}</b></td> ",
      "<td><b>$text{'routes_net'}</b></td> ",
      "<td><b>$text{'routes_mask'}</b></td> ",
      "<td><b>$text{'routes_gateway'}</b></td> ",
      "<td><b>$text{'routes_type'}</b></td> </tr>\n";
local ($r, $i = 0);
foreach $r (@routes, [ ]) {
	next if ($r eq $def);
	print "<tr $cb>\n";
	print "<td><input name=dev_$i size=6 value='$r->[3]'></td>\n";
	print "<td><input name=net_$i size=15 value='$r->[0]'></td>\n";
	print "<td><input name=netmask_$i size=15 value='$r->[2]'></td>\n";
	print "<td><input name=gw_$i size=15 value='$r->[1]'></td>\n";
	print "<td><input name=type_$i size=10 value='$r->[4]'></td>\n";
	print "</tr>\n";
	$i++;
	}
print "</table></td> </tr>\n";
}

sub parse_routing
{
# Parse route inputs
local (@routes, $r, $i);
if (!$in{'gateway_def'}) {
	gethostbyname($in{'gateway'}) ||
		&error(&text('routes_edefault', $in{'gateway'}));
	local @def = ( "default", $in{'gateway'}, undef, undef );
	if (!$in{'gatewaydev_def'}) {
		$in{'gatewaydev'} =~ /^\S+$/ ||
			&error(&text('routes_edevice', $in{'gatewaydev'}));
		$def[3] = $in{'gatewaydev'};
		}
	push(@routes, \@def);
	}
for($i=0; defined($in{"dev_$i"}); $i++) {
	next if (!$in{"net_$i"});
	&check_ipaddress($in{"net_$i"}) ||
		$in{"net_$i"} =~ /^(\S+)\/(\d+)$/ && &check_ipaddress($1) ||
		&error(&text('routes_enet', $in{"net_$i"}));
	$in{"dev_$i"} =~ /^\S*$/ || &error(&text('routes_edevice', $dev));
	!$in{"netmask_$i"} || &check_ipaddress($in{"netmask_$i"}) ||
		&error(&text('routes_emask', $in{"netmask_$i"}));
	!$in{"gw_$i"} || &check_ipaddress($in{"gw_$i"}) ||
		&error(&text('routes_egateway', $in{"gw_$i"}));
	$in{"type_$i"} =~ /^\S*$/ ||
		&error(&text('routes_etype', $in{"type_$i"}));
	push(@routes, [ $in{"net_$i"}, $in{"gw_$i"}, $in{"netmask_$i"},
			$in{"dev_$i"}, $in{"type_$i"} ] );
	}

# Save routes and routing option
&save_routes_config(\@routes);
local $lref = &read_file_lines($sysctl_config);
for($i=0; $i<@$lref; $i++) {
	if ($lref->[$i] =~ /^\s*IP_FORWARD\s*=/) {
		$lref->[$i] = "IP_FORWARD=".($in{'forward'} ? "yes" : "no");
		}
	}
&flush_file_lines();
}

# get_default_gateway()
# Returns the default gateway IP (if one is set) and device (if set) boot time
# settings.
sub get_default_gateway
{
local @routes = &get_routes_config();
local ($def) = grep { $_->[0] eq "default" } @routes;
if ($def) {
	return ( $def->[1], $def->[3] );
	}
else {
	return ( );
	}
}

# set_default_gateway(gateway, device)
# Sets the default gateway to the given IP accessible via the given device,
# in the boot time settings.
sub set_default_gateway
{
local @routes = &get_routes_config();
local ($def) = grep { $_->[0] eq "default" } @routes;
if ($def && $_[0]) {
	$def->[1] = $_[0];
	$def->[3] = $_[1];
	}
elsif ($def && !$_[0]) {
	@routes = grep { $_ ne $def } @routes;
	}
elsif (!$def && $_[0]) {
	splice(@routes, 0, 0, [ "default", $_[0], undef, $_[1] ]);
	}
&save_routes_config(\@routes);
}

sub os_feedback_files
{
opendir(DIR, $net_scripts_dir);
local @f = readdir(DIR);
closedir(DIR);
return ( (map { "$net_scripts_dir/$_" } grep { /^ifcfg-/ } @f),
	 $network_config, $static_route_config, "/etc/resolv.conf",
	 "/etc/nsswitch.conf", "/etc/HOSTNAME" );
}

# apply_network()
# Apply the interface and routing settings
sub apply_network
{
&system_logged("(cd / ; /etc/init.d/network stop ; /etc/init.d/network start) >/dev/null 2>&1");
}

1;

