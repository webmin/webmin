# Networking functions for Ubuntu 17+, which uses Netplan by default

$netplan_dir = "/etc/netplan";
$sysctl_config = "/etc/sysctl.conf";

do 'linux-lib.pl';

# boot_interfaces()
# Returns a list of all interfaces activated at boot time
sub boot_interfaces
{
my @rv;
foreach my $f (glob("$netplan_dir/*.yaml")) {
	my $yaml = &read_yaml_file($f);
	next if (!$yaml || !@$yaml);
	my ($network) = grep { $_->{'name'} eq 'network' } @$yaml;
	next if (!$network);
	my @ens = grep { $_->{'name'} eq 'ethernets' ||
			 $_->{'name'} eq 'bridges' }
			 @{$network->{'members'}};
	next if (!@ens);
	foreach my $e (map { @{$_->{'members'}} } @ens) {
		my $cfg = { 'name' => $e->{'name'},
			    'fullname' => $e->{'name'},
			    'file' => $f,
			    'yaml' => $e,
			    'line' => $e->{'line'},
			    'eline' => $e->{'eline'},
			    'edit' => 1,
			    'up' => 1 };

		# Is DHCP enabled?
		my ($dhcp) = grep { $_->{'name'} eq 'dhcp4' }
				  @{$e->{'members'}};
		if (&is_true_value($dhcp)) {
			$cfg->{'dhcp'} = 1;
			}
		my ($dhcp6) = grep { $_->{'name'} eq 'dhcp6' }
				  @{$e->{'members'}};
		if (&is_true_value($dhcp6)) {
			$cfg->{'auto6'} = 1;
			}

		# Is optional at boot?
		my ($optional) = grep { $_->{'name'} eq 'optional' }
				      @{$e->{'members'}};
		if (&is_true_value($optional)) {
			$cfg->{'up'} = 0;
			}

		# IPv4 and v6 addresses
		my ($addresses) = grep { $_->{'name'} eq 'addresses' }
				       @{$e->{'members'}};
		my @addrs;
		my @addrs6;
		if ($addresses) {
			foreach my $v (@{$addresses->{'value'}}) {
				my ($a) = split(/\//, $v);
				if (&check_ip6address($a)) {
					push(@addrs6, $v);
					}
				elsif (&check_ipaddress($a)) {
					push(@addrs, $v);
					}
				}
			if (!$cfg->{'dhcp'}) {
				my $a = shift(@addrs);
				($cfg->{'address'}, $cfg->{'netmask'}) =
					&split_addr_netmask($a);
				}
			}
		foreach my $a6 (@addrs6) {
			if ($a6 =~ /^(\S+)\/(\d+)$/) {
				push(@{$cfg->{'address6'}}, $1);
				push(@{$cfg->{'netmask6'}}, $2);
				}
			else {
				push(@{$cfg->{'address6'}}, $a6);
				push(@{$cfg->{'netmask6'}}, 64);
				}
			}

		# IPv4 and v4 gateways
		my ($gateway4) = grep { $_->{'name'} eq 'gateway4' }
				      @{$e->{'members'}};
		if ($gateway4) {
			$cfg->{'gateway'} = $gateway4->{'value'};
			}
		my ($gateway6) = grep { $_->{'name'} eq 'gateway6' }
				      @{$e->{'members'}};
		if ($gateway6) {
			$cfg->{'gateway6'} = $gateway6->{'value'};
			}
		$cfg->{'index'} = scalar(@rv);
		push(@rv, $cfg);

		# Nameservers (which are used to generate resolv.conf)
		my ($nameservers) = grep { $_->{'name'} eq 'nameservers' }
                                         @{$e->{'members'}};
		if ($nameservers) {
			my ($nsa) = grep { $_->{'name'} eq 'addresses' }
					 @{$nameservers->{'members'}};
			my ($search) = grep { $_->{'name'} eq 'search' }
					 @{$nameservers->{'members'}};
			if ($nsa && @{$nsa->{'value'}}) {
				$cfg->{'nameserver'} = $nsa->{'value'};
				}
			if ($search && @{$search->{'value'}}) {
				$cfg->{'search'} = $search->{'value'};
				}
			}

		# MAC address
		my ($macaddress) = grep { $_->{'name'} eq 'macaddress' }
                                         @{$e->{'members'}};
		if ($macaddress) {
			$cfg->{'ether'} = $macaddress->{'value'};
			}

		# Static routes
		my ($routes) = grep { $_->{'name'} eq 'routes' }
                                    @{$e->{'members'}};
		if ($routes) {
			$cfg->{'routes'} = $routes;
			}

		# Bridges
		my ($interfaces) = grep { $_->{'name'} eq 'interfaces' }
                                        @{$e->{'members'}};
		if ($interfaces) {
			$cfg->{'bridgeto'} = $interfaces->{'value'};
			$cfg->{'bridge'} = 1;
			}
		my ($p) = grep { $_->{'name'} eq 'parameters' }
                               @{$e->{'members'}};
		if ($p) {
			my ($stp) = grep { $_->{'name'} eq 'stp' }
					 @{$p->{'members'}};
			$cfg->{'bridgestp'} = $stp && $stp->{'value'} eq 'false' ? 'off' : 'on';
			my ($fwd) = grep { $_->{'name'} eq 'forward-delay' }
					 @{$p->{'members'}};
			$cfg->{'bridgefd'} = $fwd->{'value'} if ($fwd);
			}
		else {
			$cfg->{'bridgestp'} = 'on';
			}

		# Add IPv4 alias interfaces
		my $i = 0;
		foreach my $aa (@addrs) {
			my $acfg = { 'name' => $cfg->{'name'},
				     'virtual' => $i,
				     'fullname' => $cfg->{'name'}.":".$i,
				     'file' => $f,
				     'edit' => 1,
				     'up' => 1, };
			($acfg->{'address'}, $acfg->{'netmask'}) =
				&split_addr_netmask($aa);
			$acfg->{'index'} = scalar(@rv);
			push(@rv, $acfg);
			$i++;
			}
		}
	}
return @rv;
}

# save_interface(&details, [&all-interfaces])
# Create or update a boot-time interface
sub save_interface
{
my ($iface, $boot) = @_;
$boot ||= [ &boot_interfaces() ];
if ($iface->{'virtual'} ne '') {
	# Find the parent config entry
	my ($parent) = grep { $_->{'fullname'} eq $iface->{'name'} } @$boot;
	$parent || &error("No interface named $iface->{'name'} exists");
	if (!$iface->{'file'}) {
		# Add to complete interface list
		push(@$boot, $iface);
		}
	else {
		# Update in complete list
		my ($oldiface) = grep { $_->{'fullname'} eq
					$iface->{'fullname'} } @$boot;
		$oldiface || &error("No existing interface named $iface->{'fullname'} found");
		$boot->[$oldiface->{'index'}] = $iface;
		}
	&save_interface($parent, $boot);
	}
else {
	# Build interface config lines
	my $id = " " x 8;
	my @lines;
	push(@lines, $id.$iface->{'fullname'}.":");
	my @addrs;
	if (!$iface->{'up'}) {
		push(@lines, $id."    "."optional: true");
		}
	if ($iface->{'dhcp'}) {
		push(@lines, $id."    "."dhcp4: true");
		}
	elsif ($iface->{'address'}) {
		push(@addrs, $iface->{'address'}."/".
			     &mask_to_prefix($iface->{'netmask'}));
		}
	if ($iface->{'auto6'}) {
		push(@lines, $id."    "."dhcp6: true");
		}
	for(my $i=0; $i<@{$iface->{'address6'}}; $i++) {
		push(@addrs, $iface->{'address6'}->[$i]."/".
			     $iface->{'netmask6'}->[$i]);
		}
	foreach my $a (@$boot) {
		if ($a->{'virtual'} ne '' && $a->{'name'} eq $iface->{'name'}) {
			push(@addrs, $a->{'address'}."/".
				     &mask_to_prefix($a->{'netmask'}));
			}
		}
	if (@addrs) {
		push(@lines, $id."    "."addresses: [".
				&join_addr_list(@addrs)."]");
		}
	if ($iface->{'gateway'}) {
		push(@lines, $id."    "."gateway4: ".$iface->{'gateway'});
		}
	if ($iface->{'gateway6'}) {
		push(@lines, $id."    "."gateway6: ".$iface->{'gateway6'});
		}
	if ($iface->{'nameserver'}) {
		push(@lines, $id."    "."nameservers:");
		push(@lines, $id."        "."addresses: [".
			     &join_addr_list(@{$iface->{'nameserver'}})."]");
		if ($iface->{'search'}) {
			push(@lines, $id."        "."search: [".
			     &join_addr_list(@{$iface->{'search'}})."]");
			}
		}
	if ($iface->{'ether'}) {
		push(@lines, $id."    "."macaddress: ".$iface->{'ether'});
		}
	if ($iface->{'routes'}) {
		push(@lines, &yaml_lines($iface->{'routes'}, $id."    "));
		}
	if ($iface->{'bridgeto'}) {
		push(@lines, $id."    "."interfaces: [".$iface->{'bridgeto'}."]");
		push(@lines, $id."    "."parameters:");
		push(@lines, $id."        "."stp: ".
			($iface->{'bridgestp'} eq 'on' ? 'true' : 'false'));
		if ($iface->{'bridgefd'}) {
			push(@lines, $id."        "."forward-delay: ".
				     $iface->{'bridgefd'});
			}
		}

	# Add all extra YAML directives from the original config
	my @poss = ("optional", "dhcp4", "dhcp6", "addresses", "gateway4",
		    "gateway6", "nameservers", "macaddress", "routes");
	if ($iface->{'yaml'}) {
		foreach my $y (@{$iface->{'yaml'}->{'members'}}) {
			next if (&indexof($y->{'name'}, @poss) >= 0);
			push(@lines, &yaml_lines($y, $id."    "));
			}
		}

	if ($iface->{'file'}) {
		# Replacing an existing interface
		my ($old) = grep { $_->{'fullname'} eq $iface->{'fullname'} } @$boot;
		$old || &error("No interface named $iface->{'fullname'} found");
		&lock_file($old->{'file'});
		my $lref = &read_file_lines($old->{'file'});
		splice(@$lref, $old->{'line'},
		       $old->{'eline'} - $old->{'line'} + 1, @lines);
		my $diff = scalar(@lines) - ($old->{'eline'} - $old->{'line'} + 1);
		$iface->{'line'} = $old->{'line'};
		$iface->{'eline'} = $iface->{'line'} + scalar(@lines) - 1;
		&flush_file_lines($old->{'file'});
		&unlock_file($old->{'file'});
		if ($diff) {
			# May need to renumber other interface lines
			foreach my $b (@$boot) {
				$b->{'line'} += $diff if ($b->{'line'} > $iface->{'eline'});
				$b->{'eline'} += $diff if ($b->{'eline'} > $iface->{'eline'});
				}
			}
		}
	else {
		# Adding a new one (possibly to it's own file)
		$iface->{'file'} = $netplan_dir."/".$iface->{'name'}.".yaml";
		&lock_file($iface->{'file'});
		my $lref = &read_file_lines($iface->{'file'});
		my $nline = -1;
		my $eline = -1;
		my $sect = $iface->{'bridge'} ? 'bridges' : 'ethernets';
		for(my $i=0; $i<@$lref; $i++) {
			$nline = $i if ($lref->[$i] =~ /^\s*network:/);
			$eline = $i if ($lref->[$i] =~ /^\s*\Q$sect\E:/);
			}
		if ($nline < 0) {
			$nline = scalar(@$lref);
			push(@$lref, "network:");
			}
		if ($eline < 0) {
			$eline = $nline + 1;
			splice(@$lref, $nline+1, 0, "    ".$sect.":");
			}
		splice(@$lref, $eline+1, 0, @lines);
		$iface->{'line'} = $eline + 1;
		$iface->{'eline'} = $iface->{'line'} + scalar(@lines) - 1;
		&flush_file_lines($iface->{'file'});
		&unlock_file($iface->{'file'});
		}
	}
}

# delete_interface(&details)
# Remove a boot-time interface
sub delete_interface
{
my ($iface) = @_;
if ($iface->{'virtual'} ne '') {
	# Just remove the virtual address
	my $boot = [ &boot_interfaces() ];
	my ($parent) = grep { $_->{'fullname'} eq $iface->{'name'} } @$boot;
	$parent || &error("No interface named $iface->{'name'} exists");
	$boot = [ grep { $_->{'fullname'} ne $iface->{'fullname'} } @$boot ];
	&save_interface($parent, $boot);
	}
else {
	# Delete all the lines
	&lock_file($iface->{'file'});
	my $lref = &read_file_lines($iface->{'file'});
	splice(@$lref, $iface->{'line'},
	       $iface->{'eline'} - $iface->{'line'} + 1);
	&flush_file_lines($iface->{'file'});
	if (&is_yaml_empty($iface->{'file'})) {
		&unlink_file($iface->{'file'});
		}
	&unlock_file($iface->{'file'});
	}
}

# is_yaml_empty(file)
# Return 1 if a YAML file contains only network and ethernets line, with no
# other interfaces
sub is_yaml_empty
{
my ($file) = @_;
my $yaml = &read_yaml_file($file);
return 1 if (!$yaml);
my @rest = grep { $_->{'name'} ne 'network' } @$yaml;
return 0 if (@rest);
foreach my $n (@$yaml) {
	my @rest = grep { $_->{'name'} ne 'ethernets' &&
			  $_->{'name'} ne 'bridges' }
			@{$network->{'members'}};
	return 0 if (@rest);
	foreach my $ens (@{$network->{'members'}}) {
		return 0 if (@{$ens->{'members'}});
		}
	}
return 1;
}

sub supports_bonding
{
return 0;	# XXX fix later
}

sub supports_vlans
{
return 0;	# XXX fix later
}

sub boot_iface_hardware
{
return $_[0] =~ /^(eth|em)/;
}

# supports_address6([&iface])
# Returns 1 if managing IPv6 interfaces is supported
sub supports_address6
{
my ($iface) = @_;
return !$iface || $iface->{'virtual'} eq '';
}

# Returns 1, as boot-time interfaces on Debian can exist without an IP (such as
# for bridging)
sub supports_no_address
{
return 1;
}

# Bridge interfaces can be created on debian
sub supports_bridges
{
return 1;
}

# can_edit(what)
# Can some boot-time interface parameter be edited?
sub can_edit
{
my ($f) = @_;
return $f eq "mtu" ? 0 :
       $f eq "bridgewait" ? 0 : 1;
}

sub can_broadcast_def
{
return 0;
}

# valid_boot_address(address)
# Is some address valid for a bootup interface
sub valid_boot_address
{
return &check_ipaddress_any($_[0]);
}

# get_hostname()
sub get_hostname
{
my $hn = &read_file_contents("/etc/hostname");
$hn =~ s/\r|\n//g;
if ($hn) {
	return $hn;
	}
return &get_system_hostname();
}

# save_hostname(name)
sub save_hostname
{
my ($hostname) = @_;
&system_logged("hostname ".quotemeta($hostname)." >/dev/null 2>&1");
foreach my $f ("/etc/hostname", "/etc/HOSTNAME", "/etc/mailname") {
	if (-r $f) {
		&open_lock_tempfile(HOST, ">$f");
		&print_tempfile(HOST, $hostname,"\n");
		&close_tempfile(HOST);
		}
	}

# Use the hostnamectl command as well
if (&has_command("hostnamectl")) {
	&system_logged("hostnamectl set-hostname ".quotemeta($hostname).
		       " >/dev/null 2>&1");
	}

&get_system_hostname(undef, undef, 2);      # clear cache
}

# get_domainname()
sub get_domainname
{
my $d;
&execute_command("domainname", undef, \$d, undef);
chop($d);
return $d;
}

# save_domainname(domain)
sub save_domainname
{
my ($domain) = @_;
&execute_command("domainname ".quotemeta($domain));
}

sub routing_config_files
{
return ( $netplan_dir, $sysctl_config );
}

# routing_input()
# show default router and device
sub routing_input
{
my ($addr, $router) = &get_default_gateway();
my ($addr6, $router6) = &get_default_ipv6_gateway();
my @ifaces = grep { $_->{'virtual'} eq '' } &boot_interfaces();
my @inames = map { $_->{'name'} } @ifaces;

# Show default gateway
print &ui_table_row($text{'routes_default'},
	&ui_radio("gateway_def", $addr ? 0 : 1,
		  [ [ 1, $text{'routes_none'} ],
		    [ 0, $text{'routes_gateway'}." ".
			 &ui_textbox("gateway", $addr, 15)." ".
			 &ui_select("gatewaydev", $router, \@inames) ] ]));

# Show default IPv6 gateway
print &ui_table_row($text{'routes_default6'},
	&ui_radio("gateway6_def", $addr6 ? 0 : 1,
		  [ [ 1, $text{'routes_none'} ],
		    [ 0, $text{'routes_gateway'}." ".
			 &ui_textbox("gateway6", $addr6, 30)." ".
			 &ui_select("gatewaydev6", $router6, \@inames) ] ]));

# Act as router?
my %sysctl;
&read_env_file($sysctl_config, \%sysctl);
print &ui_table_row($text{'routes_forward'},
	&ui_yesno_radio("forward",
			$sysctl{'net.ipv4.ip_forward'} ? 1 : 0));

# Static routes
my $rtable = &ui_columns_start([ $text{'routes_ifc'},
			       $text{'routes_net'},
			       $text{'routes_mask'},
			       $text{'routes_gateway'} ]);
my $i = 0;
@inames = ( "", @inames );
foreach my $b (@ifaces) {
	next if (!$b->{'routes'});
	foreach my $v (@{$b->{'routes'}->{'value'}}) {
		next if ($v->{'to'} eq 'default');
		my ($net, $mask) = split(/\//, $v->{'to'});
		$mask = &prefix_to_mask($mask);
		$rtable .= &ui_columns_row([
		    &ui_select("dev_$i", $b->{'fullname'}, \@inames, 1, 0, 1),
		    &ui_textbox("net_$i", $net, 15),
		    &ui_textbox("mask_$i", $mask, 15),
		    &ui_textbox("gw_$i", $v->{'via'}, 15),
		    ]);
		$i++;
		}
	}
$rtable .= &ui_columns_row([
	&ui_select("dev_$i", "", \@inames, 1, 0, 1),
	&ui_textbox("net_$i", "", 15),
	&ui_textbox("mask_$i", "", 15),
	&ui_textbox("gw_$i", "", 15),
	]);
$rtable .= &ui_columns_end();
print &ui_table_row($text{'routes_static'}, $rtable);
}

# parse_routing()
# Save the form generated by routing_input
sub parse_routing
{
# Save IPv4 address
my ($dev, $gw);
if (!$in{'gateway_def'}) {
	&check_ipaddress($in{'gateway'}) ||
		&error(&text('routes_egateway', &html_escape($in{'gateway'})));
	$gw = $in{'gateway'};
	$dev = $in{'gatewaydev'};
	}
&set_default_gateway($gw, $dev);

# Save IPv6 address
my ($dev6, $gw6);
if (!$in{'gateway6_def'}) {
	&check_ip6address($in{'gateway6'}) ||
		&error(&text('routes_egateway6',&html_escape($in{'gateway6'})));
	$gw6 = $in{'gateway6'};
	$dev6 = $in{'gatewaydev6'};
	}
&set_default_ipv6_gateway($gw6, $dev6);

# Save routing flag
my %sysctl;
&lock_file($sysctl_config);
&read_env_file($sysctl_config, \%sysctl);
$sysctl{'net.ipv4.ip_forward'} = $in{'forward'};
&write_env_file($sysctl_config, \%sysctl);
&unlock_file($sysctl_config);

# Save static routes
my @boot = &boot_interfaces();
foreach my $b (grep { $_->{'virtual'} eq '' } @boot) {
	my @r;
	if ($b->{'routes'}) {
		@r = grep { $_->{'to'} eq 'default' }
			  @{$b->{'routes'}->{'value'}};
		}
	for(my $i=0; defined($in{"dev_$i"}); $i++) {
		if ($in{"dev_$i"} eq $b->{'fullname'}) {
			&check_ipaddress($in{"net_$i"}) ||
				&error(&text('routes_enet', $in{"net_$i"}));
			&check_ipaddress($in{"mask_$i"}) ||
				&error(&text('routes_emask', $in{"mask_$i"}));
			my $to = $in{"net_$i"}."/".
				 &mask_to_prefix($in{"mask_$i"});
			&check_ipaddress($in{"gw_$i"}) ||
				&error(&text('routes_egateway', $in{"gw_$i"}));
			push(@r, { 'to' => $to, 'via' => $in{"gw_$i"} });
			}
		}
	if (@r) {
		$b->{'routes'} = { 'name' => 'routes',
				   'value' => \@r };
		}
	else {
		delete($b->{'routes'});
		}
	&save_interface($b, \@boot);
	}
}

sub network_config_files
{
return ( "/etc/hostname", "/etc/HOSTNAME", "/etc/mailname" );
}

# apply_network()
# Apply the interface and routing settings
sub apply_network
{
&system_logged("(cd / ; netplan apply) >/dev/null 2>&1");
}

# get_default_gateway()
# Returns the default gateway IP (if one is set) and device (if set) boot time
# settings.
sub get_default_gateway
{
foreach my $iface (&boot_interfaces()) {
	if ($iface->{'gateway'}) {
		return ( $iface->{'gateway'}, $iface->{'fullname'} );
		}
	if ($iface->{'routes'}) {
		foreach my $v (@{$iface->{'routes'}->{'value'}}) {
			if ($v->{'to'} eq 'default') {
				return ( $v->{'via'}, $iface->{'fullname'} );
				}
			}
		}
	}
return ( );
}

# set_default_gateway([gateway, device])
# Sets the default gateway to the given IP accessible via the given device,
# in the boot time settings.
sub set_default_gateway
{
my ($gw, $dev) = @_;
my @boot = &boot_interfaces();
foreach my $iface (@boot) {
	# What is this interface's current default and how is it set?
	my $oldgw = $iface->{'gateway'};
	my $oldr;
	if (!$oldgw && $iface->{'routes'}) {
		foreach my $v (@{$iface->{'routes'}->{'value'}}) {
                        if ($v->{'to'} eq 'default') {
				$oldgw = $v->{'via'};
				$oldr = $v;
				}
			}
		}

	if ($iface->{'fullname'} eq $dev && $oldgw && $oldgw ne $gw) {
		# Already set, but we're changing it using the same method
		if ($oldr) {
			$oldr->{'via'} = $gw;
			}
		else {
			$iface->{'gateway'} = $gw;
			}
		$save = 1;
		}
	elsif ($iface->{'fullname'} eq $dev && !$oldgw) {
		# Not set but we need to add it, using a static route
		$iface->{'routes'} ||= { 'name' => 'routes',
					 'value' => [] };
		push(@{$iface->{'routes'}->{'value'}}, { 'to' => 'default',
						         'via' => $gw });
		$save = 1;
		}
	elsif ($iface->{'fullname'} ne $dev && $oldgw) {
		# Need to remove from however it is set
		if ($oldr) {
			$iface->{'routes'}->{'value'} = [ grep { $_ ne $oldr } @{$iface->{'routes'}->{'value'}} ];
			}
		else {
			delete($iface->{'gateway'});
			}
		$save = 1;
		}

	if ($save) {
		&save_interface($iface, \@boot);
		}
	}
}

# get_default_ipv6_gateway()
# Returns the default gateway IPv6 address (if one is set) and device (if set)
# boot time settings.
sub get_default_ipv6_gateway
{
foreach my $iface (&boot_interfaces()) {
	if ($iface->{'gateway6'}) {
		return ( $iface->{'gateway6'}, $iface->{'fullname'} );
		}
	}
return ( );
}

# set_default_ipv6_gateway([gateway, device])
# Sets the default IPv6 gateway to the given IP accessible via the given device,
# in the boot time settings.
sub set_default_ipv6_gateway
{
my ($gw, $dev) = @_;
my @boot = &boot_interfaces();
foreach my $iface (@boot) {
	if ($iface->{'fullname'} eq $dev && $iface->{'gateway6'} ne $gw) {
		# Need to add to this interface
		$iface->{'gateway6'} = $gw;
		&save_interface($iface, \@boot);
		}
	elsif ($iface->{'fullname'} ne $dev && $iface->{'gateway6'}) {
		# Need to remove from this interface
		delete($iface->{'gateway6'});
		&save_interface($iface, \@boot);
		}
	}
}

# os_save_dns_config(&config)
# On Ubuntu 18+, DNS servers are stored in the Netplan config files
sub os_save_dns_config
{
my ($conf) = @_;
my @boot = &boot_interfaces();
my @fix = grep { $_->{'nameserver'} } @boot;
@fix = @boot if (!@fix);
foreach my $iface (@fix) {
	$iface->{'nameserver'} = $conf->{'nameserver'};
	$iface->{'search'} = $conf->{'domain'};
	&save_interface($iface);
	}
}

# read_yaml_file(file)
# Converts a YAML file into a nested hash ref
sub read_yaml_file
{
my ($file) = @_;
my $lref = &read_file_lines($file, 1);
my $lnum = 0;
my $rv = [ ];
my $parent = { 'members' => $rv,
	       'indent' => -1 };
my $lastdir;
foreach my $origl (@$lref) {
	my $l = $origl;
	$l =~ s/#.*$//;
	if ($l =~ /^(\s*)(\S+):\s*(.*)/) {
		# Name and possibly value
		my $i = length($1);
		if ($i >= $lastdir->{'indent'} + 2 &&
		    ref($lastdir->{'value'}) eq 'ARRAY' &&
		    @{$lastdir->{'value'}} &&
		    ref($lastdir->{'value'}->[0]) eq 'HASH') {
			# Another key in the current value hash
			my $v = $lastdir->{'value'};
			$v->[@$v-1]->{$2} = $3;
			&set_parent_elines($lastdir, $lnum);
			}
		else {
			# A regular directive
			my $dir = { 'indent' => length($1),
				    'name' => $2,
				    'value' => $3,
				    'line' => $lnum,
				    'eline' => $lnum,
				    'parent' => $parent,
				    'members' => [],
				  };
			if ($dir->{'value'} =~ /^\[(.*)\]$/) {
				$dir->{'value'} = [ &split_addr_list("$1") ];
				}
			if (!$lastdir || $i == $lastdir->{'indent'}) {
				# At same level as previous directive, which
				# puts it underneath current parent
				push(@{$parent->{'members'}}, $dir);
				}
			elsif ($i > $lastdir->{'indent'}) {
				# A further ident by one level, meaning that it
				# is under the previous directive
				$parent = $lastdir;
				$dir->{'parent'} = $parent;
				push(@{$parent->{'members'}}, $dir);
				}
			elsif ($i < $lastdir->{'indent'}) {
				# Indent has decreased, so this must be under a
				# previous parent directive
				$parent = $parent->{'parent'};
				while($i <= $parent->{'indent'}) {
					$parent = $parent->{'parent'};
					}
				push(@{$parent->{'members'}}, $dir);
				$dir->{'parent'} = $parent;
				}
			$lastdir = $dir;
			&set_parent_elines($parent, $lnum);
			}
		}
	elsif ($l =~ /^(\s*)\-\s*(\S+):\s+(\S.*)$/) {
		# Value that is itself a key-value pair
		# routes:
		#   - to: 1.2.3.4/24
		#     via: 1.2.3.1
		#     metric: 100
		$lastdir->{'value'} ||= [ ];
		my $v = { $2 => $3 };
		push(@{$lastdir->{'value'}}, $v);
		$lastdir->{'eline'} = $lnum;
		&set_parent_elines($parent, $lnum);
		}
	elsif ($l =~ /^(\s*)\-\s*(\S+)\s*$/) {
		# Value-only line that is an extra value for the previous dir
		# addresses:
		#   - 1.2.3.4/24
		#   - 5.6.7.8/24
		$lastdir->{'value'} ||= [ ];
		$lastdir->{'value'} = [ $lastdir->{'value'} ] if (!ref($lastdir->{'value'}));
		push(@{$lastdir->{'value'}}, $2);
		$lastdir->{'eline'} = $lnum;
		&set_parent_elines($parent, $lnum);
		}
	$lnum++;
	}
&cleanup_yaml_parents($rv);
return $rv;
}

# cleanup_yaml_parents(&config)
# Remove all 'parent' fields once parsing is done, as they can't be serialized
sub cleanup_yaml_parents
{
my ($conf) = @_;
foreach my $c (@$conf) {
	delete($c->{'parent'});
	if ($c->{'members'}) {
		&cleanup_yaml_parents($c->{'members'});
		}
	}
}

# yaml_lines(&directive, indent-string)
# Converts a YAML directive into text lines
sub yaml_lines
{
my ($yaml, $id) = @_;
my @rv;
my $v = $id.$yaml->{'name'}.":";
if (ref($yaml->{'value'}) eq 'ARRAY') {
	my @a = @{$yaml->{'value'}};
	if (@a && ref($a[0]) eq 'HASH') {
		# Array of hashes, like for routes
		push(@rv, $v);
		foreach my $a (@a) {
			my @k = sort(keys %$a);
			my $f = shift(@k);
			push(@rv, $id."  - ".$f.": ".$a->{$f});
			foreach my $f (@k) {
				push(@rv, $id."    ".$f.": ".$a->{$f});
				}
			}
		}
	else {
		# Array of strings
		push(@rv, $v." [".&join_addr_list(@a)."]");
		}
	}
elsif (defined($yaml->{'value'})) {
	push(@rv, $v." ".$yaml->{'value'});
	}
else {
	push(@rv, $v);
	}
if ($yaml->{'members'}) {
	foreach my $m (@{$yaml->{'members'}}) {
		push(@rv, &yaml_lines($m, $id."    "));
		}
	}
return @rv;
}

# set_parent_elines(&conf, eline)
sub set_parent_elines
{
my ($c, $eline) = @_;
$c->{'eline'} = $eline;
&set_parent_elines($c->{'parent'}, $eline) if ($c->{'parent'});
}

# split_addr_netmask(addr-string)
# Splits a string like 1.2.3.4/24 into an address and netmask
sub split_addr_netmask
{
my ($a) = @_;
$a =~ s/^'(.*)'$/$1/g;
$a =~ s/^"(.*)"$/$1/g;
if ($a =~ /^([0-9\.]+)\/(\d+)$/) {
	return ($1, &prefix_to_mask($2));
	}
elsif ($a =~ /^([0-9\.]+)\/([0-9\.]+)$/) {
	return ($1, $2);
	}
else {
	return $a;
	}
}

# join_addr_list(addr, ...)
# Returns a string of properly joined addresses 
sub join_addr_list
{
my @rv;
foreach my $a (@_) {
	if ($a =~ /\/|\s|:/) {
		push(@rv, "'$a'");
		}
	else {
		push(@rv, $a);
		}
	}
return join(", ", @rv);
}

# split_addr_list(string)
# Split up a string of properly formatted addresses
sub split_addr_list
{
my ($str) = @_;
my @rv;
foreach my $a (split(/\s*,\s*/, $str)) {
	if ($a =~ /^'(.*)'$/ || $a =~ /^"(.*)"$/) {
		push(@rv, $1);
		}
	else {
		push(@rv, $a);
		}
	}
return @rv;
}

sub is_true_value
{
my ($dir) = @_;
return $dir && $dir->{'value'} =~ /true|yes|1/i;
}

1;
