# linux-lib.pl
# Active interface functions for all flavours of linux

# active_interfaces([include-no-address])
# Returns a list of currently ifconfig'd interfaces
sub active_interfaces
{
local ($empty) = @_;
local(@rv, @lines, $l);
&clean_language();
&open_execute_command(IFC, "ifconfig -a", 1, 1);
while(<IFC>) {
	s/\r|\n//g;
	if (/^\S+/) { push(@lines, $_); }
	else { $lines[$#lines] .= $_; }
	}
close(IFC);
&reset_environment();
my $ethtool = &has_command("ethtool");
foreach $l (@lines) {
	local %ifc;
	$l =~ /^([^:\s]+)/; $ifc{'name'} = $1;
	$l =~ /^(\S+)/; $ifc{'fullname'} = $1;
	if ($l =~ /^(\S+):(\d+)/) { $ifc{'virtual'} = $2; }
	if ($l =~ /^(\S+)\.(\d+)/) { $ifc{'vlanid'} = $2; }
	if ($l =~ /inet addr:(\S+)/) { $ifc{'address'} = $1; }
	elsif (!$empty) { next; }
	if ($l =~ /Mask:(\S+)/) { $ifc{'netmask'} = $1; }
	if ($l =~ /Bcast:(\S+)/) { $ifc{'broadcast'} = $1; }
	if ($l =~ /HWaddr (\S+)/) { $ifc{'ether'} = $1; }
	if ($l =~ /MTU:(\d+)/) { $ifc{'mtu'} = $1; }
	if ($l =~ /P-t-P:(\S+)/) { $ifc{'ptp'} = $1; }
	$ifc{'up'}++ if ($l =~ /\sUP\s/);
	$ifc{'promisc'}++ if ($l =~ /\sPROMISC\s/);
	local (@address6, @netmask6, @scope6);
	while($l =~ s/inet6 addr:\s*(\S+)\/(\d+)\s+Scope:(Global)//i) {
		local ($address6, $netmask6, $scope6) = ($1, $2, $3);
		push(@address6, $address6);
		push(@netmask6, $netmask6);
		push(@scope6, $scope6);
		}
	$ifc{'address6'} = \@address6;
	$ifc{'netmask6'} = \@netmask6;
	$ifc{'scope6'} = \@scope6;
	$ifc{'edit'} = ($ifc{'name'} !~ /^ppp/);
	$ifc{'index'} = scalar(@rv);

	# Get current status for ethtool
	if ($ifc{'fullname'} =~ /^eth(\d+)$/ && $ethtool) {
		my $out = &backquote_command(
			"$ethtool $ifc{'fullname'} 2>/dev/null");
		if ($out =~ /Speed:\s+(\S+)/i) {
			$ifc{'speed'} = $1;
			}
		if ($out =~ /Duplex:\s+(\S+)/i) {
			$ifc{'duplex'} = $1;
			}
		if ($out =~ /Link\s+detected:\s+(\S+)/i) {
			$ifc{'link'} = lc($1) eq 'yes' ? 1 : 0;
			}
		}
	push(@rv, \%ifc);
	}
return @rv;
}

# activate_interface(&details)
# Create or modify an interface
sub activate_interface
{
local $a = $_[0];
# For Debian 5.0+ the "vconfig add" command is deprecated, this is handled by ifup.
if(($a->{'vlan'} == 1) && !(($gconfig{'os_type'} eq 'debian-linux') && ($gconfig{'os_version'} >= 5))) {
	local $vconfigCMD = "vconfig add " .
			    $a->{'physical'} . " " . $a->{'vlanid'};
	local $vconfigout = &backquote_logged("$vconfigCMD 2>&1");
	if ($?) { &error($vonconfigout); }
	}

local $cmd;
if (&use_ifup_command($a)) {
	# Use Debian / Redhat ifup command
	if($a->{'vlan'} == 1) {
		# name and fullname for VLAN tagged interfaces are "auto" so we need to ifup using physical and vlanid. 
		if ($a->{'up'}) {
			if(($a->{'mtu'}) && (($gconfig{'os_type'} eq 'redhat-linux') && ($gconfig{'os_version'} >= 13))) {
                        	local $cmd2;
                        	$cmd2 .= "ifconfig $a->{'physical'} mtu $a->{'mtu'}";
                        	local $out = &backquote_logged("$cmd2 2>&1");
                        	if ($?) { &error($out); }
                        	}
			$cmd .= "ifup $a->{'physical'}" . "." . $a->{'vlanid'};
			}
	        else { $cmd .= "ifdown $a->{'physical'}" . "." . $a->{'vlanid'}; }
	}
        elsif ($a->{'up'}) { $cmd .= "ifup $a->{'fullname'}"; }
        else { $cmd .= "ifdown $a->{'fullname'}"; }
	}
else {
	# Build ifconfig command manually
	if($a->{'vlan'} == 1) {
		$cmd .= "ifconfig $a->{'physical'}.$a->{'vlanid'}";
		}
	else {
		$cmd .= "ifconfig $a->{'name'}";
		if ($a->{'virtual'} ne "") {
			$cmd .= ":$a->{'virtual'}";
			}
		}
	$cmd .= " $a->{'address'}";
	if ($a->{'netmask'}) { $cmd .= " netmask $a->{'netmask'}"; }
	if ($a->{'broadcast'}) { $cmd .= " broadcast $a->{'broadcast'}"; }
	if ($a->{'mtu'} && $a->{'virtual'} eq "") { $cmd .= " mtu $a->{'mtu'}";}
	if ($a->{'up'}) { $cmd .= " up"; }
	else { $cmd .= " down"; }
	}
local $out = &backquote_logged("$cmd 2>&1");
if ($?) { &error($out); }

# Apply ethernet address
if ($a->{'ether'} && !&use_ifup_command($a)) {
	$out = &backquote_logged(
		"ifconfig $a->{'name'} hw ether $a->{'ether'} 2>&1");
	if ($?) { &error($out); }
	}

if ($a->{'virtual'} eq '') {
	# Remove old IPv6 addresses
	local $l = &backquote_command("ifconfig $a->{'name'}");
	while($l =~ s/inet6 addr:\s*(\S+)\/(\d+)\s+Scope:(\S+)//) {
		local $cmd = "ifconfig $a->{'name'} inet6 del $1/$2 2>&1";
		$out = &backquote_logged($cmd);
		&error("Failed to remove old IPv6 address : $out") if ($?);
		}

	# Add IPv6 addresses
	for(my $i=0; $i<@{$a->{'address6'}}; $i++) {
		local $cmd = "ifconfig $a->{'name'} inet6 add ".
		     $a->{'address6'}->[$i]."/".$a->{'netmask6'}->[$i]." 2>&1";
		$out = &backquote_logged($cmd);
		&error("Failed to add IPv6 address : $out") if ($?);
		}
	}
}

# deactivate_interface(&details)
# Shutdown some active interface
sub deactivate_interface
{
local $a = $_[0];
local $name = $a->{'name'}.
	      ($a->{'virtual'} ne "" ? ":$a->{'virtual'}" : "");
local $address = $a->{'address'}.
        ($a->{'virtual'} ne "" ? ":$a->{'virtual'}" : "");
local $netmask = $a->{'netmask'};
 
if ($a->{'virtual'} ne "") {
	# Shutdown virtual interface by setting address to 0
	local $out = &backquote_logged("ifconfig $name 0 2>&1");
	}
# Delete all v6 addresses
for(my $i=0; $i<@{$a->{'address6'}}; $i++) {
	local $cmd = "ifconfig $a->{'name'} inet6 del ".
		     $a->{'address6'}->[$i]."/".$a->{'netmask6'}->[$i];
	&backquote_logged("$cmd 2>&1");
	}

# Check if still up somehow
local ($still) = grep { $_->{'fullname'} eq $name } &active_interfaces();
if ($still) {
	# Old version of ifconfig or non-virtual interface.. down it
	local $out;
	if (&use_ifup_command($a)) {
		$out = &backquote_logged("ifdown $name 2>&1");
		}
	else {
		$out = &backquote_logged("ifconfig $name down 2>&1");
		}
	local ($still) = grep { $_->{'fullname'} eq $name }
		      &active_interfaces();
	if ($still && $still->{'up'}) {
		&error($out ? "<pre>$out</pre>"
			    : "Interface is still active even after being ".
			      "shut down");
		}
	if (&iface_type($name) =~ /^(.*) (VLAN)$/) {
		$out = &backquote_logged("vconfig rem $name 2>&1");
		}
	}
}

# use_ifup_command(&iface)
# Returns 1 if the ifup command must be used to bring up some interface.
# True on Debian 5.0+ for non-ethernet, typically bonding and VLAN tagged interfaces.
sub use_ifup_command
{
local ($iface) = @_;
return ($gconfig{'os_type'} eq 'debian-linux' &&
	$gconfig{'os_version'} >= 5 ||
	$gconfig{'os_type'} eq 'redhat-linux' &&
	$gconfig{'os_version'} >= 13) &&
       ($iface->{'name'} !~ /^(eth|lo)/ ||
 	$iface->{'name'} =~ /^(\S+)\.(\d+)/) &&
       $iface->{'virtual'} eq '';
}

# iface_type(name)
# Returns a human-readable interface type name
sub iface_type
{
if ($_[0] =~ /^(.*)\.(\d+)$/) {
	return &iface_type("$1")." VLAN";
	}
return "PPP" if ($_[0] =~ /^ppp/);
return "SLIP" if ($_[0] =~ /^sl/);
return "PLIP" if ($_[0] =~ /^plip/);
return "Ethernet" if ($_[0] =~ /^eth/);
return "Wireless Ethernet" if ($_[0] =~ /^(wlan|ath)/);
return "Arcnet" if ($_[0] =~ /^arc/);
return "Token Ring" if ($_[0] =~ /^tr/);
return "Pocket/ATP" if ($_[0] =~ /^atp/);
return "Loopback" if ($_[0] =~ /^lo/);
return "ISDN rawIP" if ($_[0] =~ /^isdn/);
return "ISDN syncPPP" if ($_[0] =~ /^ippp/);
return "CIPE" if ($_[0] =~ /^cip/);
return "VmWare" if ($_[0] =~ /^vmnet/);
return "Wireless" if ($_[0] =~ /^wlan/);
return "Bonded" if ($_[0] =~ /^bond/);
return "OpenVZ" if ($_[0] =~ /^venet/);
return "Bridge" if ($_[0] =~ /^br/);
return $text{'ifcs_unknown'};
}

# list_routes()
# Returns a list of active routes
sub list_routes
{
local @rv;
&open_execute_command(ROUTES, "netstat -rn", 1, 1);
while(<ROUTES>) {
	s/\s+$//;
	if (/^([0-9\.]+)\s+([0-9\.]+)\s+([0-9\.]+)\s+\S+\s+\S+\s+\S+\s+\S+\s+(\S+)$/) {
		push(@rv, { 'dest' => $1,
			    'gateway' => $2,
			    'netmask' => $3,
			    'iface' => $4 });
		}
	}
close(ROUTES);
&open_execute_command(ROUTES, "netstat -rn -A inet6", 1, 1);
while(<ROUTES>) {
	s/\s+$//;
	if (/^([0-9a-z:]+)\/([0-9]+)\s+([0-9a-z:]+)\s+\S+\s+\S+\s+\S+\s+\S+\s+(\S+)$/) {
		push(@rv, { 'dest' => $1,
			    'gateway' => $3,
			    'netmask' => $2,
			    'iface' => $4 });
		}
	}
close(ROUTES);
return @rv;
}

# load_module(&details)
# Load or modify a loaded module
sub load_module
{
local $a = $_[0];
local $cmd = "modprobe bonding";

if($a->{'mode'}) {$cmd .= " mode=" . $a->{'mode'};}
if($a->{'miimon'}) {$cmd .= " miimon=" . $a->{'miimon'};}
if($a->{'downdelay'}) {$cmd .= " downdelay=" . $a->{'downdelay'};}
if($a->{'updelay'}) {$cmd .= " updelay=" . $a->{'updelay'};}

local $out = &backquote_logged("$cmd 2>&1");
if ($?) { &error($out); }
}

# Tries to unload the module
# unload_module(name)
sub unload_module
{
	my ($name) = @_;
	my $cmd = "modprobe -r bonding";
	local $out = &backquote_logged("$cmd 2>&1");
	if($?) { &error($out);}
}

# list_interfaces()
# return a list of interfaces
sub list_interfaces
{
	my @ret;
	$cmd = "ifconfig -a";
	local $out = &backquote_logged("$cmd 2>&1");
	if ($?) { &error($out); }
	
	@lines = split("\n", $out);
	foreach $line(@lines) {
		$line =~ /^([\w|.]*)/m;
		if(($1)) {
			push(@ret, $1);
		}
	}
	return @ret;
}

# create_route(&route)
# Delete one active route, as returned by list_routes. Returns an error message
# on failure, or undef on success
sub delete_route
{
local ($route) = @_;
local $cmd = "route ".
	(&check_ip6address($route->{'dest'}) || $route->{'dest'} eq '::' ?
	 "-A inet6 " : "-A inet ")."del ";
if (!$route->{'dest'} || $route->{'dest'} eq '0.0.0.0' ||
    $route->{'dest'} eq '::') {
		$cmd .= " default";
	}
elsif ($route->{'netmask'} eq '255.255.255.255') {
	$cmd .= " -host $route->{'dest'}";
	}
elsif (!&check_ip6address($route->{'dest'})) {
	$cmd .= " -net $route->{'dest'}";
	if ($route->{'netmask'} && $route->{'netmask'} ne '0.0.0.0') {
		$cmd .= " netmask $route->{'netmask'}";
		}
	}
else {
	$cmd .= "$route->{'dest'}/$route->{'netmask'}";
	}
if ($route->{'gateway'}) {
	$cmd .= " gw $route->{'gateway'}";
	}
elsif ($route->{'iface'}) {
	$cmd .= " dev $route->{'iface'}";
	}
local $out = &backquote_logged("$cmd 2>&1 </dev/null");
return $? ? $out : undef;
}

# create_route(&route)
# Adds a new active route
sub create_route
{
local ($route) = @_;
local $cmd = "route ".
	(&check_ip6address($route->{'dest'}) ||
	 &check_ip6address($route->{'gateway'}) ?
	 "-A inet6 " : "-A inet ")."add ";
if (!$route->{'dest'} || $route->{'dest'} eq '0.0.0.0' ||
    $route->{'dest'} eq '::') {
	$cmd .= " default";
	}
elsif ($route->{'netmask'} eq '255.255.255.255') {
	$cmd .= " -host $route->{'dest'}";
	}
elsif (!&check_ip6address($route->{'dest'})) {
	$cmd .= " -net $route->{'dest'}";
	if ($route->{'netmask'} && $route->{'netmask'} ne '0.0.0.0') {
		$cmd .= " netmask $route->{'netmask'}";
		}
	}
else {
	$cmd .= "$route->{'dest'}/$route->{'netmask'}";
	}
if ($route->{'gateway'}) {
	$cmd .= " gw $route->{'gateway'}";
	}
elsif ($route->{'iface'}) {
	$cmd .= " dev $route->{'iface'}";
	}
local $out = &backquote_logged("$cmd 2>&1 </dev/null");
return $? ? $out : undef;
}

# iface_hardware(name)
# Does some interface have an editable hardware address
sub iface_hardware
{
return $_[0] =~ /^eth/;
}

# allow_interface_clash()
# Returns 0 to indicate that two virtual interfaces with the same IP
# are not allowed
sub allow_interface_clash
{
return 0;
}

# get_dns_config()
# Returns a hashtable containing keys nameserver, domain, search & order
sub get_dns_config
{
local $dns = { };
local $rc;
if ($use_suse_dns && ($rc = &parse_rc_config()) && $rc->{'NAMESERVER'}) {
	# Special case - get DNS settings from SuSE config
	local @ns = split(/\s+/, $rc->{'NAMESERVER'}->{'value'});
	$dns->{'nameserver'} = [ grep { $_ ne "YAST_ASK" } @ns ];
	local $src = $rc->{'SEARCHLIST'};
	$dns->{'domain'} = [ split(/\s+/, $src->{'value'}) ] if ($src);
	$dnsfile = $rc_config;
	}
elsif ($gconfig{'os_type'} eq 'debian-linux' &&
       -l "/etc/resolv.conf") {
	# On Ubuntu 12+, /etc/resolv.conf is auto-generated from network
	# interface config
	my @ifaces = &get_interface_defs();
	foreach my $i (@ifaces) {
		local ($ns) = grep { $_->[0] eq 'dns-nameservers' } @{$i->[3]};
		local @dom = grep { $_->[0] eq 'dns-domain' ||
				    $_->[0] eq 'dns-search' } @{$i->[3]};
		if ($ns) {
			$dns->{'nameserver'} = [ split(/\s+/, $ns->[1]) ];
			if (@dom) {
				$dns->{'domain'} =
					[ map { split(/\s+/, $_->[1]) } @dom ];
				}
			$dnsfile = "/etc/network/interfaces";
			last;
			}
		}
	}
if (!$dnsfile) {
	# Just read resolv.conf
	&open_readfile(RESOLV, "/etc/resolv.conf");
	while(<RESOLV>) {
		s/\r|\n//g;
		s/#.*$//;
		s/;.*$//;
		if (/nameserver\s+(.*)/) {
			push(@{$dns->{'nameserver'}}, split(/\s+/, $1));
			}
		elsif (/domain\s+(\S+)/) {
			$dns->{'domain'} = [ $1 ];
			}
		elsif (/search\s+(.*)/) {
			$dns->{'domain'} = [ split(/\s+/, $1) ];
			}
		}
	close(RESOLV);
	$dnsfile = "/etc/resolv.conf";
	}
&open_readfile(SWITCH, "/etc/nsswitch.conf");
while(<SWITCH>) {
	s/\r|\n//g;
	if (/^\s*hosts:\s+(.*)/) {
		$dns->{'order'} = $1;
		}
	}
close(SWITCH);
$dns->{'files'} = [ $dnsfile, "/etc/nsswitch.conf" ];
return $dns;
}

# save_dns_config(&config)
# Writes out the resolv.conf and nsswitch.conf files
sub save_dns_config
{
local $rc;
&lock_file($rc_config) if ($suse_dns_config);
local $use_resolvconf = 0;
local $need_resolvconf_update = 0;
if ($use_suse_dns && ($rc = &parse_rc_config()) && $rc->{'NAMESERVER'}) {
	# Update SuSE config file
	&save_rc_config($rc, "NAMESERVER", join(" ", @{$_[0]->{'nameserver'}}));
	&save_rc_config($rc, "SEARCHLIST", join(" ", @{$_[0]->{'domain'}}));
	}
elsif ($gconfig{'os_type'} eq 'debian-linux' &&
       -l "/etc/resolv.conf") {
	# resolv.conf is auto-generated!
	$use_resolvconf = 1;
	}
else {
	# Update standard resolv.conf file
	&lock_file("/etc/resolv.conf");
	&open_readfile(RESOLV, "/etc/resolv.conf");
	local @resolv = <RESOLV>;
	close(RESOLV);
	&open_tempfile(RESOLV, ">/etc/resolv.conf");
	foreach (@{$_[0]->{'nameserver'}}) {
		&print_tempfile(RESOLV, "nameserver $_\n");
		}
	if ($_[0]->{'domain'}) {
		if ($_[0]->{'domain'}->[1]) {
			&print_tempfile(RESOLV,
				"search ",join(" ", @{$_[0]->{'domain'}}),"\n");
			}
		else {
			&print_tempfile(RESOLV,
				"domain $_[0]->{'domain'}->[0]\n");
			}
		}
	foreach (@resolv) {
		&print_tempfile(RESOLV, $_)
			if (!/^\s*(nameserver|domain|search)\s+/);
		}
	&close_tempfile(RESOLV);
	&unlock_file("/etc/resolv.conf");
	}

# On Debian, if dns-nameservers are defined in interfaces, update them too
if ($gconfig{'os_type'} eq 'debian-linux' && defined(&get_interface_defs)) {
	local @ifaces = &get_interface_defs();
	local @dnssearch;
	if (@{$_[0]->{'domain'}} > 1) {
		@dnssearch = map { [ 'dns-search', $_ ] } @{$_[0]->{'domain'}};
		}
	elsif (@{$_[0]->{'domain'}}) {
		@dnssearch = ( [ 'dns-domain', $_[0]->{'domain'}->[0] ] );
		}
	foreach my $i (@ifaces) {
		local ($ns) = grep { $_->[0] eq 'dns-nameservers' } @{$i->[3]};
		if ($ns) {
			$ns->[1] = join(' ', @{$_[0]->{'nameserver'}});
			$i->[3] = [ grep { $_->[0] ne 'dns-domain' &&
					   $_->[0] ne 'dns-search' }
					 @{$i->[3]} ];
			push(@{$i->[3]}, @dnssearch);
			&modify_interface_def($i->[0], $i->[1], $i->[2],
					      $i->[3], 0);
			$need_resolvconf_update = 1;
			}
		}
	if (!$need_resolvconf_update && $use_resolvconf) {
		# Nameservers have to be defined in the interfaces file, but
		# no interfaces have them yet. Find the first non-local
		# interface with an IP, and add them there
		foreach my $i (@ifaces) {
			next if ($i->[0] =~ /^lo/);
			local ($a) = grep { $_->[0] eq 'address' &&
				    &check_ipaddress($_->[1]) } @{$i->[3]};
			next if (!$a);
			push(@{$i->[3]}, [ 'dns-nameservers',
				   join(' ', @{$_[0]->{'nameserver'}}) ]);
			push(@{$i->[3]}, @dnssearch);
			&modify_interface_def($i->[0], $i->[1], $i->[2],
					      $i->[3], 0);
			$need_resolvconf_update = 1;
			last;
			}
		}
	}

# Update resolution order in nsswitch.conf
&lock_file("/etc/nsswitch.conf");
&open_readfile(SWITCH, "/etc/nsswitch.conf");
local @switch = <SWITCH>;
close(SWITCH);
&open_tempfile(SWITCH, ">/etc/nsswitch.conf");
foreach (@switch) {
	if (/^\s*hosts:\s+/) {
		&print_tempfile(SWITCH, "hosts:\t$_[0]->{'order'}\n");
		}
	else {
		&print_tempfile(SWITCH, $_);
		}
	}
&close_tempfile(SWITCH);
&unlock_file("/etc/nsswitch.conf");

# Update SuSE config file
if ($suse_dns_config && $rc->{'USE_NIS_FOR_RESOLVING'}) {
	if ($_[0]->{'order'} =~ /nis/) {
		&save_rc_config($rc, "USE_NIS_FOR_RESOLVING", "yes");
		}
	else {
		&save_rc_config($rc, "USE_NIS_FOR_RESOLVING", "no");
		}
	}
&unlock_file($rc_config) if ($suse_dns_config);

# Update resolv.conf from network interfaces config
if ($need_resolvconf_update) {
	&apply_network();
	}
}

$max_dns_servers = 3;

# order_input(&dns)
# Returns HTML for selecting the name resolution order
sub order_input
{
my @o = split(/\s+/, $_[0]->{'order'});
@o = map { s/nis\+/nisplus/; s/yp/nis/; $_; } @o;
my @opts = ( [ "files", "Hosts file" ], [ "dns", "DNS" ], [ "nis", "NIS" ],
	     [ "nisplus", "NIS+" ], [ "ldap", "LDAP" ], [ "db", "DB" ],
	     [ "mdns4", "Multicast DNS" ] );
if (&indexof("mdns4_minimal", @o) >= 0) {
	push(@opts, [ "mdns4_minimal", "Multicast DNS (minimal)" ]);
	}
return &common_order_input("order", join(" ", @o), \@opts);
}

# parse_order(&dns)
# Parses the form created by order_input()
sub parse_order
{
if (defined($in{'order'})) {
	$in{'order'} =~ /\S/ || &error($text{'dns_eorder'});
	$_[0]->{'order'} = $in{'order'};
	}
else {
	local($i, @order);
	for($i=0; defined($in{"order_$i"}); $i++) {
		push(@order, $in{"order_$i"}) if ($in{"order_$i"});
		}
	$_[0]->{'order'} = join(" ", @order);
	}
}

1;

