# united-linux-lib.pl
# Networking functions for united linux

$net_scripts_dir = "/etc/sysconfig/network";
$routes_config = "/etc/sysconfig/network/routes";
$sysctl_config = "/etc/sysconfig/sysctl";

do 'linux-lib.pl';

# boot_interfaces()
# Returns a list of interfaces brought up at boot time
sub boot_interfaces
{
local(@rv, $f);
opendir(CONF, &translate_filename($net_scripts_dir));
while($f = readdir(CONF)) {
	next if ($f !~ /^ifcfg-([a-z0-9:\.]+)$/);
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
	$b->{'edit'} = ($b->{'name'} !~ /^ppp|irlan/);
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
$conf{'UNIQUE'} = time();
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
return $_[0] ne "mtu" && $_[0] ne "bootp";
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
return ( $routes_config, $sysctl_config );
}

sub routing_input
{
local (@routes, $i);
&open_readfile(ROUTES, $routes_config);
while(<ROUTES>) {
	s/#.*$//;
	s/\r|\n//g;
	local @r = map { $_ eq '-' ? undef : $_ } split(/\s+/, $_);
	push(@routes, \@r) if (@r);
	}
close(ROUTES);

# show default router and device
local ($def) = grep { $_->[0] eq "default" } @routes;
print &ui_table_row($text{'routes_default'},
        &ui_opt_textbox("gateway", $def->[1], 15, $text{'routes_none'}));

print &ui_table_row($text{'routes_device2'},
        &ui_opt_textbox("gatewaydev", $def->[3], 6, $text{'routes_none'}));

# Forwarding enabled?
&read_env_file($sysctl_config, \%sysctl);
print &ui_table_row($text{'routes_forward'},
        &ui_yesno_radio("forward", $sysctl{'IP_FORWARD'} eq 'yes'));

# show static network routes
my $i = 0;
my @table;
foreach my $r (@routes, [ ]) {
        next if ($r eq $def);
        push(@table, [ &ui_textbox("dev_$i", $r->[3], 6),
                       &ui_textbox("net_$i", $r->[0], 15),
                       &ui_textbox("netmask_$i", $r->[2], 15),
                       &ui_textbox("gw_$i", $r->[1], 15),
                       &ui_textbox("type_$i", $r->[4], 10) ]);
        }
print &ui_table_row($text{'routes_static'},         &ui_columns_table([ $text{'routes_ifc'}, $text{'routes_net'},
                            $text{'routes_mask'}, $text{'routes_gateway'},
                            $text{'routes_type'} ],
                          undef, \@table, undef, 1));
}

sub parse_routing
{
# Parse route inputs
local (@routes, $r, $i);
if (!$in{'gateway_def'}) {
	&to_ipaddress($in{'gateway'}) ||
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
&open_tempfile(ROUTES, ">$routes_config");
foreach $r (@routes) {
	&print_tempfile(ROUTES,join(" ", map { $_ eq '' ? "-" : $_ } @$r),"\n");
	}
&close_tempfile(ROUTES);
local $lref = &read_file_lines($sysctl_config);
for($i=0; $i<@$lref; $i++) {
	if ($lref->[$i] =~ /^\s*IP_FORWARD\s*=/) {
		$lref->[$i] = "IP_FORWARD=".($in{'forward'} ? "yes" : "no");
		}
	}
&flush_file_lines();
}

# apply_network()
# Apply the interface and routing settings
sub apply_network
{
&system_logged("(cd / ; /etc/init.d/network stop ; /etc/init.d/network start) >/dev/null 2>&1");
}

# supports_address6([&iface])
# Returns 1 if managing IPv6 interfaces is supported
sub supports_address6
{
local ($iface) = @_;
return 0;
}

1;

