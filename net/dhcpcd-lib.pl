# Networking functions for dhcpcd

$dhcpcd_config = "/etc/dhcpcd.conf";
$sysctl_config = "/etc/sysctl.conf";

do 'linux-lib.pl';

# boot_interfaces()
# Returns a list of all interfaces configured in dhcpcd.conf
sub boot_interfaces
{
my $cfg = &read_dhcpcd_config($dhcpcd_config);
my @rv;
foreach my $block (@$cfg) {
	# Only interface blocks map to Webmin boot-time interfaces.
	next if ($block->{'type'} ne 'interface');
	my $iface = { 'name' => $block->{'name'},
		      'fullname' => $block->{'name'},
		      'virtual' => '',
		      'file' => $dhcpcd_config,
		      'block' => $block,
		      'edit' => 1,
		      'up' => 1,
		      'address6' => [ ],
		      'netmask6' => [ ] };

	# The first static ip_address is the primary IPv4 address.
	my @ip4 = &dhcpcd_values($block, "ip_address");
	if (@ip4) {
		my ($addr, $prefix) = split(/\//, $ip4[0]);
		$iface->{'address'} = $addr;
		$iface->{'netmask'} = $prefix ? &prefix_to_mask($prefix) : undef;

		# Extra static ip_address directives become Webmin virtual aliases.
		for(my $i=1; $i<@ip4; $i++) {
			my ($vaddr, $vprefix) = split(/\//, $ip4[$i]);
			push(@rv, { 'name' => $iface->{'name'},
				    'fullname' => $iface->{'name'}.":".($i-1),
				    'virtual' => $i-1,
				    'file' => $dhcpcd_config,
				    'block' => $block,
				    'edit' => 1,
				    'up' => 1,
				    'address' => $vaddr,
				    'netmask' => $vprefix ?
					&prefix_to_mask($vprefix) : undef });
			}
		}
	else {
		# dhcpcd uses DHCP when no static ip_address is configured.
		$iface->{'dhcp'} = 1;
		}

	# Parse gateways and static IPv4 routes from dhcpcd's static keys.
	my ($routers) = &dhcpcd_values($block, "routers");
	($iface->{'gateway'}) = split(/\s+/, $routers) if ($routers);
	my ($routes) = &dhcpcd_values($block, "routes");
	if ($routes) {
		my @r = split(/\s+/, $routes);
		while(@r >= 2) {
			my $dest = shift(@r);
			my $gw = shift(@r);
			push(@{$iface->{'routes'}}, "$dest,$gw");
			}
		}

	# DNS servers and search domains live inside the interface block.
	my ($ns) = &dhcpcd_values($block, "domain_name_servers");
	$iface->{'nameserver'} = [ split(/\s+/, $ns) ] if ($ns);
	my ($search) = &dhcpcd_values($block, "domain_search");
	$search ||= (&dhcpcd_values($block, "domain_name"))[0];
	$iface->{'search'} = [ split(/\s+/, $search) ] if ($search);

	# IPv6 addresses and router settings use separate dhcpcd directives.
	foreach my $ip6 (&dhcpcd_values($block, "ip6_address")) {
		my ($addr, $prefix) = split(/\//, $ip6);
		push(@{$iface->{'address6'}}, $addr);
		push(@{$iface->{'netmask6'}}, $prefix || 64);
		}
	my ($routers6) = &dhcpcd_values($block, "ip6_routers");
	($iface->{'gateway6'}) = split(/\s+/, $routers6) if ($routers6);
	my ($mtu) = &dhcpcd_plain_values($block, "mtu");
	$iface->{'mtu'} = $mtu if ($mtu);

	push(@rv, $iface);
	}

# Default dhcpcd setups may manage DHCP interfaces without explicit blocks.
push(@rv, &dhcpcd_implicit_interfaces($cfg, \@rv));
@rv = sort { $a->{'fullname'} cmp $b->{'fullname'} } @rv;
for(my $i=0; $i<@rv; $i++) {
	$rv[$i]->{'index'} = $i;
	}
return @rv;
}

# save_interface(&iface, [&all-interfaces])
# Create or update a dhcpcd interface block
sub save_interface
{
my ($iface, $boot) = @_;
$boot ||= [ &boot_interfaces() ];
if ($iface->{'virtual'} ne '') {
	# Virtual aliases are stored as extra ip_address lines on the parent.
	my ($parent) = grep { $_->{'fullname'} eq $iface->{'name'} } @$boot;
	$parent || &error("No interface named $iface->{'name'} exists");
	if (!$iface->{'block'}) {
		push(@$boot, $iface);
		}
	else {
		# Replace the existing alias in the in-memory boot list.
		my ($oldiface) = grep { $_->{'fullname'} eq $iface->{'fullname'} } @$boot;
		$oldiface || &error("No existing interface named $iface->{'fullname'} found");
		$boot->[$oldiface->{'index'}] = $iface;
		}
	&save_interface($parent, $boot);
	return;
	}

my $cfg = &read_dhcpcd_config($dhcpcd_config);
my ($old) = grep { $_->{'type'} eq 'interface' &&
		   $_->{'name'} eq $iface->{'fullname'} } @$cfg;
my @lines = &dhcpcd_interface_lines($iface, $boot);
&lock_file($dhcpcd_config);
my $lref = &read_file_lines($dhcpcd_config);
if ($old) {
	# Replace only the old interface block, preserving file-level comments.
	splice(@$lref, $old->{'line'}, $old->{'eline'} - $old->{'line'} + 1,
	       @lines);
	}
else {
	# Append a new explicit block, used for first edits to implicit DHCP rows.
	push(@$lref, "") if (@$lref && $lref->[@$lref-1] =~ /\S/);
	push(@$lref, @lines);
	}

# Saving an interface means dhcpcd should no longer deny managing it.
&dhcpcd_delete_global_word($lref, "denyinterfaces", $iface->{'fullname'});

# If allowinterfaces is present, the saved interface must be included there.
&dhcpcd_add_global_word_if_exists($lref, "allowinterfaces",
				  $iface->{'fullname'});
&flush_file_lines($dhcpcd_config);
&unlock_file($dhcpcd_config);
}

# delete_interface(&iface)
# Remove a dhcpcd interface block, or one virtual address from it
sub delete_interface
{
my ($iface) = @_;
if ($iface->{'virtual'} ne '') {
	# Removing an alias means re-saving the parent without that address.
	my @boot = grep { $_->{'fullname'} ne $iface->{'fullname'} }
		   &boot_interfaces();
	my ($parent) = grep { $_->{'fullname'} eq $iface->{'name'} } @boot;
	$parent || &error("No interface named $iface->{'name'} exists");
	&save_interface($parent, \@boot);
	return;
	}
&lock_file($dhcpcd_config);
my $lref = &read_file_lines($dhcpcd_config);
my $block = $iface->{'block'};
if ($block) {
	# Explicit blocks can be removed directly.
	splice(@$lref, $block->{'line'}, $block->{'eline'} - $block->{'line'} + 1);

	# A deleted explicit block should be gone, not replaced by a deny.
	&dhcpcd_delete_global_word($lref, "denyinterfaces",
				   $iface->{'fullname'});
	}
else {
	# Implicit DHCP interfaces need a deny line, or they reappear.
	&dhcpcd_add_global_word($lref, "denyinterfaces",
				 $iface->{'fullname'});
	}
&flush_file_lines($dhcpcd_config);
&unlock_file($dhcpcd_config);
}

# can_edit(setting, [&iface])
# Returns true if a boot-time interface setting can be edited
sub can_edit
{
my ($what) = @_;
return $what !~ /^(up|bootp|broadcast|ether|bridgestp|bridgefd|bridgewait)$/;
}

# can_broadcast_def()
# Returns true if broadcast address can be left to the OS
sub can_broadcast_def
{
return 1;
}

# valid_boot_address(address)
# Returns true if an IPv4 or IPv6 boot-time address is valid
sub valid_boot_address
{
return &check_ipaddress_any($_[0]);
}

# supports_address6([&iface])
# Returns true if this backend supports IPv6 addresses
sub supports_address6
{
return 1;
}

# supports_no_address([&iface])
# Returns true if this backend supports explicit no-address interfaces
sub supports_no_address
{
return 0;
}

# supports_bridges()
# Returns true if this backend can create persistent bridge devices
sub supports_bridges
{
return 0;
}

# supports_bonding()
# Returns true if this backend can create persistent bonded devices
sub supports_bonding
{
return 0;
}

# supports_vlans()
# Returns true if this backend can create persistent VLAN devices
sub supports_vlans
{
return 0;
}

# apply_network()
# Applies dhcpcd configuration by restarting the dhcpcd service
sub apply_network
{
&dhcpcd_remove_stale_virtual_addresses();
my $cmd = &has_command("systemctl") ? "systemctl restart dhcpcd" :
	  &has_command("service") ? "service dhcpcd restart" :
	  "/etc/init.d/dhcpcd restart";
my $out = &backquote_logged("$cmd 2>&1 </dev/null");
return $? ? $out || "$cmd failed" : undef;
}

# apply_interface(&iface)
# Applies one interface change by restarting dhcpcd
sub apply_interface
{
return "Cannot find device \"".&dhcpcd_apply_device($_[0])."\""
	if (!&dhcpcd_interface_exists($_[0]));
return &apply_network();
}

# unapply_interface(&iface)
# Applies one interface removal by restarting dhcpcd
sub unapply_interface
{
return &apply_network();
}

# unapply_interface_after_delete(&active, &boot)
# Applies one interface removal after its dhcpcd config has been deleted
sub unapply_interface_after_delete
{
my ($active, $boot) = @_;
# Apply after the file edit so dhcpcd sees the deleted address/block.
return &apply_network();
}

# delete_active_interface(&iface)
# Deactivates an active interface row under dhcpcd control
sub delete_active_interface
{
my ($active) = @_;
my @boot = &boot_interfaces();

if ($active->{'virtual'} ne '' && $active->{'address'}) {
	# dhcpcd can recreate configured aliases unless the config changes too.
	my ($boot) = grep { $_->{'virtual'} ne '' &&
			    &dhcpcd_address_key($_) eq
			    &dhcpcd_address_key($active) } @boot;
	if ($boot) {
		# Remove the persistent alias, then drop only the selected live IP.
		&delete_interface($boot);
		&deactivate_interface($active);
		return undef;
		}
	}

# Unmanaged or real active rows can still use the normal Linux action.
&deactivate_interface($active);
return undef;
}

# dhcpcd_remove_stale_virtual_addresses()
# Removes live virtual IPv4 addresses missing from dhcpcd boot config
sub dhcpcd_remove_stale_virtual_addresses
{
my @boot = &boot_interfaces();
my %managed;
my %wanted;
foreach my $iface (@boot) {
	if ($iface->{'virtual'} eq '') {
		# Only clean up live aliases on dhcpcd-managed parents.
		$managed{$iface->{'fullname'}} = 1;
		}
	elsif ($iface->{'address'}) {
		# Keep aliases that still exist in dhcpcd.conf.
		$wanted{&dhcpcd_address_key($iface)} = 1;
		}
	}
foreach my $active (&dhcpcd_active_interfaces()) {
	# Live aliases missing from boot config would survive a restart.
	next if ($active->{'virtual'} eq '' || !$active->{'address'});
	next if (!$managed{$active->{'name'}});
	next if ($wanted{&dhcpcd_address_key($active)});
	&deactivate_interface($active);
	}
}

# dhcpcd_address_key(&iface)
# Returns a stable parent/address key for comparing virtual IPv4 aliases
sub dhcpcd_address_key
{
my ($iface) = @_;
return join("\0", $iface->{'name'}, $iface->{'address'},
	    $iface->{'netmask'} || "");
}

# dhcpcd_apply_device(&iface)
# Returns the real device name needed to apply an interface config
sub dhcpcd_apply_device
{
my ($iface) = @_;
return $iface->{'virtual'} ne '' ? $iface->{'name'} :
       $iface->{'name'} || $iface->{'fullname'};
}

# dhcpcd_interface_exists(&iface)
# Returns true if the interface's real device exists right now
sub dhcpcd_interface_exists
{
my ($iface) = @_;
my $dev = &dhcpcd_apply_device($iface);
return grep { $_->{'fullname'} eq $dev || $_->{'name'} eq $dev }
       &dhcpcd_active_interfaces();
}

# routing_config_files()
# Returns files that affect boot-time routing
sub routing_config_files
{
return ( $dhcpcd_config, $sysctl_config );
}

# network_config_files()
# Returns files that affect hostname/domain network settings
sub network_config_files
{
return ( "/etc/hostname", "/etc/HOSTNAME", "/etc/mailname" );
}

# routing_input()
# Prints the boot-time routing form for dhcpcd
sub routing_input
{
my ($addr, $router) = &get_default_gateway();
my ($addr6, $router6) = &get_default_ipv6_gateway();
my @ifaces = grep { $_->{'virtual'} eq '' } &boot_interfaces();
my @inames = map { $_->{'name'} } @ifaces;

# Default IPv4 and IPv6 gateways are stored on one interface block.
print &ui_table_row($text{'routes_default'},
	&ui_radio("gateway_def", $addr ? 0 : 1,
		  [ [ 1, $text{'routes_none'} ],
		    [ 0, $text{'routes_gateway'}." ".
			 &ui_textbox("gateway", $addr, 15)." ".
			 &ui_select("gatewaydev", $router, \@inames) ] ]));

print &ui_table_row($text{'routes_default6'},
	&ui_radio("gateway6_def", $addr6 ? 0 : 1,
		  [ [ 1, $text{'routes_none'} ],
		    [ 0, $text{'routes_gateway'}." ".
			 &ui_textbox("gateway6", $addr6, 30)." ".
			 &ui_select("gatewaydev6", $router6, \@inames) ] ]));

# Static routes are stored as destination/gateway pairs per interface.
my @routes;
foreach my $iface (@ifaces) {
	foreach my $route (@{$iface->{'routes'} || [ ]}, "") {
		my ($dest, $gw) = split(/,/, $route, 2);
		push(@routes, [
			&ui_select("route_dev", $iface->{'name'}, \@inames),
			&ui_textbox("route_dest", $dest, 20),
			&ui_textbox("route_gw", $gw, 15),
			]);
		}
	}
push(@routes, [
	&ui_select("route_dev", undef, \@inames),
	&ui_textbox("route_dest", undef, 20),
	&ui_textbox("route_gw", undef, 15),
	]) if (!@ifaces);
print &ui_table_row($text{'routes_static'},
	&ui_columns_table([ $text{'routes_ifc'}, $text{'routes_dest'},
			    $text{'routes_gateway'} ], 100, 0, \@routes));

# Forwarding remains the standard Linux sysctl setting.
my %sysctl;
&read_env_file($sysctl_config, \%sysctl);
print &ui_table_row($text{'routes_forward'},
	&ui_yesno_radio("forward",
			$sysctl{'net.ipv4.ip_forward'} ? 1 : 0));
}

# parse_routing()
# Saves the boot-time routing form for dhcpcd
sub parse_routing
{
my @boot = &boot_interfaces();

# Save the default IPv4 route, clearing it from any other interface.
my ($dev, $gw);
if (!$in{'gateway_def'}) {
	&check_ipaddress($in{'gateway'}) ||
		&error(&text('routes_egateway', &html_escape($in{'gateway'})));
	$gw = $in{'gateway'};
	$dev = $in{'gatewaydev'};
	}
&set_default_gateway($gw, $dev, \@boot);

# Save the default IPv6 route in the same single-interface style.
my ($dev6, $gw6);
if (!$in{'gateway6_def'}) {
	&check_ip6address($in{'gateway6'}) ||
		&error(&text('routes_egateway6',&html_escape($in{'gateway6'})));
	$gw6 = $in{'gateway6'};
	$dev6 = $in{'gatewaydev6'};
	}
&set_default_ipv6_gateway($gw6, $dev6, \@boot);

# Rebuild static routes from the submitted rows.
foreach my $iface (@boot) {
	delete($iface->{'routes'});
	}
my @rdev = split(/\0/, $in{'route_dev'} || "");
my @rdest = split(/\0/, $in{'route_dest'} || "");
my @rgw = split(/\0/, $in{'route_gw'} || "");
for(my $i=0; $i<@rdest; $i++) {
	next if ($rdest[$i] eq '' && $rgw[$i] eq '');

	# Each route must point at an existing boot-time interface.
	my ($iface) = grep { $_->{'fullname'} eq $rdev[$i] } @boot;
	$iface || &error(&text('routes_edevice',
			       &html_escape($rdev[$i])));

	# dhcpcd static routes are IPv4 destination/gateway pairs here.
	&valid_dhcpcd_route_dest($rdest[$i]) ||
		&error(&text('routes_enet', &html_escape($rdest[$i])));
	&check_ipaddress($rgw[$i]) ||
		&error(&text('routes_egateway',
			     &html_escape($rgw[$i])));
	push(@{$iface->{'routes'}}, "$rdest[$i],$rgw[$i]");
	}

# Save all real interfaces so removed routes are written out too.
foreach my $iface (@boot) {
	next if ($iface->{'virtual'} ne '');
	&save_interface($iface, \@boot);
	}

# Save Linux IPv4 forwarding alongside the dhcpcd routing settings.
my %sysctl;
&lock_file($sysctl_config);
&read_env_file($sysctl_config, \%sysctl);
$sysctl{'net.ipv4.ip_forward'} = $in{'forward'};
&write_env_file($sysctl_config, \%sysctl);
&unlock_file($sysctl_config);
}

# get_hostname()
# Returns the system hostname
sub get_hostname
{
my $hn = &read_file_contents("/etc/hostname");
$hn =~ s/\r|\n//g;
return $hn if ($hn);
return &get_system_hostname();
}

# save_hostname(hostname)
# Sets the system hostname in common Linux hostname files
sub save_hostname
{
my ($hostname) = @_;
&system_logged("hostname ".quotemeta($hostname)." >/dev/null 2>&1");

# Update all hostname files that already exist on this system.
foreach my $f ("/etc/hostname", "/etc/HOSTNAME", "/etc/mailname") {
	if (-r $f) {
		&open_lock_tempfile(HOST, ">$f");
		&print_tempfile(HOST, $hostname,"\n");
		&close_tempfile(HOST);
		}
	}

# hostnamectl keeps systemd's transient/static hostname in sync.
if (&has_command("hostnamectl")) {
	&system_logged("hostnamectl set-hostname ".quotemeta($hostname).
		       " >/dev/null 2>&1");
	}
&get_system_hostname(undef, undef, 2);
}

# get_domainname()
# Returns the current NIS domain name
sub get_domainname
{
my $d;
&execute_command("domainname", undef, \$d, undef);
chop($d);
return $d;
}

# save_domainname(domain)
# Sets the current NIS domain name
sub save_domainname
{
my ($domain) = @_;
&execute_command("domainname ".quotemeta($domain));
}

# get_default_gateway()
# Returns the default IPv4 gateway and interface name
sub get_default_gateway
{
foreach my $iface (&boot_interfaces()) {
	return ( $iface->{'gateway'}, $iface->{'fullname'} )
		if ($iface->{'gateway'});
	}
return ( );
}

# set_default_gateway([gateway], [interface], [&boot-interfaces])
# Sets the default IPv4 gateway on one dhcpcd interface
sub set_default_gateway
{
my ($gw, $dev, $boot) = @_;
$boot ||= [ &boot_interfaces() ];
foreach my $iface (@$boot) {
	next if ($iface->{'virtual'} ne '');
	if ($iface->{'fullname'} eq $dev && $iface->{'gateway'} ne $gw) {
		# Add or update the gateway on the selected interface.
		$iface->{'gateway'} = $gw;
		&save_interface($iface, $boot);
		}
	elsif ($iface->{'fullname'} ne $dev && $iface->{'gateway'}) {
		# Remove old default gateways from all other interfaces.
		delete($iface->{'gateway'});
		&save_interface($iface, $boot);
		}
	}
}

# get_default_ipv6_gateway()
# Returns the default IPv6 gateway and interface name
sub get_default_ipv6_gateway
{
foreach my $iface (&boot_interfaces()) {
	return ( $iface->{'gateway6'}, $iface->{'fullname'} )
		if ($iface->{'gateway6'});
	}
return ( );
}

# set_default_ipv6_gateway([gateway], [interface], [&boot-interfaces])
# Sets the default IPv6 gateway on one dhcpcd interface
sub set_default_ipv6_gateway
{
my ($gw, $dev, $boot) = @_;
$boot ||= [ &boot_interfaces() ];
foreach my $iface (@$boot) {
	next if ($iface->{'virtual'} ne '');
	if ($iface->{'fullname'} eq $dev && $iface->{'gateway6'} ne $gw) {
		# Add or update the IPv6 gateway on the selected interface.
		$iface->{'gateway6'} = $gw;
		&save_interface($iface, $boot);
		}
	elsif ($iface->{'fullname'} ne $dev && $iface->{'gateway6'}) {
		# Remove old IPv6 default gateways from all other interfaces.
		delete($iface->{'gateway6'});
		&save_interface($iface, $boot);
		}
	}
}

# os_save_dns_config(&config)
# Saves DNS servers and search domains into dhcpcd interface blocks
sub os_save_dns_config
{
my ($conf) = @_;
my @boot = &boot_interfaces();
my $newns = @{$conf->{'nameserver'} || [ ]} ? $conf->{'nameserver'} : undef;
my $newsearch = @{$conf->{'domain'} || [ ]} ? $conf->{'domain'} : undef;

# Prefer updating interfaces that already have DNS; otherwise use all real ones.
my @fix = grep { $_->{'nameserver'} } @boot;
@fix = grep { $_->{'virtual'} eq '' } @boot if (!@fix);
my $need_apply = 0;
foreach my $iface (@fix) {
	# Skip unchanged interfaces to avoid needless dhcpcd restarts.
	next if (&dhcpcd_same_list($iface->{'nameserver'}, $newns) &&
		 &dhcpcd_same_list($iface->{'search'}, $newsearch));
	if ($newns) {
		$iface->{'nameserver'} = $newns;
		}
	else {
		delete($iface->{'nameserver'});
		}
	if ($newsearch) {
		$iface->{'search'} = $newsearch;
		}
	else {
		delete($iface->{'search'});
		}
	&save_interface($iface, \@boot);
	$need_apply = 1;
	}
return ($need_apply, 1);
}

# dhcpcd_same_list(&list1, &list2)
# Returns true if two optional array refs contain the same values
sub dhcpcd_same_list
{
my ($a, $b) = @_;
my @a = $a ? @$a : ( );
my @b = $b ? @$b : ( );
return 0 if (@a != @b);
for(my $i=0; $i<@a; $i++) {
	return 0 if ($a[$i] ne $b[$i]);
	}
return 1;
}

# read_dhcpcd_config(file)
# Parses dhcpcd.conf into global/interface/profile/ssid blocks
sub read_dhcpcd_config
{
my ($file) = @_;
my $lref = &read_file_lines($file);

# Global settings are represented as a synthetic first block.
my $cur = { 'type' => 'global',
	    'name' => '',
	    'line' => 0,
	    'eline' => -1,
	    'members' => [ ] };
my @rv = ( $cur );
for(my $i=0; $i<@$lref; $i++) {
	my $line = $lref->[$i];
	if ($line =~ /^\s*(interface|profile|ssid)\s+(\S+)/) {
		# New dhcpcd block starts; close the previous explicit block.
		$cur->{'eline'} = $i - 1 if ($cur);
		$cur = { 'type' => $1,
			 'name' => $2,
			 'line' => $i,
			 'eline' => $i,
			 'members' => [ ] };
		push(@rv, $cur);
		}
	else {
		# Blank/comment lines are not members but still belong to blocks.
		$cur->{'eline'} = $i if ($cur->{'type'} ne 'global');
		my $member = &dhcpcd_line_member($line, $i);
		push(@{$cur->{'members'}}, $member) if ($member);
		}
	}
return \@rv;
}

# dhcpcd_line_member(line, line-number)
# Parses one non-block dhcpcd.conf line into a member hash
sub dhcpcd_line_member
{
my ($line, $lnum) = @_;

# Strip comments and surrounding whitespace before classifying the line.
my $clean = $line;
$clean =~ s/#.*$//;
$clean =~ s/^\s+//;
$clean =~ s/\s+$//;
return undef if ($clean eq '');

# Static dhcpcd settings use "static name=value" syntax.
if ($clean =~ /^static\s+([^=\s]+)=(.*)$/) {
	return { 'static' => 1,
		 'name' => $1,
		 'value' => $2,
		 'line' => $lnum };
	}
elsif ($clean =~ /^(\S+)\s+(.*)$/) {
	# Plain settings usually use "name value" syntax.
	return { 'name' => $1,
		 'value' => $2,
		 'line' => $lnum };
	}
elsif ($clean =~ /^(\S+)$/) {
	# Flag settings such as noipv6rs have no value.
	return { 'name' => $1,
		 'value' => '',
		 'line' => $lnum };
	}
return undef;
}

# dhcpcd_values(&block, name)
# Returns all static values with the given name from a block
sub dhcpcd_values
{
my ($block, $name) = @_;
return map { $_->{'value'} }
       grep { $_->{'static'} && $_->{'name'} eq $name }
	    @{$block->{'members'}};
}

# dhcpcd_plain_values(&block, name)
# Returns all non-static values with the given name from a block
sub dhcpcd_plain_values
{
my ($block, $name) = @_;
return map { $_->{'value'} }
       grep { !$_->{'static'} && $_->{'name'} eq $name }
	    @{$block->{'members'}};
}

# dhcpcd_interface_lines(&iface, [&all-interfaces])
# Converts one Webmin boot interface into dhcpcd.conf lines
sub dhcpcd_interface_lines
{
my ($iface, $boot) = @_;
my @lines = ( "interface ".$iface->{'fullname'} );
my @keep;
if ($iface->{'block'}) {
	# Managed settings are regenerated; all other directives are preserved.
	my %replace = map { $_ => 1 }
		qw(ip_address routers domain_name_servers domain_search
		   domain_name ip6_address ip6_routers routes);
	foreach my $m (@{$iface->{'block'}->{'members'}}) {
		next if ($m->{'static'} && $replace{$m->{'name'}});
		next if (!$m->{'static'} && $m->{'name'} eq 'mtu');
		my $line = $m->{'static'} ?
			"static $m->{'name'}=$m->{'value'}" :
			$m->{'value'} eq '' ? $m->{'name'} :
					      "$m->{'name'} $m->{'value'}";
		push(@keep, $line);
		}
	}
push(@lines, @keep);

# Virtual aliases are stored as extra static ip_address directives.
my @vifaces = grep { $_->{'name'} eq $iface->{'name'} &&
		     $_->{'virtual'} ne '' } @$boot;
if ($iface->{'dhcp'} && !@vifaces) {
	# dhcpcd uses DHCP by default when no static ip_address is set.
	}
elsif ($iface->{'address'} || @vifaces) {
	# Write the primary static IPv4 address first, then aliases.
	my $prefix = $iface->{'netmask'} ?
		&mask_to_prefix($iface->{'netmask'}) : 24;
	push(@lines, "static ip_address=$iface->{'address'}/$prefix")
		if ($iface->{'address'});
	foreach my $viface (@vifaces) {
		my $vprefix = $viface->{'netmask'} ?
			&mask_to_prefix($viface->{'netmask'}) : $prefix;
		push(@lines, "static ip_address=$viface->{'address'}/$vprefix");
		}
	}

# Default gateway and static routes use separate dhcpcd directives.
if ($iface->{'gateway'}) {
	push(@lines, "static routers=$iface->{'gateway'}");
	}
if ($iface->{'routes'} && @{$iface->{'routes'}}) {
	my @routes;
	foreach my $route (@{$iface->{'routes'}}) {
		my ($dest, $gw) = split(/,/, $route, 2);
		push(@routes, $dest, $gw) if ($dest && $gw);
		}
	push(@lines, "static routes=".join(" ", @routes)) if (@routes);
	}

# DNS servers and search domains stay inside the interface block.
if ($iface->{'nameserver'} && @{$iface->{'nameserver'}}) {
	push(@lines, "static domain_name_servers=".
		     join(" ", @{$iface->{'nameserver'}}));
	}
if ($iface->{'search'} && @{$iface->{'search'}}) {
	push(@lines, "static domain_search=".join(" ", @{$iface->{'search'}}));
	}

# IPv6 static addresses and gateway are written after IPv4 settings.
for(my $i=0; $i<@{$iface->{'address6'}}; $i++) {
	push(@lines, "static ip6_address=$iface->{'address6'}->[$i]/".
		     ($iface->{'netmask6'}->[$i] || 64));
	}
if ($iface->{'gateway6'}) {
	push(@lines, "static ip6_routers=$iface->{'gateway6'}");
	}

# MTU is a plain dhcpcd directive, not a static key.
if ($iface->{'mtu'}) {
	push(@lines, "mtu $iface->{'mtu'}");
	}
return @lines;
}

# valid_dhcpcd_route_dest(destination)
# Returns true if a static IPv4 route destination is valid
sub valid_dhcpcd_route_dest
{
my ($dest) = @_;
return 0 if ($dest eq '');
my ($addr, $prefix) = split(/\//, $dest, 2);
return 0 if (!&check_ipaddress($addr));
return !defined($prefix) || $prefix =~ /^\d+$/ && $prefix >= 0 &&
       $prefix <= 32;
}

# dhcpcd_implicit_interfaces(&config, [&explicit-interfaces])
# Returns DHCP interfaces managed by dhcpcd without explicit blocks
sub dhcpcd_implicit_interfaces
{
my ($cfg, $explicit) = @_;
return ( ) if (!&dhcpcd_should_synthesize_implicit());

# Do not synthesize rows for names already represented by interface blocks.
my %explicit = map { $_->{'fullname'}, 1 } @$explicit;
my @rv;
foreach my $active (&dhcpcd_active_interfaces()) {
	my $name = $active->{'fullname'} || $active->{'name'};

	# Only real, non-loopback interfaces can be implicit dhcpcd rows.
	next if (!$name || $name eq "lo" || $active->{'virtual'} ne "");
	next if ($explicit{$name});
	next if (!&dhcpcd_interface_managed_by_default($name, $cfg));

	# Limit this to physical and wireless interfaces, not bridges/tunnels.
	my $type = &iface_type($name);
	next if ($type !~ /Ethernet|Wireless/);
	push(@rv, { 'name' => $name,
		    'fullname' => $name,
		    'virtual' => '',
		    'file' => $dhcpcd_config,
		    'edit' => 1,
		    'up' => 1,
		    'dhcp' => 1,
		    'implicit' => 1,
		    'address6' => [ ],
		    'netmask6' => [ ] });
	}
return @rv;
}

# dhcpcd_should_synthesize_implicit()
# Returns true if implicit default-DHCP interfaces should be shown
sub dhcpcd_should_synthesize_implicit
{
return $dhcpcd_synthesize_implicit
	if (defined($dhcpcd_synthesize_implicit));

# In normal use, implicit rows only make sense when dhcpcd is the service.
return defined(&net_dhcpcd_service_active) &&
       &net_dhcpcd_service_active();
}

# dhcpcd_active_interfaces()
# Returns active interfaces, with a test override for unit tests
sub dhcpcd_active_interfaces
{
return @$dhcpcd_test_active_interfaces
	if (ref($dhcpcd_test_active_interfaces));
return &active_interfaces(1);
}

# dhcpcd_interface_managed_by_default(name, &config)
# Returns true if global allow/deny rules let dhcpcd manage an interface
sub dhcpcd_interface_managed_by_default
{
my ($name, $cfg) = @_;
my ($global) = grep { $_->{'type'} eq 'global' } @$cfg;

# dhcpcd supports global allowinterfaces and denyinterfaces filters.
my @allow = $global ? map { split(/\s+/, $_) }
		  &dhcpcd_plain_values($global, "allowinterfaces") : ( );
my @deny = $global ? map { split(/\s+/, $_) }
		 &dhcpcd_plain_values($global, "denyinterfaces") : ( );

# denyinterfaces wins first; allowinterfaces narrows the default set.
return 0 if (grep { &dhcpcd_pattern_match($name, $_) } @deny);
return 1 if (!@allow);
return grep { &dhcpcd_pattern_match($name, $_) } @allow;
}

# dhcpcd_pattern_match(name, pattern)
# Returns true if an interface name matches a dhcpcd glob pattern
sub dhcpcd_pattern_match
{
my ($name, $pattern) = @_;
return 0 if ($pattern eq "");

# Convert dhcpcd-style shell globs into a safely quoted regexp.
my $re = quotemeta($pattern);
$re =~ s/\\\*/.*/g;
$re =~ s/\\\?/./g;
return $name =~ /^$re$/;
}

# dhcpcd_add_global_word(&lines, directive, word)
# Adds one word to a global dhcpcd directive before any interface block
sub dhcpcd_add_global_word
{
my ($lref, $name, $word) = @_;
return if ($word eq "");
for(my $i=0; $i<@$lref; $i++) {
	my $line = $lref->[$i];

	# Global directives must appear before interface/profile/ssid blocks.
	last if ($line =~ /^\s*(interface|profile|ssid)\s+\S+/);
	my $clean = $line;
	$clean =~ s/#.*$//;
	if ($clean =~ /^(\s*)\Q$name\E\s+(.*)$/) {
		# Extend an existing directive without adding duplicates.
		my @words = split(/\s+/, $2);
		return if (grep { $_ eq $word } @words);
		push(@words, $word);
		$lref->[$i] = $1.$name." ".join(" ", @words);
		return;
		}
	}

# No matching directive existed, so add a new global directive at the top.
unshift(@$lref, "$name $word");
}

# dhcpcd_add_global_word_if_exists(&lines, directive, word)
# Adds one word to an existing global dhcpcd directive
sub dhcpcd_add_global_word_if_exists
{
my ($lref, $name, $word) = @_;
return if ($word eq "");
for(my $i=0; $i<@$lref; $i++) {
	my $line = $lref->[$i];

	# Only global allow/deny directives apply before interface blocks.
	last if ($line =~ /^\s*(interface|profile|ssid)\s+\S+/);
	my $clean = $line;
	$clean =~ s/#.*$//;
	if ($clean =~ /^(\s*)\Q$name\E\s+(.*)$/) {
		my @words = split(/\s+/, $2);

		# Existing exact or glob patterns already allow this interface.
		return if (grep { $_ eq $word ||
				  &dhcpcd_pattern_match($word, $_) } @words);
		push(@words, $word);
		$lref->[$i] = $1.$name." ".join(" ", @words);
		return;
		}
	}
}

# dhcpcd_delete_global_word(&lines, directive, word)
# Removes one word from a global dhcpcd directive
sub dhcpcd_delete_global_word
{
my ($lref, $name, $word) = @_;
return if ($word eq "");
for(my $i=0; $i<@$lref; $i++) {
	my $line = $lref->[$i];

	# Stop before per-interface blocks so line numbers remain predictable.
	last if ($line =~ /^\s*(interface|profile|ssid)\s+\S+/);
	my $clean = $line;
	$clean =~ s/#.*$//;
	if ($clean =~ /^(\s*)\Q$name\E\s+(.*)$/) {
		# Keep the directive if other words remain, otherwise remove it.
		my @words = grep { $_ ne $word } split(/\s+/, $2);
		if (@words) {
			$lref->[$i] = $1.$name." ".join(" ", @words);
			}
		else {
			splice(@$lref, $i, 1);
			}
		return;
		}
	}
}

1;
