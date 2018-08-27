# linux-lib.pl
# Active interface functions for all flavours of linux

# active_interfaces([include-no-ipv4-address])
# Returns a list of currently ifconfig'd interfaces
sub active_interfaces
{
local ($empty) = @_;
my @rv;
my $ethtool = &has_command("ethtool");

if (&has_command("ip")) {
	# Get status from new ip command
	&clean_language();
	&open_execute_command(IFC, "ip addr", 1, 1);
	my @lines;
	while(<IFC>) {
		s/\r|\n//g;
		if (/^\S+/) { push(@lines, $_); }
		else { $lines[$#lines] .= $_; }
		}
	close(IFC);
	&reset_environment();
	foreach my $l (@lines) {
		my %ifc;
		$l =~ /^\d+:\s+(\S+):/ || next;
		$ifc{'name'} = $1;
		$ifc{'fullname'} = $1;
		if ($l =~ /\sinet\s+([0-9\.]+)\s+peer\s+([0-9\.]+)\/(\d+)\s+brd\s+([0-9\.]+)\s+scope\s+global\s+(\S+)/ && $5 eq $ifc{'name'}) {
			# Line like :
			# inet 193.9.101.120 peer 193.9.101.104/32 brd 193.9.101.120 scope global eth0
			$ifc{'address'} = $1;
			$ifc{'netmask'} = &prefix_to_mask("$3");
			}
		elsif ($l =~ /\sinet\s+([0-9\.]+)\/(\d+)/ && !$ifc{'address'}) {
			# Line like :
			# inet 193.9.101.120/24 brd 193.9.101.255 scope global br0
			$ifc{'address'} = $1;
			$ifc{'netmask'} = &prefix_to_mask("$2");
			}
		elsif ($l =~ /\sinet\s+([0-9\.]+)\s+peer\s+([0-9\.]+)\/(\d+)/) {
			# Line like :
			# inet 46.4.13.87 peer 46.4.13.65/32
			$ifc{'address'} = $1;
			$ifc{'netmask'} = &prefix_to_mask("$3");
			}
		if ($l =~ /\sbrd\s+([0-9\.]+)/) {
			$ifc{'broadcast'} = $1;
			}
		if ($l =~ /\smtu\s+(\d+)/) {
			$ifc{'mtu'} = $1;
			}
		if ($l =~ /ether\s+([0-9a-f:]+)/i) {
			$ifc{'ether'} = $1;
			}

		my (@address6, @netmask6, @scope6);
		while($l =~ s/inet6\s+(\S+)\/(\d+)\s+scope\s+(\S+)//i) {
			local ($address6, $netmask6, $scope6) = ($1, $2, $3);
			push(@address6, $address6);
			push(@netmask6, $netmask6);
			push(@scope6, $scope6);
			}
		$ifc{'address6'} = \@address6;
		$ifc{'netmask6'} = \@netmask6;
		$ifc{'scope6'} = \@scope6;

		$ifc{'up'}++ if ($l =~ /\sUP\s|<\S*UP\S*>/);
		$ifc{'promisc'}++ if ($l =~ /\sPROMISC\s/);
		$ifc{'edit'} = ($ifc{'name'} !~ /^ppp/);
		$ifc{'index'} = scalar(@rv);
		push(@rv, \%ifc);

		# Add extra IPs as fake virtual interfaces
		$l =~ s/\sinet\s+([0-9\.]+)\s+peer// ||
			$l =~ s/\sinet\s+([0-9\.]+)\/(\d+)//;
		my $i = 0;
		my $bn = $ifc{'name'};
		while($l =~ s/\sinet\s+([0-9\.]+)\/(\d+).*?\Q$bn\E:(\d+)//) {
			my %vifc;
			$vifc{'name'} = $ifc{'name'};
			$vifc{'fullname'} = $ifc{'name'}.":".$3;
			$vifc{'address'} = $1;
			$vifc{'netmask'} = &prefix_to_mask("$2");
			$vifc{'broadcast'} = &compute_broadcast(
				$vifc{'address'}, $vifc{'netmask'});
			$vifc{'mtu'} = $ifc{'mtu'};
			$vifc{'up'} = $ifc{'up'};
			$vifc{'virtual'} = $3;
			$vifc{'edit'} = ($vifc{'name'} !~ /^ppp/);
			$vifc{'index'} = scalar(@rv);
			push(@rv, \%vifc);
			$i++;
			}
		}
	}
elsif (&has_command("ifconfig")) {
	&clean_language();
	&open_execute_command(IFC, "ifconfig -a", 1, 1);
	my @lines;
	while(<IFC>) {
		s/\r|\n//g;
		if (/^\S+/) { push(@lines, $_); }
		else { $lines[$#lines] .= $_; }
		}
	close(IFC);
	&reset_environment();
	foreach my $l (@lines) {
		my %ifc;
		$l =~ /^([^:\s]+)/ || next;
		$ifc{'name'} = $1;
		$l =~ /^(\S+)/;
		$ifc{'fullname'} = $1;
		$ifc{'fullname'} =~ s/:$//;
		if ($l =~ /^(\S+):(\d+)/) { $ifc{'virtual'} = $2; }
		if ($l =~ /^(\S+)\.(\d+)/) { $ifc{'vlanid'} = $2; }
		if ($l =~ /inet addr:(\S+)/) { $ifc{'address'} = $1; }
		elsif ($l =~ /inet (\S+)/) { $ifc{'address'} = $1; }
		elsif (!$empty) { next; }
		if ($l =~ /Mask:(\S+)/) { $ifc{'netmask'} = $1; }
		elsif ($l =~ /netmask (\S+)/) { $ifc{'netmask'} = $1; }
		if ($l =~ /Bcast:(\S+)/) { $ifc{'broadcast'} = $1; }
		elsif ($l =~ /broadcast (\S+)/) { $ifc{'broadcast'} = $1; }
		if ($l =~ /HWaddr (\S+)/) { $ifc{'ether'} = $1; }
		elsif ($l =~ /ether (\S+)/) { $ifc{'ether'} = $1; }
		if ($l =~ /MTU:(\d+)/) { $ifc{'mtu'} = $1; }
		elsif ($l =~ /mtu (\d+)/) { $ifc{'mtu'} = $1; }
		if ($l =~ /P-t-P:(\S+)/) { $ifc{'ptp'} = $1; }
		elsif ($l =~ /ptp (\S+)/) { $ifc{'ptp'} = $1; }
		$ifc{'up'}++ if ($l =~ /\sUP\s|<\S*UP\S*>/);
		$ifc{'promisc'}++ if ($l =~ /\sPROMISC\s/);

		my (@address6, @netmask6, @scope6);
		while($l =~ s/inet6 addr:\s*(\S+)\/(\d+)\s+Scope:(Global)//i) {
			local ($address6, $netmask6, $scope6) = ($1, $2, $3);
			push(@address6, $address6);
			push(@netmask6, $netmask6);
			push(@scope6, $scope6);
			}
		while($l =~ s/inet6 (\S+)\s+prefixlen (\d+)\s+scopeid\s+(\S+)<global>//i) {
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
		push(@rv, \%ifc);
		}
	}

else {
	&error("Both the ifconfig and ip commands are missing");
	}

foreach my $ifc (@rv) {
	# For each ethernet interface, merge in data from ethtool
	if (&iface_type($ifc->{'fullname'}) eq 'Ethernet' &&
	    $ifc->{'virtual'} eq '' && $ethtool) {
		my $out = &backquote_command(
			"$ethtool $ifc->{'fullname'} 2>/dev/null");
		if ($out =~ /Speed:\s+(\S+)/i && $1 ne "Unknown!") {
			$ifc->{'speed'} = $1;
			}
		if ($out =~ /Duplex:\s+(\S+)/i && $1 ne "Unknown!") {
			$ifc->{'duplex'} = $1;
			}
		if ($out =~ /Link\s+detected:\s+(\S+)/i) {
			$ifc->{'link'} = lc($1) eq 'yes' ? 1 : 0;
			}
		}
	}

return @rv;
}

# activate_interface(&details)
# Create or modify an interface
sub activate_interface
{
my ($a) = @_;
my ($old) = grep { $_->{'fullname'} eq $a->{'fullname'} } &active_interfaces();

# For Debian 5.0+ the "vconfig add" command is deprecated, this is handled
# by ifup.
if(($a->{'vlan'} == 1) && !(($gconfig{'os_type'} eq 'debian-linux') && ($gconfig{'os_version'} >= 5))) {
	local $vconfigCMD = "vconfig add " .
			    $a->{'physical'} . " " . $a->{'vlanid'};
	local $vconfigout = &backquote_logged("$vconfigCMD 2>&1");
	if ($?) { &error($vonconfigout); }
	}

if (!&has_command("ifconfig") && &has_command("ip")) {
	# For a real interface, activate or de-activate the link
	if ($a->{'virtual'} eq '' && $a->{'up'} && (!$old || !$old->{'up'})) {
		# Bring up
		my $cmd = "ip link set dev ".$a->{'name'}." up";
		my $out = &backquote_logged("$cmd 2>&1");
		&error("Failed to bring up link : $out") if ($?);
		}
	elsif ($a->{'virtual'} eq '' && !$a->{'up'} && $old && $old->{'up'}) {
		# Take down
		my $cmd = "ip link set dev ".$a->{'name'}." down";
		my $out = &backquote_logged("$cmd 2>&1");
		&error("Failed to bring down link : $out") if ($?);
		}
	}

my $cmd;
if (&use_ifup_command($a)) {
	# Use Debian / Redhat ifup command
	if($a->{'vlan'} == 1) {
		# Name and fullname for VLAN tagged interfaces are "auto" so
		# we need to ifup using physical and vlanid. 
		if ($a->{'up'}) {
			if(($a->{'mtu'}) && (($gconfig{'os_type'} eq 'redhat-linux') && ($gconfig{'os_version'} >= 13))) {
                        	my $cmd2;
                        	$cmd2 .= "ifconfig $a->{'physical'} mtu $a->{'mtu'}";
                        	my $out = &backquote_logged("$cmd2 2>&1");
                        	if ($?) { &error($out); }
                        	}
			$cmd .= "ifup $a->{'physical'}" . "." . $a->{'vlanid'};
			}
	        else {
			$cmd .= "ifdown $a->{'physical'}.".$a->{'vlanid'};
			}
		}
	elsif ($a->{'up'}) {
		$cmd .= "ifdown $a->{'fullname'}\; ifup $a->{'fullname'}";
		}
        else {
		$cmd .= "ifdown $a->{'fullname'}";
		}
	}
elsif (&has_command("ifconfig")) {
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
elsif (&has_command("ip")) {
	# If the IP is changing, first remove it then re-add
	my $readd = 0;
	if ($old && $old->{'address'}) {
		if ($old->{'address'} ne $a->{'address'} ||
		    $old->{'netmask'} ne $a->{'netmask'}) {
			my $rcmd = "ip addr del ".$old->{'address'}."/".
				   &mask_to_prefix($old->{'netmask'}).
				   " dev ".$a->{'name'};
			&system_logged("$rcmd >/dev/null 2>&1");
			$readd = 1;
			}
		}
	else {
		$readd = 1;
		}

	# Build ip command to add the new IP
	if ($readd) {
		$cmd .= "ip addr add ".$a->{'address'};
		if ($a->{'netmask'}) {
			$cmd .= "/".&mask_to_prefix($a->{'netmask'});
			}
		if ($a->{'broadcast'}) {
			$cmd .= " broadcast $a->{'broadcast'}";
			}
		if($a->{'vlan'} == 1) {
			$cmd .= " dev $a->{'physical'}.$a->{'vlanid'}";
			}
		else {
			$cmd .= " dev $a->{'name'}";
			}
		}
	}
else {
	&error("Both the ifconfig and ip commands are missing");
	}
my $out = &backquote_logged("cd / ; $cmd 2>&1");
if ($?) { &error($out); }

# Apply ethernet address
if ($a->{'ether'} && !&use_ifup_command($a) && &has_command("ifconfig")) {
	# With ifconfig command
	$out = &backquote_logged(
		"ifconfig $a->{'name'} hw ether $a->{'ether'} 2>&1");
	if ($?) { &error($out); }
	}
elsif ($a->{'ether'} && !&use_ifup_command($a) && &has_command("ip")) {
	# With ip link command
	$out = &backquote_logged(
	    "ip link set dev ".$a->{'name'}." address ".$a->{'ether'}." 2>&1");
	if ($?) { &error($out); }
	}

# Apply MTU
if ($a->{'mtu'} && !&use_ifup_command($a) && &has_command("ip")) {
	$out = &backquote_logged(
	    "ip link set dev ".$a->{'name'}." mtu ".$a->{'mtu'}." 2>&1");
	if ($?) { &error($out); }
	}

if ($a->{'virtual'} eq '' && &has_command("ifconfig")) {
	# Remove old IPv6 addresses
	local $l = &backquote_command("ifconfig $a->{'name'}");
	while($l =~ s/inet6 addr:\s*(\S+)\/(\d+)\s+Scope:(\S+)// ||
	      $l =~ s/inet6\s+(\S+)\s+prefixlen\s+(\d+)\s+scopeid\s+\S+//) {
		my $cmd = "ifconfig $a->{'name'} inet6 del $1/$2 2>&1";
		$out = &backquote_logged($cmd);
		&error("Failed to remove old IPv6 address : $out") if ($?);
		}

	# Add IPv6 addresses
	for(my $i=0; $i<@{$a->{'address6'}}; $i++) {
		my $cmd = "ifconfig $a->{'name'} inet6 add ".
		     $a->{'address6'}->[$i]."/".$a->{'netmask6'}->[$i]." 2>&1";
		$out = &backquote_logged($cmd);
		&error("Failed to add IPv6 address : $out") if ($?);
		}
	}
elsif ($a->{'virtual'} eq '' && &has_command("ip")) {
	# Remove old IPv6 addresses
	if ($old) {
		for(my $i=0; $i<@{$old->{'address6'}}; $i++) {
			my $cmd = "ip -6 addr del ".
				  $old->{'address6'}->[$i]."/".
				  $old->{'netmask6'}->[$i]." dev ".
				  $a->{'name'};
			$out = &backquote_logged("$cmd 2>&1");
			&error("Failed to remove old IPv6 address : $out") if ($?);
			}
		}

	# Add IPv6 addresses
	for(my $i=0; $i<@{$a->{'address6'}}; $i++) {
		my $cmd = "ip -6 addr add ".
			  $a->{'address6'}->[$i]."/".
			  $a->{'netmask6'}->[$i]." dev ".
			  $a->{'name'};
		$out = &backquote_logged("$cmd 2>&1");
		&error("Failed to add IPv6 address : $out") if ($?);
		}
	}

}

# deactivate_interface(&details)
# Shutdown some active interface
sub deactivate_interface
{
my ($a) = @_;
if (&has_command("ifconfig")) {
	# Use old ifconfig command
	my $name = $a->{'name'}.
		      ($a->{'virtual'} ne "" ? ":$a->{'virtual'}" : "");
	my $address = $a->{'address'}.
		($a->{'virtual'} ne "" ? ":$a->{'virtual'}" : "");
	my $netmask = $a->{'netmask'};
	 
	if ($a->{'virtual'} ne "") {
		# Shutdown virtual interface by setting address to 0
		my $out = &backquote_logged("ifconfig $name 0 2>&1");
		}
	# Delete all v6 addresses
	for(my $i=0; $i<@{$a->{'address6'}}; $i++) {
		my $cmd = "ifconfig $a->{'name'} inet6 del ".
			     $a->{'address6'}->[$i]."/".$a->{'netmask6'}->[$i];
		&backquote_logged("$cmd 2>&1");
		}

	# Check if still up somehow
	my ($still) = grep { $_->{'fullname'} eq $name } &active_interfaces();
	if ($still) {
		# Old version of ifconfig or non-virtual interface.. down it
		my $out;
		if (&use_ifup_command($a)) {
			$out = &backquote_logged("ifdown $name 2>&1");
			}
		else {
			$out = &backquote_logged("ifconfig $name down 2>&1");
			}
		my ($still) = grep { $_->{'fullname'} eq $name }
			      &active_interfaces();
		if ($still && $still->{'up'}) {
			&error($out ? "<pre>".&html_escape($out)."</pre>"
				    : "Interface is still active even after ".
				      "being shut down");
			}
		if (&iface_type($name) =~ /^(.*) (VLAN)$/) {
			$out = &backquote_logged("vconfig rem $name 2>&1");
			}
		}
	}
elsif (&has_command("ip")) {
	# Use new ip command to remove all IPs
	my @del;
	if ($a->{'address'}) {
		push(@del, $a->{'address'}."/".
			   &mask_to_prefix($a->{'netmask'}));
		}
	for(my $i=0; $i<@{$a->{'address6'}}; $i++) {
		push(@del, $a->{'address6'}->[$i]."/".
			   $a->{'netmask6'}->[$i]);
		}
	foreach my $d (@del) {
		my $cmd = "ip addr del ".$d." dev ".$a->{'name'};
		my $out = &backquote_logged("$cmd 2>&1");
		&error("Failed to remove old address : $out") if ($?);
		}

	if ($a->{'virtual'} eq '') {
		my $cmd = "ip link set dev ".$a->{'name'}." down";
		my $out = &backquote_logged("$cmd 2>&1");
		&error("<pre>".&html_escape($out)."</pre>") if ($?);
		}
	}
else {
	&error("Both the ifconfig and ip commands are missing");
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
       ($iface->{'name'} !~ /^(eth|em|eno|ens|enp|enx|lo|br)/ ||
 	$iface->{'name'} =~ /^(\S+)\.(\d+)/) &&
       $iface->{'virtual'} eq '';
}

# iface_type(name)
# Returns a human-readable interface type name
sub iface_type
{
my ($name) = @_;
if ($name =~ /^(.*)\.(\d+)$/) {
	return &iface_type("$1")." VLAN";
	}
return "PPP" if ($name =~ /^ppp/);
return "SLIP" if ($name =~ /^sl/);
return "PLIP" if ($name =~ /^plip/);
return "Ethernet" if ($name =~ /^eth|em|eno|ens|enp|enx|p\d+p\d+/);
return "Wireless Ethernet" if ($name =~ /^(wlan|ath)/);
return "Arcnet" if ($name =~ /^arc/);
return "Token Ring" if ($name =~ /^tr/);
return "Pocket/ATP" if ($name =~ /^atp/);
return "Loopback" if ($name =~ /^lo/);
return "ISDN rawIP" if ($name =~ /^isdn/);
return "ISDN syncPPP" if ($name =~ /^ippp/);
return "CIPE" if ($name =~ /^cip/);
return "VmWare" if ($name =~ /^vmnet/);
return "Wireless" if ($name =~ /^wlan/);
return "Bonded" if ($name =~ /^bond/);
return "OpenVZ" if ($name =~ /^venet/);
return "Bridge" if ($name =~ /^(br|xenbr|virbr)/);
return $text{'ifcs_unknown'};
}

# list_routes()
# Returns a list of active routes
sub list_routes
{
local @rv;
if (&has_command("netstat")) {
	# Use old netstat command if installed
	&open_execute_command(ROUTES, "netstat -rn", 1, 1);
	while(<ROUTES>) {
		s/\s+$//;
		if (/^([0-9\.]+)\s+([0-9\.]+)\s+([0-9\.]+)\s+\S+\s+\S+\s+\S+\s*\S+\s+(\S+)$/) {
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
		if (/^([0-9a-z:]+)\/([0-9]+)\s+([0-9a-z:]+)\s+\S+\s+\S+\s+\S+\s*\S+\s+(\S+)$/) {
			push(@rv, { 'dest' => $1,
				    'gateway' => $3,
				    'netmask' => $2,
				    'iface' => $4 });
			}
		}
	close(ROUTES);
	}
elsif (&has_command("ip")) {
	# Use new ip command
	&open_execute_command(ROUTES, "ip route", 1, 1);
	while(<ROUTES>) {
		s/\r|\n//g;
		if (/^(\S+)\s+/) {
			my $r = { 'dest' => $1 };
			if ($r->{'dest'} =~ /^(\S+)\/(\d+)/) {
				$r->{'dest'} = $1;
				$r->{'netmask'} = &prefix_to_mask("$2");
				}
			if (/\sdev\s+(\S+)/) {
				$r->{'iface'} = $1;
				}
			if (/\svia\s+(\S+)/) {
				$r->{'gateway'} = $1;
				}
			push(@rv, $r);
			}
		}
	close(ROUTES);
	}
else {
	&error("Both the ip and netstat commands are missing!");
	}
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

# delete_route(&route)
# Delete one active route, as returned by list_routes. Returns an error message
# on failure, or undef on success
sub delete_route
{
my ($route) = @_;
my $cmd;
my $proto = &check_ip6address($route->{'dest'}) ||
	    $route->{'dest'} eq '::' ? 6 : 4;
if (&has_command("route")) {
	# Use old route command
	$cmd = "route ".
	       ($proto == 6 ? "-A inet6" : "-A inet")." del ";
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
	}
elsif (&has_command("ip")) {
	# Use new ip command
	$cmd = "ip -".$proto." route delete";
	 if (!$route->{'dest'} || $route->{'dest'} eq '0.0.0.0' ||
            $route->{'dest'} eq '::') {
                $cmd .= " default";
                }
	else {
		$cmd .= " ".$route->{'dest'};
		if ($route->{'netmask'} && $route->{'netmask'} ne '0.0.0.0' &&
		    $route->{'netmask'} != 32) {
			if ($route->{'netmask'} =~ /^\d+$/) {
				$cmd .= "/".$route->{'netmask'};
				}
			else {
				$cmd .= "/".&mask_to_prefix($route->{'netmask'});
				}
			}
		}
	}
else {
	return "Missing the route and ip commands";
	}
my $out = &backquote_logged("$cmd 2>&1 </dev/null");
return $? ? $out : undef;
}

# create_route(&route)
# Adds a new active route
sub create_route
{
local ($route) = @_;
my $cmd;
my $proto = &check_ip6address($route->{'dest'}) ||
	    &check_ip6address($route->{'gateway'}) ? 6 : 4;
if (&has_command("route")) {
	# Use old route command
	$cmd = "route ".($proto == 6 ? "-A inet6" : "-A inet")." add";
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
	}
elsif (&has_command("ip")) {
	# Use new ip command
	$cmd = "ip -".$proto." route add";
	 if (!$route->{'dest'} || $route->{'dest'} eq '0.0.0.0' ||
            $route->{'dest'} eq '::') {
                $cmd .= " default";
                }
	else {
		$cmd .= " ".$route->{'dest'};
		if ($route->{'netmask'} && $route->{'netmask'} ne '0.0.0.0' &&
		    $route->{'netmask'} != 32) {
			if ($route->{'netmask'} =~ /^\d+$/) {
				$cmd .= "/".$route->{'netmask'};
				}
			else {
				$cmd .= "/".&mask_to_prefix($route->{'netmask'});
				}
			}
		}
	if ($route->{'gateway'}) {
		$cmd .= " via $route->{'gateway'}";
		}
	if ($route->{'iface'}) {
		$cmd .= " dev $route->{'iface'}";
		}
	}
else {
	return "Missing the route and ip commands";
	}
my $out = &backquote_logged("$cmd 2>&1 </dev/null");
return $? ? $out : undef;
}

# iface_hardware(name)
# Does some interface have an editable hardware address
sub iface_hardware
{
return $_[0] =~ /^(eth|em|eno|ens|enp|enx)/;
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
# XXX factor out to os_ functions
sub get_dns_config
{
local $dns = { };
local $rc;
local $dnsfile;
if ($use_suse_dns && ($rc = &parse_rc_config()) && $rc->{'NAMESERVER'}) {
	# Special case - get DNS settings from SuSE config
	local @ns = split(/\s+/, $rc->{'NAMESERVER'}->{'value'});
	$dns->{'nameserver'} = [ grep { $_ ne "YAST_ASK" } @ns ];
	local $src = $rc->{'SEARCHLIST'};
	$dns->{'domain'} = [ split(/\s+/, $src->{'value'}) ] if ($src);
	$dnsfile = $rc_config;
	}
elsif ($gconfig{'os_type'} eq 'debian-linux' && -l "/etc/resolv.conf" &&
       $netplan_dir) {
	# On Ubuntu 18+, /etc/resolv.conf is auto-generated from netplan config
	my @boot = &boot_interfaces();
	foreach my $b (@boot) {
		if ($b->{'nameserver'}) {
			$dns->{'nameserver'} = $b->{'nameserver'};
			$dns->{'domain'} = $b->{'search'};
			$dnsfile = $b->{'file'};
			last;
			}
		}
	}
elsif ($gconfig{'os_type'} eq 'debian-linux' && -l "/etc/resolv.conf") {
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
local ($conf) = @_;
local ($need_apply, $generated_resolv) = (0, 0);

# Call OS-specific function to update resolvers elsewhere
if (defined(&os_save_dns_config)) {
	($need_apply, $generated_resolv) = &os_save_dns_config($conf);
	}

if (!$generated_resolv) {
	# Update standard resolv.conf file
	&lock_file("/etc/resolv.conf");
	&open_readfile(RESOLV, "/etc/resolv.conf");
	local @resolv = <RESOLV>;
	close(RESOLV);
	&open_tempfile(RESOLV, ">/etc/resolv.conf");
	foreach (@{$conf->{'nameserver'}}) {
		&print_tempfile(RESOLV, "nameserver $_\n");
		}
	if ($conf->{'domain'}) {
		if ($conf->{'domain'}->[1]) {
			&print_tempfile(RESOLV,
				"search ",join(" ", @{$conf->{'domain'}}),"\n");
			}
		else {
			&print_tempfile(RESOLV,
				"domain $conf->{'domain'}->[0]\n");
			}
		}
	foreach (@resolv) {
		&print_tempfile(RESOLV, $_)
			if (!/^\s*(nameserver|domain|search)\s+/);
		}
	&close_tempfile(RESOLV);
	&unlock_file("/etc/resolv.conf");
	}

# Update resolution order in nsswitch.conf
&lock_file("/etc/nsswitch.conf");
&open_readfile(SWITCH, "/etc/nsswitch.conf");
local @switch = <SWITCH>;
close(SWITCH);
&open_tempfile(SWITCH, ">/etc/nsswitch.conf");
foreach (@switch) {
	if (/^\s*hosts:\s+/) {
		&print_tempfile(SWITCH, "hosts:\t$conf->{'order'}\n");
		}
	else {
		&print_tempfile(SWITCH, $_);
		}
	}
&close_tempfile(SWITCH);
&unlock_file("/etc/nsswitch.conf");

# Update SuSE config file for resolution order
if ($use_suse_dns) {
	&lock_file($rc_config);
	local $rc = &parse_rc_config();
	if ($rc->{'USE_NIS_FOR_RESOLVING'}) {
		if ($conf->{'order'} =~ /nis/) {
			&save_rc_config($rc, "USE_NIS_FOR_RESOLVING", "yes");
			}
		else {
			&save_rc_config($rc, "USE_NIS_FOR_RESOLVING", "no");
			}
		}
	&unlock_file($rc_config);
	}

# Update resolv.conf from network interfaces config
if ($need_apply) {
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
	     [ "mdns4", "Multicast DNS" ], [ "myhostname", "Local hostname" ] );
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

