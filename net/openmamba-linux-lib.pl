# redhat-linux-lib.pl
# Networking functions for redhat linux

$net_scripts_dir = "/etc/sysconfig/network-devices";
$network_config = "/etc/sysconfig/network";
$static_route_config = "/etc/sysconfig/static-routes";
$sysctl_config = "/etc/sysctl.conf";
$devices_dir = "/etc/sysconfig/network-devices";

# Redhat 7.2+ and Mandrake 9.1+ support separate gateways in each interface file
$supports_dev_gateway = ($gconfig{'os_type'} eq 'redhat-linux' &&
			 $gconfig{'os_version'} >= 7.2) ||
			($gconfig{'os_type'} eq 'mandrake-linux' &&
			 $gconfig{'os_version'} >= 9.1) ||
			($gconfig{'os_type'} eq 'coherant-linux' &&
			 $gconfig{'os_version'} >= 3.0) ||
			($gconfig{'os_type'} eq 'trustix-linux');

# Redhat 8.0+ and Mandrake 9.1+ have a separate file for static routes for
# each interface
$supports_dev_routes = ($gconfig{'os_type'} eq 'redhat-linux' &&
		        $gconfig{'os_version'} >= 8.0) ||
			($gconfig{'os_type'} eq 'mandrake-linux' &&
			 $gconfig{'os_version'} >= 9.1) ||
			($gconfig{'os_type'} eq 'coherant-linux' &&
			 $gconfig{'os_version'} >= 3.0) ||
			($gconfig{'os_type'} eq 'trustix-linux');

# Redhat 10 (ES/AS 3) uses route-$dev instead of $dev.route
$supports_route_dev = ($gconfig{'os_type'} eq 'redhat-linux' &&
		       $gconfig{'os_version'} >= 10.0) ||
		      ($gconfig{'os_type'} eq 'coherant-linux' &&
		       $gconfig{'os_version'} >= 3.0);

# Redhat 9.0+ uses the ONPARENT variable for virtual interfaces
$uses_on_parent = ($gconfig{'os_type'} eq 'redhat-linux' &&
		   $gconfig{'os_version'} >= 9.0) ||
		  ($gconfig{'os_type'} eq 'mandrake-linux' &&
		   $gconfig{'os_version'} >= 9.1) ||
		  ($gconfig{'os_type'} eq 'coherant-linux' &&
		   $gconfig{'os_version'} >= 3.0);

# Redhat versions 7.2 and above allow the MTU to be set at boot time
$supports_mtu = ($gconfig{'os_type'} eq 'redhat-linux' &&
		 $gconfig{'os_version'} >= 7.2) ||
		($gconfig{'os_type'} eq 'coherant-linux' &&
 		 $gconfig{'os_version'} >= 3.0);

do 'linux-lib.pl';

