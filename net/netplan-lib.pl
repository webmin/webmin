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
	my ($ens) = grep { $_->{'name'} eq 'ethernets' }
			 @{$network->{'members'}};
	next if (!$ens);
	foreach my $e (@{$ens->{'members'}}) {
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
			$cfg->{'dhcp6'} = 1;
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
			my $a = shift(@addrs);
			($cfg->{'address'}, $cfg->{'netmask'}) =
				&split_addr_netmask($a);
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
	else {
		push(@addrs, $iface->{'address'}."/".
			     &mask_to_prefix($iface->{'netmask'}));
		}
	if ($iface->{'dhcp6'}) {
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

	# Add all extra YAML directives from the original config
	my @poss = ( "optional", "dhcp4", "dhcp6", "addresses", "gateway4",
		     "gateway6", "nameservers", "macaddress" );
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
		&flush_file_lines($old->{'file'});
		&unlock_file($old->{'file'});
		}
	else {
		# Adding a new one (to it's own file)
		$iface->{'file'} = $netplan_dir."/".$iface->{'name'}.".yaml";
		@lines = ( "network:",
			   "    ethernets:",
			   @lines );
		&lock_file($iface->{'file'});
		my $lref = &read_file_lines($iface->{'file'});
		push(@$lref, @lines);
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
	&unlock_file($iface->{'file'});
	# XXX also delete file if empty?
	}
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
local ($iface) = @_;
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
return 0;	# XXX fix later
}

# can_edit(what)
# Can some boot-time interface parameter be edited?
sub can_edit
{
my ($f) = @_;
return $f ne "mtu";
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
local $hn = &read_file_contents("/etc/hostname");
$hn =~ s/\r|\n//g;
if ($hn) {
	return $hn;
	}
return &get_system_hostname(1);
}

# save_hostname(name)
sub save_hostname
{
local (%conf, $f);
&system_logged("hostname $_[0] >/dev/null 2>&1");
foreach $f ("/etc/hostname", "/etc/HOSTNAME", "/etc/mailname") {
	if (-r $f) {
		&open_lock_tempfile(HOST, ">$f");
		&print_tempfile(HOST, $_[0],"\n");
		&close_tempfile(HOST);
		}
	}
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

# Show default gateway
print &ui_table_row($text{'routes_default'},
	&ui_radio("gateway_def", $addr ? 0 : 1,
		  [ [ 1, $text{'routes_none'} ],
		    [ 0, $text{'routes_gateway'}." ".
			 &ui_textbox("gateway", $addr, 15)." ".
			 &ui_select("gatewaydev", $router,
				[ map { $_->{'name'} } @ifaces ]) ] ]));

# Show default IPv6 gateway
print &ui_table_row($text{'routes_default6'},
	&ui_radio("gateway6_def", $addr6 ? 0 : 1,
		  [ [ 1, $text{'routes_none'} ],
		    [ 0, $text{'routes_gateway'}." ".
			 &ui_textbox("gateway6", $addr6, 30)." ".
			 &ui_select("gatewaydev6", $router6,
				[ map { $_->{'name'} } @ifaces ]) ] ]));

# Act as router?
local %sysctl;
&read_env_file($sysctl_config, \%sysctl);
print &ui_table_row($text{'routes_forward'},
	&ui_yesno_radio("forward",
			$sysctl{'net.ipv4.ip_forward'} ? 1 : 0));
}

# parse_routing()
# Save the form generated by routing_input
sub parse_routing
{
# Save IPv4 address
my ($dev, $gw);
if (!$in{'gateway_def'}) {
	&check_ipaddress($in{'gateway'}) ||
		&error(&text('routes_egateway', $in{'gateway'}));
	$gw = $in{'gateway'};
	$dev = $in{'gatewaydev'};
	}
&set_default_gateway($gw, $dev);

# Save IPv6 address
my ($dev6, $gw6);
if (!$in{'gateway6_def'}) {
	&check_ip6address($in{'gateway6'}) ||
		&error(&text('routes_egateway6', $in{'gateway6'}));
	$gw6 = $in{'gateway6'};
	$dev6 = $in{'gatewaydev6'};
	}
&set_default_ipv6_gateway($gw6, $dev6);

# Save routing flag
local %sysctl;
&lock_file($sysctl_config);
&read_env_file($sysctl_config, \%sysctl);
$sysctl{'net.ipv4.ip_forward'} = $in{'forward'};
&write_env_file($sysctl_config, \%sysctl);
&unlock_file($sysctl_config);
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
	}
return ( );
}

# set_default_gateway([gateway, device])
# Sets the default gateway to the given IP accessible via the given device,
# in the boot time settings.
sub set_default_gateway
{
my ($gw, $dev) = @_;
foreach my $iface (&boot_interfaces()) {
	if ($iface->{'fullname'} eq $dev && $iface->{'gateway'} ne $gw) {
		# Need to add to this interface
		$iface->{'gateway'} = $gw;
		&save_interface($iface);
		}
	elsif ($iface->{'fullname'} ne $dev && $iface->{'gateway'}) {
		# Need to remove from this interface
		delete($iface->{'gateway'});
		&save_interface($iface);
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
foreach my $iface (&boot_interfaces()) {
	if ($iface->{'fullname'} eq $dev && $iface->{'gateway6'} ne $gw) {
		# Need to add to this interface
		$iface->{'gateway6'} = $gw;
		&save_interface($iface);
		}
	elsif ($iface->{'fullname'} ne $dev && $iface->{'gateway6'}) {
		# Need to remove from this interface
		delete($iface->{'gateway6'});
		&save_interface($iface);
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
			# At same level as previous directive, which puts it
			# underneath current parent
			push(@{$parent->{'members'}}, $dir);
			}
		elsif ($i > $lastdir->{'indent'}) {
			# A further ident by one level, meaning that it is under
			# the previous directive
			$parent = $lastdir;
			push(@{$parent->{'members'}}, $dir);
			}
		elsif ($i < $lastdir->{'indent'}) {
			# Indent has decreased, so this must be under a previous
			# parent directive
			$parent = $parent->{'parent'};
			while($i <= $parent->{'indent'}) {
				$parent = $parent->{'parent'};
				}
			push(@{$parent->{'members'}}, $dir);
			}
		$lastdir = $dir;
		&set_parent_elines($parent, $lnum);
		}
	elsif ($l =~ /^(\s*)\-\s*(\S+)\s*$/) {
		# Value-only line that is an extra value for the previous dir
		$lastdir->{'value'} ||= [ ];
		$lastdir->{'value'} = [ $lastdir->{'value'} ] if (!ref($lastdir->{'value'}));
		push(@{$lastdir->{'value'}}, $2);
		$lastdir->{'eline'} = $lnum;
		&set_parent_elines($parent, $lnum);
		}
	$lnum++;
	}
return $rv;
}

# yaml_lines(&directive, indent-string)
sub yaml_lines
{
my ($yaml, $id) = @_;
my @rv;
push(@rv, $id.$yaml->{'name'}.":".
	  (ref($yaml->{'value'}) eq 'ARRAY' ?
		" [".&join_addr_list(@{$yaml->{'value'}})."]" :
	   defined($yaml->{'value'}) ? " ".$yaml->{'value'} : ""));
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
return join(",", @rv);
}

# split_addr_list(string)
# Split up a string of properly formatted addresses
sub split_addr_list
{
my ($str) = @_;
my @rv;
foreach my $a (split(/,/, $str)) {
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
