# redhat-linux-lib.pl
# Networking functions for redhat linux

if ($gconfig{'os_type'} eq 'openmamba-linux') {
	# OpenMamba Linux
	$net_scripts_dir = "/etc/sysconfig/network-devices";
	$devices_dir = "/etc/sysconfig/network-devices";
	}
else {
	# Redhat, Mandrake, etc..
	$net_scripts_dir = "/etc/sysconfig/network-scripts";
	$devices_dir = "/etc/sysconfig/networking/devices";
	}
$route_files_dir = -d $devices_dir ? $devices_dir : $net_scripts_dir;
$network_config = "/etc/sysconfig/network";
$static_route_config = "/etc/sysconfig/static-routes";
$sysctl_config = "/etc/sysctl.conf";

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
local (@rv, $f);
local %bridge_map;
local @active;
opendir(CONF, &translate_filename($net_scripts_dir));
while($f = readdir(CONF)) {
	local (%conf, $b);
	if ($f =~ /^ifcfg-([a-z0-9:\.]+)\-range([a-z0-9\.\_]+)$/) {
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
		$b->{'desc'} = $conf{'NAME'};
		$b->{'index'} = scalar(@rv);
		$b->{'file'} = "$net_scripts_dir/$f";
		push(@rv, $b);
		}
	elsif ($f !~ /\.(bak|old)$/i && $f =~ /^ifcfg-([a-zA-Z_0-9:\.]+)$/) {
		# Normal interface
		my $fname = $1;
		&read_env_file("$net_scripts_dir/$f", \%conf);
		if ($conf{'DEVICE'}) {
			# Device is set in the file
			$b->{'fullname'} = $conf{'DEVICE'};
			}
		elsif (&iface_type($fname) ne $text{'ifcs_unknown'}) {
			# Filename looks like a regular device
			$b->{'fullname'} = $fname;
			}
		elsif ($conf{'HWADDR'}) {
			# Filename is something odd, like Auto_Ethernet .. so
			# lookup real device by MAC
			if (!@active) {
				@active = &active_interfaces(1);
				}
			my ($a) = grep { lc($_->{'ether'}) eq
					 lc($conf{'HWADDR'}) &&
					 $_->{'name'} !~ /^br/ } @active;
			next if (!$a);
			$b->{'fullname'} = $a->{'fullname'};
			# XXX virtuals?
			}
		else {
			# No idea what to do here, probably isn't even an
			# interface file
			next;
			}
		if ($b->{'fullname'} =~ /(\S+):(\d+)/) {
			$b->{'name'} = $1;
			$b->{'virtual'} = $2;
			}
		else {
			$b->{'name'} = $b->{'fullname'};
			}
		if ($b->{'fullname'} =~ /(\S+)\.(\d+)/) {
			my ($k, $v) = split(/\./, $b->{'fullname'});
			$b->{'physical'} = $k;
			$b->{'vlanid'} = $v;
			$b->{'vlan'} = 1;
			}
		$b->{'up'} = defined($conf{'ONPARENT'}) &&
			     $b->{'virtual'} ne '' ?
				($conf{'ONPARENT'} eq 'yes') :
				($conf{'ONBOOT'} eq 'yes');
		$b->{'address'} = $conf{'IPADDR'} || $conf{'IPADDR0'};
		$b->{'netmask'} = $conf{'NETMASK'} || $conf{'NETMASK0'};
		if (!$conf{'NETMASK'} && $conf{'PREFIX'}) {
			$b->{'netmask'} = &prefix_to_mask($conf{'PREFIX'});
			}
		elsif (!$conf{'NETMASK'} && $conf{'PREFIX0'}) {
			$b->{'netmask'} = &prefix_to_mask($conf{'PREFIX0'});
			}
		$b->{'broadcast'} = $conf{'BROADCAST'};
		if (!$b->{'broadcast'} && $b->{'address'} && $b->{'netmask'}) {
			$b->{'broadcast'} = &compute_broadcast($b->{'address'},
							       $b->{'netmask'});
			}
		$b->{'gateway'} = $conf{'GATEWAY'};
		$b->{'gateway6'} = $conf{'IPV6_DEFAULTGW'};
		$b->{'mtu'} = $conf{'MTU'};
		if ($b->{'fullname'} =~ /^bond/) {
			$b->{'partner'} = &get_teaming_partner($conf{'DEVICE'});
			}
                my @values = split(/\s+/, $conf{'BONDING_OPTS'});
                foreach my $val (@values) {
                         my ($k, $v) = split(/=/, $val, 2);
				if ($k eq "mode") {
					$b->{'mode'} = $v;
					}
				elsif ($k eq "miimon") {
					$b->{'miimon'} = $v;
					}
				elsif ($k eq "updelay") {
					$b->{'updelay'} = $v;
					}
				elsif ($k eq "downdelay") {
					$b->{'downdelay'} = $v;
					}
                        }
		$b->{'ether'} = $conf{'MACADDR'};
		$b->{'dhcp'} = ($conf{'BOOTPROTO'} eq 'dhcp');
		$b->{'bootp'} = ($conf{'BOOTPROTO'} eq 'bootp');
		local @ip6s;
		push(@ip6s, [ split(/\//, $conf{'IPV6ADDR'}) ])
			if ($conf{'IPV6ADDR'});
		push(@ip6s, map { [ split(/\//, $_) ] }
				split(/\s+/, $conf{'IPV6ADDR_SECONDARIES'}));
		if (@ip6s) {
			# Static IPv6 addresses
			$b->{'address6'} = [ map { $_->[0] } @ip6s ];
			$b->{'netmask6'} = [ map { $_->[1] } @ip6s ];
			}
		elsif (lc($conf{'IPV6INIT'}) eq 'yes') {
			$b->{'auto6'} = 1;
			}
		$b->{'edit'} = ($b->{'name'} !~ /^ppp|irlan/);
		$b->{'desc'} = $conf{'NAME'};
		$b->{'index'} = scalar(@rv);
		$b->{'file'} = "$net_scripts_dir/$f";
		if ($conf{'BRIDGE'}) {
			$bridge_map{$conf{'BRIDGE'}} = $b->{'fullname'};
			}
		push(@rv, $b);
		}
	}
closedir(CONF);
foreach my $b (@rv) {
	if ($b->{'fullname'} =~ /^br\d+$/) {
		$b->{'bridge'} = 1;
		$b->{'bridgeto'} = $bridge_map{$b->{'fullname'}};
		}
	}
return @rv;
}

# save_bond_interface(device, master)
# Create or update a boot-time bond slave interface
sub save_bond_interface
{
local(%conf);
&lock_file("$net_scripts_dir/ifcfg-$_[0]");
$conf{'DEVICE'} = $_[0];
$conf{'BOOTPROTO'} = none;
$conf{'ONBOOT'} = yes;
$conf{'MASTER'} = $_[1];
$conf{'SLAVE'} = "yes";
$conf{'USERCTL'} = "no";
&write_env_file("$net_scripts_dir/ifcfg-$_[0]", \%conf);
&unlock_file("$net_scripts_dir/ifcfg-$_[0]");
}

# save_interface(&details)
# Create or update a boot-time interface
sub save_interface
{
my ($b) = @_;
local(%conf);
local $name = $b->{'range'} ne "" ? $b->{'name'}."-range".$b->{'range'} :
	      $b->{'virtual'} ne "" ? $b->{'name'}.":".$b->{'virtual'} :
	      $b->{'vlanid'} ne "" ? $b->{'physical'}.".".$b->{'vlanid'}
				       : $b->{'name'};
my $file = $b->{'file'} || "$net_scripts_dir/ifcfg-$name";
&lock_file($file);
&read_env_file($file, \%conf);
if ($b->{'range'} ne "") {
	# Special case - saving a range
	$conf{'IPADDR_START'} = $b->{'start'};
	$conf{'IPADDR_END'} = $b->{'end'};
	$conf{'CLONENUM_START'} = $b->{'num'};
	}
else {
	# Saving a normal interface
	$conf{'DEVICE'} = $name;
	my $pfx = $conf{'IPADDR0'} ? '0' : '';
	$conf{'IPADDR'.$pfx} = $b->{'address'};
	$conf{'NETMASK'.$pfx} = $b->{'netmask'};
	delete($conf{'PREFIX'.$pfx});
	if ($b->{'address'} && $b->{'netmask'}) {
		$conf{'NETWORK'.$pfx} = &compute_network($b->{'address'},
						         $b->{'netmask'});
		}
	else {
		$conf{'NETWORK'.$pfx} = '';
		}
	$conf{'BROADCAST'.$pfx} = $b->{'broadcast'};
	if ($b->{'gateway'}) {
		$conf{'GATEWAY'} = $b->{'gateway'};
		}
	else {
		delete($conf{'GATEWAY'});
		}
	if ($b->{'gateway6'}) {
		$conf{'IPV6_DEFAULTGW'} = $b->{'gateway6'};
		}
	else {
		delete($conf{'IPV6_DEFAULTGW'});
		}
	$conf{'MTU'} = $b->{'mtu'};
	$conf{'MACADDR'} = $b->{'ether'};
	$conf{'ONBOOT'} = $b->{'up'} ? "yes" : "no";
	$conf{'ONPARENT'} = $b->{'up'} ? "yes" : "no"
		if ($b->{'virtual'} ne '');
	$conf{'BOOTPROTO'} = $b->{'bootp'} ? "bootp" :
			     $b->{'dhcp'} ? "dhcp" : "none";
	delete($conf{'IPV6ADDR'});
	delete($conf{'IPV6ADDR_SECONDARIES'});
	local @ip6s;
	for(my $i=0; $i<@{$b->{'address6'}}; $i++) {
		push(@ip6s, $b->{'address6'}->[$i]."/".
			    $b->{'netmask6'}->[$i]);
		}
	if ((@ip6s || $b->{'auto6'}) && lc($conf{'IPV6INIT'}) ne 'yes') {
		$conf{'IPV6INIT'} = 'yes';
		}
	elsif (!@ip6s && !$b->{'auto6'}) {
		$conf{'IPV6INIT'} = 'no';
		}
	if (@ip6s) {
		$conf{'IPV6ADDR'} = shift(@ip6s);
		$conf{'IPV6ADDR_SECONDARIES'} = join(" ", @ip6s);
		}
	if ($b->{'fullname'} =~ /^br(\d+)$/) {
		&has_command("brctl") ||
			&error("Bridges cannot be created unless the brctl ".
			       "command is installed");
		$conf{'TYPE'} = 'Bridge';
		}
	if ($b->{'fullname'} =~ /^bond(\d+)$/) {
		$conf{'BONDING_OPTS'} = "mode=$b->{'mode'}";
		if ($b->{'miimon'}) {
			$conf{'BONDING_OPTS'} .= " miimon=$b->{'miimon'}";
			}
		if ($b->{'updelay'}) {
			$conf{'BONDING_OPTS'} .= " updelay=$b->{'updelay'}";
			}
		if ($b->{'downdelay'}) {
			$conf{'BONDING_OPTS'} .= " downdelay=$b->{'downdelay'}";
			}

		my @values = split(/\s+/, $b->{'partner'});
		foreach my $val (@values) {
			&save_bond_interface($val, $b->{'fullname'});
			}
		}
	if ($b->{'vlan'} == 1) {
		$conf{'VLAN'} = "yes";
		}
	}
$conf{'NAME'} = $b->{'desc'};
if (!-r $file) {
	# New interfaces shouldn't be controller by network manager
	$conf{'NM_CONTROLLED'} = 'no';
	}
&write_env_file($file, \%conf);

# If this is a bridge, set BRIDGE in real interface
if ($b->{'bridge'}) {
	foreach my $efile (glob("$net_scripts_dir/ifcfg-e*")) {
		local %bconf;
		&lock_file($efile);
		&read_env_file($efile, \%bconf);
		if ($bconf{'DEVICE'} eq $b->{'bridgeto'} &&
		    $b->{'bridgeto'}) {
			# Correct device for bridge
			$bconf{'BRIDGE'} = $b->{'fullname'};
			&write_env_file($efile, \%bconf);
			}
		elsif ($bconf{'BRIDGE'} eq $b->{'fullname'} &&
		       $bconf{'BRIDGE'}) {
			# Was using this bridge, shouldn't be
			delete($bconf{'BRIDGE'});
			&write_env_file($efile, \%bconf);
			}
		&unlock_file($efile);
		}
	}

# Link to devices directory
if (-d &translate_filename($devices_dir)) {
	&link_file($file, "$devices_dir/ifcfg-$name");
	}
&unlock_file($file);

# Make sure IPv6 is enabled globally
if (@{$b->{'address6'}}) {
	local %conf;
	&lock_file($network_config);
	&read_env_file($network_config, \%conf);
	if (lc($conf{'NETWORKING_IPV6'}) ne 'yes') {
		$conf{'NETWORKING_IPV6'} = 'yes';
		&write_env_file($network_config, \%conf);
		}
	&unlock_file($network_config);
	}
}

# delete_interface(&details)
# Delete a boot-time interface
sub delete_interface
{
my ($b) = @_;
local $name = $b->{'range'} ne "" ? $b->{'name'}."-range".
				    $b->{'range'} :
	      $b->{'virtual'} ne "" ? $b->{'name'}.":".$b->{'virtual'}
				    : $b->{'name'};
my $file = $b->{'file'} || "$net_scripts_dir/ifcfg-$name";
&lock_file($file);
&unlink_file("$net_scripts_dir/ifcfg-$name");
if (-d &translate_filename($devices_dir)) {
	&unlink_file("$devices_dir/ifcfg-$name");
	}
&unlock_file($file);
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

# If any ifcfg-XXX files have the old hostname in DHCP_HOSTNAME, fix it
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

# Update /etc/hostname if exists
if (-r "/etc/hostname") {
	&open_lock_tempfile(HOST, ">/etc/hostname");
	&print_tempfile(HOST, $_[0],"\n");
	&close_tempfile(HOST);
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
	foreach my $dir ($devices_dir, $net_scripts_dir) {
		opendir(DIR, &translate_filename($dir));
		while(my $f = readdir(DIR)) {
			if ($f =~ /^([a-z]+\d*(\.\d+)?(:\d+)?)\.route$/ ||
			    $f =~ /^route\-([a-z]+\d*(\.\d+)?(:\d+)?)$/) {
				push(@rv, "$dir/$f");
				}
			}
		closedir(DIR);
		}
	}
return @rv;
}

sub network_config_files
{
return ( "/etc/HOSTNAME", $network_config );
}

sub routing_input
{
local (%conf, @st, @hr, %sysctl);
&read_env_file($network_config, \%conf);
if (!$supports_dev_gateway) {
	# show default router and device
	print &ui_table_row($text{'routes_default'},
		&ui_opt_textbox("gateway", $conf{'GATEWAY'}, 15,
				$text{'routes_none'}));

	print &ui_table_row($text{'routes_device2'},
		&ui_opt_textbox("gatewaydev", $conf{'GATEWAYDEV'}, 6,
			        $text{'routes_none'}));
	}
else {
	# multiple default routers can exist, one per interface
	my @table;
	local $r = 0;
	if ($conf{'GATEWAY'} || $conf{'IPV6_DEFAULTGW'}) {
		push(@table, [
		    &interface_sel("gatewaydev$r",
				   $conf{'GATEWAYDEV'} ||
				     $conf{'IPV6_DEFAULTDEV'} || "*"),
		    &ui_textbox("gateway$r", $conf{'GATEWAY'}, 15),
		    &ui_textbox("gateway6$r", $conf{'IPV6_DEFAULTGW'}, 30),
		    ]);
		$r++;
		}
	local @boot = &boot_interfaces();
	foreach $b (grep { $_->{'gateway'} && $_->{'virtual'} eq '' } @boot) {
		push(@table, [ &interface_sel("gatewaydev$r", $b->{'name'}),
			       &ui_textbox("gateway$r", $b->{'gateway'}, 15),
			       &ui_textbox("gateway6$r", $b->{'gateway6'}, 30),
			     ]);
		$r++;
		}
	push(@table, [ &interface_sel("gatewaydev$r"),
		       &ui_textbox("gateway$r", undef, 15),
		       &ui_textbox("gateway6$r", undef, 30), ]);
	print &ui_table_row($text{'routes_default2'},
		&ui_columns_table(
			[ $text{'routes_ifc'}, $text{'routes_gateway'},
			  $text{'routes_gateway6'} ],
			undef, \@table, undef, 1));
	}

# show routing
if ($gconfig{'os_version'} < 7.0) {
	print &ui_table_row($text{'routes_forward'},
		&ui_yesno_radio("forward",
				$conf{'FORWARD_IPV4'} eq "yes" ? 1 : 0));
	}
else {
	&read_env_file($sysctl_config, \%sysctl);
	print &ui_table_row($text{'routes_forward'},
		&ui_yesno_radio("forward",
				$sysctl{'net.ipv4.ip_forward'} ? 1 : 0));
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
	opendir(DIR, &translate_filename($route_files_dir));
	while($f = readdir(DIR)) {
		if ($f =~ /^([a-z]+\d*(\.\d+)?(:\d+)?)\.route$/ ||
		    $f =~ /^route\-([a-z]+\d*(\.\d+)?(:\d+)?)$/) {
			local $dev = $1;
			local (%rfile, $i);
			&read_env_file("$route_files_dir/$f", \%rfile);
			for($i=0; defined($rfile{"ADDRESS$i"}); $i++) {
				if ($rfile{"GATEWAY$i"}) {
					push(@st, [ $dev, $rfile{"ADDRESS$i"},
							  $rfile{"NETMASK$i"},
							  $rfile{"GATEWAY$i"}]);
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

# Show static network routes
my @table;
for($i=0; $i<=@st; $i++) {
	local $st = $st[$i];
	push(@table, [ &ui_textbox("dev_$i", $st->[0], 6),
		       &ui_textbox("net_$i", $st->[1], 15),
		       &ui_textbox("netmask_$i", $st->[2], 15),
		       &ui_textbox("gw_$i", $st->[3], 15) ]);
	}
print &ui_table_row($text{'routes_static'},
	&ui_columns_table([ $text{'routes_ifc'}, $text{'routes_net'},
			    $text{'routes_mask'}, $text{'routes_gateway'} ],
			  undef, \@table, undef, 1));

# Show static host routes
my @table;
for($i=0; $i<=@hr; $i++) {
	local $st = $hr[$i];
	push(@table, [ &ui_textbox("ldev_$i", $st->[0], 6),
		       &ui_textbox("lnet_$i", $st->[1], 15),
		       &ui_textbox("lnetmask_$i", $st->[2], 15) ]);
	}
print &ui_table_row($text{'routes_local'},
	&ui_columns_table([ $text{'routes_ifc'}, $text{'routes_net'},
			    $text{'routes_mask'} ],
			  undef, \@table, undef, 1));
}

sub parse_routing
{
local (%conf, @st, %sysctl, %st, @boot);
&lock_file($network_config);
&read_env_file($network_config, \%conf);
if (!$supports_dev_gateway) {
	# Just update a single file
	if ($in{'gateway_def'}) { delete($conf{'GATEWAY'}); }
	elsif (!&to_ipaddress($in{'gateway'})) {
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
	delete($conf{'IPV6_DEFAULTDEV'});
	delete($conf{'IPV6_DEFAULTGW'});

	for($r=0; defined($in{"gatewaydev$r"}); $r++) {
		next if (!$in{"gatewaydev$r"});
		&check_ipaddress($in{"gateway$r"}) ||
			&error(&text('routes_edefault2', $r+1));
		if ($in{"gatewaydev$r"} eq "*") {
			# For any interface
			$conf{'GATEWAY'} && &error(&text('routes_eclash'));
			$conf{'GATEWAY'} = $in{"gateway$r"};
			$conf{'IPV6_DEFAULTGW'} &&
				&error(&text('routes_eclash6'));
			$conf{'IPV6_DEFAULTGW'} = $in{"gateway6$r"};
			}
		else {
			# For a specific interface
			local ($b) = grep { $_->{'fullname'} eq
					    $in{"gatewaydev$r"} } @boot;
			$b->{'gateway'} && &error(&text('routes_eclash2',
							$in{"gatewaydev$r"}));
			$b->{'gateway'} = $in{"gateway$r"};
			$b->{'gateway6'} = $in{"gateway6$r"};
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
	&to_ipaddress($net) || &error(&text('routes_enet', $net));
	&check_ipaddress($netmask) || &error(&text('routes_emask', $netmask));
	&to_ipaddress($gw) || &error(&text('routes_egateway', $gw));
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
	&to_ipaddress($net) ||
	    $net =~ /^(\S+)\/(\d+)$/ && &to_ipaddress("$1") ||
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
	opendir(DIR, &translate_filename($route_files_dir));
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
		&lock_file("$route_files_dir/$f");
		&write_env_file("$route_files_dir/$f", \%rfile);
		&unlock_file("$route_files_dir/$f");
		if ($route_files_dir ne $net_scripts_dir) {
			&lock_file("$net_scripts_dir/$f");
			&link_file("$route_files_dir/$f",
				   "$net_scripts_dir/$f");
			&unlock_file("$net_scripts_dir/$f");
			}
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

# interface_sel(name, value)
# Returns a menu for all boot-time interfaces
sub interface_sel
{
local ($name, $value) = @_;
local @opts = ( [ "", "&nbsp;" ],
		[ "*", $text{'routes_any'} ] );
@boot_interfaces_cache = sort { $a->{'fullname'} cmp $b->{'fullname'} }
	&boot_interfaces() if (!@boot_interfaces_cache);
foreach $b (@boot_interfaces_cache) {
	push(@opts, [ $b->{'fullname'}, $b->{'fullname'} ]);
	}
return &ui_select($name, $value, \@opts);
}

# apply_network()
# Apply the interface and routing settings
sub apply_network
{
if ($gconfig{'os_type'} eq 'mandrake-linux') {
	&system_logged("(cd / ; service network stop ; service network start) >/dev/null 2>&1");
	}
else {
	&system_logged("(cd / ; /etc/init.d/network stop ; /etc/init.d/network start) >/dev/null 2>&1");
	}
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

# get_default_ipv6_gateway()
# Returns the default gateway IPv6 address (if one is set) and device (if set)
# boot time settings.
sub get_default_ipv6_gateway
{
local %conf;
&read_env_file($network_config, \%conf);
local @boot = &boot_interfaces();
local ($gifc) = grep { $_->{'gateway6'} && $_->{'virtual'} eq '' } @boot;
return ( $gifc->{'gateway6'}, $gifc->{'fullname'} ) if ($gifc);
return $conf{'IPV6_DEFAULTGW'} ? ( $conf{'IPV6_DEFAULTGW'},
				   $conf{'IPV6_DEFAULTDEV'} ) : ( );
}

# set_default_ipv6_gateway(gateway, device)
# Sets the default gateway to the given IPv6 address accessible via the given
# device, in the boot time settings.
sub set_default_ipv6_gateway
{
&lock_file($network_config);
&read_env_file($network_config, \%conf);
local @boot = grep { $->{'virtual'} eq '' } &boot_interfaces();
foreach $b (@boot) {
	delete($b->{'gateway6'});
	if ($_[0] && $b->{'fullname'} eq $_[1]) {
		$b->{'gateway6'} = $_[0];
		&save_interface($b);
		}
	}
delete($conf{'IPV6_DEFAULTGW'});
delete($conf{'IPV6_DEFAULTDEV'});
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

sub supports_bonding
{
return $gconfig{'os_type'} eq 'redhat-linux' &&
       $gconfig{'os_version'} >= 13.0 &&
       &has_command("ifenslave");
}

sub supports_vlans
{
return $gconfig{'os_type'} eq 'redhat-linux' &&
	$gconfig{'os_version'} >= 13.0 &&
	&has_command("vconfig");
}


# range_input([&interface])
# Print HTML for a IP range interface
sub range_input
{
local $new = !$_[0];

# Range description
print &ui_table_row($text{'ifcs_desc'},
	&ui_textbox("desc", $_[0] ? $_[0]->{'desc'} : undef, 60));

# Base interface
my $ifaceinput;
if ($new) {
	$ifaceinput = &ui_select("iface", $_[0]->{'name'},
		[ map { $_->{'fullname'} } grep { $b->{'virtual'} eq '' }
		      &boot_interfaces() ]);
	}
else {
	$ifaceinput = "<tt>$_[0]->{'name'}</tt>";
	}
print &ui_table_row($text{'range_iface'}, $ifaceinput);

# Name for this range
print &ui_table_row($text{'range_name'},
	$new ? &ui_textbox("range", undef, 10)
	     : "<tt>$_[0]->{'range'}</tt>");

# Start
print &ui_table_row($text{'range_start'},
	&ui_textbox("start", $_[0]->{'start'}, 15));

# Stop
print &ui_table_row($text{'range_end'},
	&ui_textbox("end", $_[0]->{'end'}, 15));

# Base number
print &ui_table_row($text{'range_num'},
	&ui_textbox("num", $_[0]->{'num'}, 5));
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
$_[0]->{'desc'} = $in{'desc'};

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
local ($eth) = grep { $_->{'fullname'} =~ /^(eth|em)\d+$/ } @boot;
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

# get_teaming_partner(devicename)
# Gets the teamingpartners of a configured bond interface
sub get_teaming_partner
{
local ($g, $return);
opendir(CONF2, &translate_filename($net_scripts_dir));
while($g = readdir(CONF2)) {
        local %conf2;
        if ($g !~ /\.(bak|old)$/i && $g =~ /^ifcfg-([a-z0-9:\.]+)$/) {
                &read_env_file("$net_scripts_dir/$g", \%conf2);
                if ($conf2{'MASTER'} eq "$_[0]") {
			$return .= $conf2{'DEVICE'}." ";
                	}
        	}
	}
return $return;
}

sub boot_iface_hardware
{
return $_[0] =~ /^(eth|em)/;
}

# supports_address6([&iface])
# Returns 1 if managing IPv6 interfaces is supported
sub supports_address6
{
local ($iface) = @_;
return !$iface || $iface->{'virtual'} eq '';
}

# Returns 1, as boot-time interfaces on Redhat can exist without an IP (such as
# for bridging)
sub supports_no_address
{
return 1;
}

# Bridge interfaces can be created on redhat
sub supports_bridges
{
return 1;
}

# os_save_dns_config(&config)
# Updates DNSx lines in all network-scripts files that have them
sub os_save_dns_config
{
local ($conf) = @_;
foreach my $b (&boot_interfaces()) {
	local %ifc;
	&read_env_file($b->{'file'}, \%ifc);
	next if (!defined($ifc{'DNS1'}));
	&lock_file($b->{'file'});
	foreach my $k (keys %ifc) {
		delete($ifc{$k}) if ($k =~ /^DNS\d+$/);
		}
	&write_env_file($b->{'file'}, \%ifc);
	local $i = 1;
	foreach my $ns (@{$conf->{'nameserver'}}) {
		$ifc{'DNS'.$i} = $ns;
		$i++;
		}
	if (!@{$conf->{'nameserver'}}) {
		# Add an empty DNS1 line so that we know to update this file
		# later if DNS resolves come back
		$ifc{'DNS1'} = ''
		}
	&write_env_file($b->{'file'}, \%ifc);
	&unlock_file($b->{'file'});
	}
return (0, 0);
}

1;