# boot_interfaces()
# Returns a list of interfaces brought up at boot time
sub boot_interfaces
{
local(@rv, $f);
opendir(CONF, &translate_filename($net_scripts_dir));
while($f = readdir(CONF)) {
	local (%conf, $b);
	if ($f =~ /^ifconfig-([a-z0-9:\.]+)\-range([a-z0-9\.\_]+)$/) {
		# A range of addresses
		&read_env_file("$net_scripts_dir/$f", \%conf);
		$b->{'fullname'} = "$1-range$2";
		$b->{'name'} = $1;
		$b->{'range'} = $2;
		$b->{'start'} = $conf{'IPADDR_START'};
		$b->{'end'} = $conf{'IPADDR_END'};
		$b->{'num'} = $conf{'CLONENUM_START'};
		$b->{'up'} = 1;
		$b->{'edit'} = 1;
		$b->{'index'} = scalar(@rv);
		$b->{'file'} = "$net_scripts_dir/$f";
		push(@rv, $b);
		}
	elsif ($f =~ /^ifconfig-[a-z0-9:\.]+$/ && $f !~ /\.(bak|old)$/i) {
		# Normal interface
		&read_env_file("$net_scripts_dir/$f", \%conf);
		$b->{'fullname'} = $conf{'DEVICE'};
		if ($b->{'fullname'} =~ /(\S+):(\d+)/) {
			$b->{'name'} = $1;
			$b->{'virtual'} = $2;
			}
		else { $b->{'name'} = $b->{'fullname'}; }
		$b->{'up'} = defined($conf{'ONPARENT'}) && $b->{'virtual'} ne '' ?
				($conf{'ONPARENT'} eq 'yes') :
				($conf{'ONBOOT'} eq 'yes');
		$b->{'address'} = $conf{'IPADDR'};
		$b->{'netmask'} = $conf{'NETMASK'};
		$b->{'broadcast'} = $conf{'BROADCAST'};
		$b->{'gateway'} = $conf{'GATEWAY'};
		$b->{'mtu'} = $conf{'MTU'};
		$b->{'dhcp'} = ($conf{'BOOTPROTO'} eq 'dhcp');
		$b->{'bootp'} = ($conf{'BOOTPROTO'} eq 'bootp');
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
local $name = $_[0]->{'range'} ne "" ? $_[0]->{'name'}."-range".$_[0]->{'range'} :
	      $_[0]->{'virtual'} ne "" ? $_[0]->{'name'}.":".$_[0]->{'virtual'}
				       : $_[0]->{'name'};
&lock_file("$net_scripts_dir/ifconfig-$name");
&read_env_file("$net_scripts_dir/ifconfig-$name", \%conf);
if ($_[0]->{'range'} ne "") {
	# Special case - saving a range
	$conf{'IPADDR_START'} = $_[0]->{'start'};
	$conf{'IPADDR_END'} = $_[0]->{'end'};
	$conf{'CLONENUM_START'} = $_[0]->{'num'};
	}
else {
	# Saving a normal interface
	$conf{'DEVICE'} = $name;
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
	$conf{'BROADCAST'} = $_[0]->{'broadcast'};
	if ($_[0]->{'gateway'}) {
		$conf{'GATEWAY'} = $_[0]->{'gateway'};
		}
	else {
		delete($conf{'GATEWAY'});
		}
	$conf{'MTU'} = $_[0]->{'mtu'};
	$conf{'ONBOOT'} = $_[0]->{'up'} ? "yes" : "no";
	$conf{'ONPARENT'} = $_[0]->{'up'} ? "yes" : "no" if ($_[0]->{'virtual'} ne '');
	$conf{'BOOTPROTO'} = $_[0]->{'bootp'} ? "bootp" :
			     $_[0]->{'dhcp'} ? "dhcp" : "none";
	}
&write_env_file("$net_scripts_dir/ifconfig-$name", \%conf);
if (-d &translate_filename($devices_dir)) {
	&link_file("$net_scripts_dir/ifconfig-$name",
		   "$devices_dir/ifconfig-$name");
	}
&unlock_file("$net_scripts_dir/ifconfig-$name");
}

# delete_interface(&details)
# Delete a boot-time interface
sub delete_interface
{
local $name = $_[0]->{'range'} ne "" ? $_[0]->{'name'}."-range".$_[0]->{'range'} :
	      $_[0]->{'virtual'} ne "" ? $_[0]->{'name'}.":".$_[0]->{'virtual'}
				       : $_[0]->{'name'};
&lock_file("$net_scripts_dir/ifconfig-$name");
&unlink_file("$net_scripts_dir/ifconfig-$name");
if (-d &translate_filename($devices_dir)) {
	&unlink_file("$devices_dir/ifconfig-$name");
	}
&unlock_file("$net_scripts_dir/ifconfig-$name");
}

# can_edit(what)
# Can some boot-time interface parameter be edited?
sub can_edit
{
if ($supports_mtu) {
	return 1;
	}
else {
	return $_[0] ne "mtu";
	}
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
local $old = &get_hostname();
local %conf;
&system_logged("hostname $_[0] >/dev/null 2>&1");
&open_lock_tempfile(HOST, ">/etc/HOSTNAME");
&print_tempfile(HOST, $_[0],"\n");
&close_tempfile(HOST);
&lock_file($network_config);
&read_env_file($network_config, \%conf);
$conf{'HOSTNAME'} = $_[0];
&write_env_file($network_config, \%conf);
&unlock_file($network_config);

# If any ifconfig-XXX files have the old hostname in DHCP_HOSTNAME, fix it
foreach my $b (&boot_interfaces()) {
	local %ifc;
	&read_env_file($b->{'file'}, \%ifc);
	if ($ifc{'DHCP_HOSTNAME'} eq $old) {
		$ifc{'DHCP_HOSTNAME'} = $_[0];
		&lock_file($b->{'file'});
		&write_env_file($b->{'file'}, \%ifc);
		&unlock_file($b->{'file'});
		}
	}
undef(@main::get_system_hostname);	# clear cache
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
local @rv = ( $network_config, $sysctl_config );
if (!$supports_dev_routes) {
	push(@rv, $static_route_config);
	}
else {
	local $f;
	opendir(DIR, &translate_filename($devices_dir));
	while($f = readdir(DIR)) {
		if ($f =~ /^([a-z]+\d*(\.\d+)?(:\d+)?)\.route$/ ||
		    $f =~ /^route\-([a-z]+\d*(\.\d+)?(:\d+)?)$/) {
			push(@rv, "$devices_dir/$f");
			}
		}
	closedir(DIR);
	}
return @rv;
}

sub routing_input
{
local (%conf, @st, @hr, %sysctl);
&read_env_file($network_config, \%conf);
if (!$supports_dev_gateway) {
	# show default router and device
	print "<tr> <td><b>$text{'routes_default'}</b></td> <td>\n";
	printf "<input type=radio name=gateway_def value=1 %s> $text{'routes_none'}\n",
		$conf{'GATEWAY'} ? "" : "checked";
	printf "<input type=radio name=gateway_def value=0 %s>\n",
		$conf{'GATEWAY'} ? "checked" : "";
	printf "<input name=gateway size=15 value=\"%s\"></td> </tr>\n",
		$conf{'GATEWAY'};

	print "<tr> <td><b>$text{'routes_device2'}</b></td> <td>\n";
	printf "<input type=radio name=gatewaydev_def value=1 %s> $text{'routes_none'}\n",
		$conf{'GATEWAYDEV'} ? "" : "checked";
	printf "<input type=radio name=gatewaydev_def value=0 %s>\n",
		$conf{'GATEWAYDEV'} ? "checked" : "";
	printf "<input name=gatewaydev size=6 value=\"%s\"></td> </tr>\n",
		$conf{'GATEWAYDEV'};
	}
else {
	# multiple default routers can exist!
	print "<tr> <td valign=top><b>$text{'routes_default2'}</b></td>\n";
	print "<td><table border>\n";
	print "<tr $tb> <td><b>$text{'routes_ifc'}</b></td> ",
	      "<td><b>$text{'routes_gateway'}</b></td> </tr>\n";
	local $r = 0;
	if ($conf{'GATEWAY'}) {
		print "<tr $cb>\n";
		print "<td>",&interface_sel("gatewaydev$r",
				    $conf{'GATEWAYDEV'} || "*"),"</td>\n";
		printf "<td><input name=gateway$r size=15 value='%s'></td>\n",
			$conf{'GATEWAY'};
		print "</tr>\n";
		$r++;
		}
	local @boot = &boot_interfaces();
	foreach $b (grep { $_->{'gateway'} && $_->{'virtual'} eq '' } @boot) {
		print "<tr $cb>\n";
		print "<td>",&interface_sel("gatewaydev$r",
				    $b->{'name'}),"</td>\n";
		printf "<td><input name=gateway$r size=15 value='%s'></td>\n",
			$b->{'gateway'};
		print "</tr>\n";
		$r++;
		}
	print "<tr $cb>\n";
	print "<td>",&interface_sel("gatewaydev$r"),"</td>\n";
	print "<td><input name=gateway$r size=15></td>\n";
	print "</tr>\n";
	print "</table></td> </tr>\n";
	}

# show routing
if ($gconfig{'os_version'} < 7.0) {
	print "<tr> <td><b>$text{'routes_forward'}</b></td> <td>\n";
	printf "<input type=radio name=forward value=1 %s> $text{'yes'}\n",
		$conf{'FORWARD_IPV4'} eq "yes" ? "checked" : "";
	printf "<input type=radio name=forward value=0 %s> $text{'no'}</td> </tr>\n",
		$conf{'FORWARD_IPV4'} eq "yes" ? "" : "checked";
	}
else {
	&read_env_file($sysctl_config, \%sysctl);
	print "<tr> <td><b>$text{'routes_forward'}</b></td> <td>\n";
	printf "<input type=radio name=forward value=1 %s> $text{'yes'}\n",
		$sysctl{'net.ipv4.ip_forward'} ? "checked" : "";
	printf "<input type=radio name=forward value=0 %s> $text{'no'}</td> </tr>\n",
		$sysctl{'net.ipv4.ip_forward'} ? "" : "checked";
	}

if (!$supports_dev_routes) {
	# get static routes from single file
	&open_readfile(STATIC, $static_route_config);
	while(<STATIC>) {
		if (/(\S+)\s+net\s+(\S+)\s+netmask\s+(\S+)\s+gw\s+(\S+)/) {
			push(@st, [ $1, $2, $3, $4 ]);
			}
		elsif (/(\S+)\s+host\s+(\S+)\s+gw\s+(\S+)/) {
			push(@st, [ $1, $2, '255.255.255.255', $3 ]);
			}
		elsif (/(\S+)\s+net\s+(\S+)\s+netmask\s+(\S+)/) {
			push(@hr, [ $1, $2, $3 ]);
			}
		elsif (/(\S+)\s+host\s+(\S+)/) {
			push(@hr, [ $1, $2, '255.255.255.255' ]);
			}
		}
	close(STATIC);
	}
else {
	# get static routes from per-interface files
	local $f;
	opendir(DIR, &translate_filename($devices_dir));
	while($f = readdir(DIR)) {
		if ($f =~ /^([a-z]+\d*(\.\d+)?(:\d+)?)\.route$/ ||
		    $f =~ /^route\-([a-z]+\d*(\.\d+)?(:\d+)?)$/) {
			local $dev = $1;
			local (%rfile, $i);
			&read_env_file("$devices_dir/$f", \%rfile);
			for($i=0; defined($rfile{"ADDRESS$i"}); $i++) {
				if ($rfile{"GATEWAY$i"}) {
					push(@st, [ $dev, $rfile{"ADDRESS$i"},
							  $rfile{"NETMASK$i"},
							  $rfile{"GATEWAY$i"} ]);
					}
				else {
					push(@hr, [ $dev, $rfile{"ADDRESS$i"},
							  $rfile{"NETMASK$i"} ||
							  "255.255.255.255" ]);
					}
				}
			}
		}
	closedir(DIR);
	}

# show static network routes
print "<tr> <td valign=top><b>$text{'routes_static'}</b></td>\n";
print "<td><table border>\n";
print "<tr $tb> <td><b>$text{'routes_ifc'}</b></td> ",
      "<td><b>$text{'routes_net'}</b></td> ",
      "<td><b>$text{'routes_mask'}</b></td> ",
      "<td><b>$text{'routes_gateway'}</b></td> </tr>\n";
for($i=0; $i<=@st; $i++) {
	local $st = $st[$i];
	print "<tr $cb>\n";
	print "<td><input name=dev_$i size=6 value='$st->[0]'></td>\n";
	print "<td><input name=net_$i size=15 value='$st->[1]'></td>\n";
	print "<td><input name=netmask_$i size=15 value='$st->[2]'></td>\n";
	print "<td><input name=gw_$i size=15 value='$st->[3]'></td>\n";
	print "</tr>\n";
	}
print "</table></td> </tr>\n";

# Show static host routes
print "<tr> <td valign=top><b>$text{'routes_local'}</b></td>\n";
print "<td><table border>\n";
print "<tr $tb> <td><b>$text{'routes_ifc'}</b></td> ",
      "<td><b>$text{'routes_net'}</b></td> ",
      "<td><b>$text{'routes_mask'}</b></td> </tr>\n";
for($i=0; $i<=@hr; $i++) {
	local $st = $hr[$i];
	print "<tr $cb>\n";
	print "<td><input name=ldev_$i size=6 value='$st->[0]'></td>\n";
	print "<td><input name=lnet_$i size=15 value='$st->[1]'></td>\n";
	print "<td><input name=lnetmask_$i size=15 value='$st->[2]'></td>\n";
	print "</tr>\n";
	}
print "</table></td> </tr>\n";
}

sub parse_routing
{
local (%conf, @st, %sysctl, %st, @boot);
&lock_file($network_config);
&read_env_file($network_config, \%conf);
if (!$supports_dev_gateway) {
	# Just update a single file
	if ($in{'gateway_def'}) { delete($conf{'GATEWAY'}); }
	elsif (!gethostbyname($in{'gateway'})) {
		&error(&text('routes_edefault', $in{'gateway'}));
		}
	else { $conf{'GATEWAY'} = $in{'gateway'}; }

	if ($in{'gatewaydev_def'}) { delete($conf{'GATEWAYDEV'}); }
	elsif ($in{'gatewaydev'} !~ /^\S+$/) {
		&error(&text('routes_edevice', $in{'gatewaydev'}));
		}
	else { $conf{'GATEWAYDEV'} = $in{'gatewaydev'}; }
	}
else {
	# Multiple defaults can be specified!
	local ($r, $b);
	@boot = grep { $->{'virtual'} eq '' } &boot_interfaces();
	foreach $b (@boot) {
		delete($b->{'gateway'});
		}
	delete($conf{'GATEWAY'});
	delete($conf{'GATEWAYDEV'});

	for($r=0; defined($in{"gatewaydev$r"}); $r++) {
		next if (!$in{"gatewaydev$r"});
		&check_ipaddress($in{"gateway$r"}) ||
			&error(&text('routes_edefault2', $r+1));
		if ($in{"gatewaydev$r"} eq "*") {
			# For any interface
			$conf{'GATEWAY'} && &error(&text('routes_eclash'));
			$conf{'GATEWAY'} = $in{"gateway$r"};
			}
		else {
			# For a specific interface
			local ($b) = grep { $_->{'fullname'} eq $in{"gatewaydev$r"} } @boot;
			$b->{'gateway'} && &error(&text('routes_eclash2',
							$in{"gatewaydev$r"}));
			$b->{'gateway'} = $in{"gateway$r"};
			}
		}
	}

if ($gconfig{'os_version'} < 7.0) {
	if ($in{'forward'}) { $conf{'FORWARD_IPV4'} = 'yes'; }
	else { $conf{'FORWARD_IPV4'} = 'no'; }
	}
else {
	&lock_file($sysctl_config);
	&read_env_file($sysctl_config, \%sysctl);
	$sysctl{'net.ipv4.ip_forward'} = $in{'forward'};
	}

# Parse static and local routes
for($i=0; defined($dev = $in{"dev_$i"}); $i++) {
	next if (!$dev);
	$net = $in{"net_$i"}; $netmask = $in{"netmask_$i"}; $gw = $in{"gw_$i"};
	$dev =~ /^\S+$/ || &error(&text('routes_edevice', $dev));
	gethostbyname($net) || &error(&text('routes_enet', $net));
	&check_ipaddress($netmask) || &error(&text('routes_emask', $netmask));
	gethostbyname($gw) || &error(&text('routes_egateway', $gw));
	if ($netmask eq "255.255.255.255") {
		push(@st, "$dev host $net gw $gw\n");
		}
	else {
		push(@st, "$dev net $net netmask $netmask gw $gw\n");
		}
	push(@{$st{$dev}}, [ $net, $netmask, $gw ]);
	}
for($i=0; defined($dev = $in{"ldev_$i"}); $i++) {
	$net = $in{"lnet_$i"}; $netmask = $in{"lnetmask_$i"};
	next if (!$dev && !$net);
	$dev =~ /^\S+$/ || &error(&text('routes_edevice', $dev));
	gethostbyname($net) || $net =~ /^(\S+)\/(\d+)$/ && gethostbyname($1) ||
		&error(&text('routes_enet', $net));
	&check_ipaddress($netmask) || &error(&text('routes_emask', $netmask));
	if ($netmask eq "255.255.255.255") {
		push(@st, "$dev host $net\n");
		}
	else {
		push(@st, "$dev net $net netmask $netmask\n");
		}
	push(@{$st{$dev}}, [ $net, $netmask ]);
	}
if (!$supports_dev_routes) {
	# Write to a single file
	&open_lock_tempfile(STATIC, ">$static_route_config");
	&print_tempfile(STATIC, @st);
	&close_tempfile(STATIC);
	}
else {
	# Write to one file per interface (delete old, then save new/updated)
	local $f;
	opendir(DIR, &translate_filename($devices_dir));
	while($f = readdir(DIR)) {
		if (($f =~ /^([a-z]+\d*(\.\d+)?(:\d+)?)\.route$/ ||
		     $f =~ /^route\-([a-z]+\d*(\.\d+)?(:\d+)?)$/) && !$st{$1}) {
			&unlink_logged("$devices_dir/$f");
			&unlink_logged("$net_scripts_dir/$f");
			}
		}
	closedir(DIR);
	foreach $dev (keys %st) {
		$f = $supports_route_dev ? "route-$dev" : "$dev.route";
		local (%rfile, $i);
		for($i=0; $i<@{$st{$dev}}; $i++) {
			$rfile{"ADDRESS$i"} = $st{$dev}->[$i]->[0];
			$rfile{"NETMASK$i"} = $st{$dev}->[$i]->[1];
			$rfile{"GATEWAY$i"} = $st{$dev}->[$i]->[2];
			}
		&lock_file("$devices_dir/$f");
		&write_env_file("$devices_dir/$f", \%rfile);
		&unlock_file("$devices_dir/$f");
		&lock_file("$net_scripts_dir/$f");
		&link_file("$devices_dir/$f", "$net_scripts_dir/$f");
		&unlock_file("$net_scripts_dir/$f");
		}
	}
&write_env_file($network_config, \%conf);
&unlock_file($network_config);
if (%sysctl) {
	&write_env_file($sysctl_config, \%sysctl);
	&unlock_file($sysctl_config);
	}
if (@boot) {
	local $b;
	foreach $b (@boot) {
		&save_interface($b);
		}
	}
}

sub os_feedback_files
{
opendir(DIR, $net_scripts_dir);
local @f = readdir(DIR);
closedir(DIR);
return ( (map { "$net_scripts_dir/$_" } grep { /^ifconfig-/ } @f),
	 $network_config, $static_route_config, "/etc/resolv.conf",
	 "/etc/nsswitch.conf", "/etc/HOSTNAME" );
}

# interface_sel(name, value)
# Returns a menu for all boot-time interfaces
sub interface_sel
{
local $rv = "<select name=$_[0]>\n";
$rv .= sprintf "<option value='' %s>&nbsp;\n",
	$_[1] eq "" ? "selected" : "";
$rv .= sprintf "<option value='*' %s>%s\n",
	$_[1] eq "*" ? "selected" : "", $text{'routes_any'};
@boot_interfaces_cache = &boot_interfaces() if (!@boot_interfaces_cache);
foreach $b (@boot_interfaces_cache) {
	next if ($b->{'virtual'} ne '');
	$rv .= sprintf "<option value=%s %s>%s\n",
	    $b->{'name'}, $b->{'name'} eq $_[1] ? "selected" : "", $b->{'name'};
	}
$rv .= "</select>\n";
return $rv;
}

# apply_network()
# Apply the interface and routing settings
sub apply_network
{
&system_logged("(cd / ; /etc/init.d/network stop ; /etc/init.d/network start) >/dev/null 2>&1");
}

# apply_interface(&iface)
# Calls an OS-specific function to make a boot-time interface active
sub apply_interface
{
local $out = &backquote_logged("cd / ; ifdown '$_[0]->{'fullname'}' >/dev/null 2>&1 </dev/null ; ifup '$_[0]->{'fullname'}' 2>&1 </dev/null");
return $? || $out =~ /error/i ? $out : undef;
}

# unapply_interface(&iface)
# Calls an OS-specific function to make a boot-time interface inactive
#sub unapply_interface
#{
#local $out = &backquote_logged("cd / ; ifdown '$_[0]->{'fullname'}' 2>&1 </dev/null");
#return $? ? $out : undef;
#}

# get_default_gateway()
# Returns the default gateway IP (if one is set) and device (if set) boot time
# settings.
sub get_default_gateway
{
local %conf;
&read_env_file($network_config, \%conf);
local @boot = &boot_interfaces();
local ($gifc) = grep { $_->{'gateway'} && $_->{'virtual'} eq '' } @boot;
return ( $gifc->{'gateway'}, $gifc->{'fullname'} ) if ($gifc);

return $conf{'GATEWAY'} ? ( $conf{'GATEWAY'}, $conf{'GATEWAYDEV'} ) : ( );
}

# set_default_gateway(gateway, device)
# Sets the default gateway to the given IP accessible via the given device,
# in the boot time settings.
sub set_default_gateway
{
&lock_file($network_config);
&read_env_file($network_config, \%conf);
if (!$supports_dev_gateway) {
	# Just update the network config file
	local %conf;
	if ($_[0]) {
		$conf{'GATEWAY'} = $_[0];
		$conf{'GATEWAYDEV'} = $_[1];
		}
	else {
		delete($conf{'GATEWAY'});
		delete($conf{'GATEWAYDEV'});
		}
	}
else {
	# Set the gateway in the specified interface file, and clear the rest
	local @boot = grep { $->{'virtual'} eq '' } &boot_interfaces();
	foreach $b (@boot) {
		delete($b->{'gateway'});
		if ($_[0] && $b->{'fullname'} eq $_[1]) {
			$b->{'gateway'} = $_[0];
			&save_interface($b);
			}
		}
	delete($conf{'GATEWAY'});
	delete($conf{'GATEWAYDEV'});
	}
&write_env_file($network_config, \%conf);
&unlock_file($network_config);
}

# supports_ranges()
# Returns 1 for newer redhat versions
sub supports_ranges
{
return ($gconfig{'os_type'} eq 'redhat-linux' &&
	$gconfig{'os_version'} >= 7.3) ||
       ($gconfig{'os_type'} eq 'mandrake-linux' &&
	$gconfig{'os_version'} >= 8.0) ||
       ($gconfig{'os_type'} eq 'coherant-linux' &&
	$gconfig{'os_version'} >= 3.0);
}

# range_input([&interface])
# Print HTML for a IP range interface
sub range_input
{
local $new = !$_[0];

# Base interface
print "<tr> <td><b>$text{'range_iface'}</b></td>\n";
if ($new) {
	print "<td><select name=iface>\n";
	local $b;
	foreach $b (&boot_interfaces()) {
		if ($b->{'virtual'} eq '') {
			printf "<option %s>%s\n",
			 $b->{'fullname'} eq $_[0]->{'name'} ?  "selected" : "",
			 $b->{'fullname'};
			}
		}
	print "</select></td>\n";
	}
else {
	print "<td><tt>$_[0]->{'name'}</tt></td>\n";
	}

# Name for this range
print "<td><b>$text{'range_name'}</b></td>\n";
if ($new) {
	print "<td><input name=range size=10></td> </tr>\n";
	}
else {
	print "<td><tt>$_[0]->{'range'}</tt></td> </tr>\n";
	}

# Start
print "<tr> <td><b>$text{'range_start'}</b></td>\n";
printf "<td><input name=start size=15 value='%s'></td>\n",
	$_[0]->{'start'};

# Stop
print "<td><b>$text{'range_end'}</b></td>\n";
printf "<td><input name=end size=15 value='%s'></td> </tr>\n",
	$_[0]->{'end'};

# Base number
print "<tr> <td><b>$text{'range_num'}</b></td>\n";
printf "<td><input name=num size=5 value='%s'></td> </tr>\n",
	$_[0]->{'num'};
}

# parse_range(&range, &in)
sub parse_range
{
local %in = %{$_[1]};
if ($in{'new'}) {
	$_[0]->{'name'} = $in{'iface'};
	$in{'range'} =~ /^[a-z0-9\.\_]+$/ || &error($text{'range_ename'});
	$_[0]->{'range'} = $in{'range'};
	$_[0]->{'fullname'} = $in{'iface'}."-range".$in{'range'};
	}

&check_ipaddress($in{'start'}) || &error($text{'range_estart'});
$_[0]->{'start'} = $in{'start'};

&check_ipaddress($in{'end'}) || &error($text{'range_eend'});
$_[0]->{'end'} = $in{'end'};

local @sip = split(/\./, $in{'start'});
local @eip = split(/\./, $in{'end'});
$sip[0] == $eip[0] && $sip[1] == $eip[1] && $sip[2] == $eip[2] ||
	&error($text{'range_eclass'});
$sip[3] <= $eip[3] || &error($text{'range_ebefore'});

$in{'num'} =~ /^\d+$/ || &error($text{'range_enum'});
$_[0]->{'num'} = $in{'num'};
}

# get_dhcp_hostname()
# Returns 0 if the hostname is not set by DHCP, 1 if it is, or -1 if this
# feature is not supported on this OS.
sub get_dhcp_hostname
{
return -1 if ($gconfig{'os_type'} ne 'redhat-linux' ||
	      $gconfig{'os_version'} < 11);
local @boot = &boot_interfaces();
local ($eth) = grep { $_->{'fullname'} =~ /^eth\d+$/ } @boot;
return -1 if (!$eth);
local %eth;
&read_env_file($eth->{'file'}, \%eth);
return $eth{'DHCP_HOSTNAME'} ne &get_system_hostname();
}

# save_dhcp_hostname(set)
# If called with a parameter of 0, the hostname is fixed and not set by
# DHCP. If called with 1, the hostname is chosen by DHCP.
sub save_dhcp_hostname
{
}

1;

