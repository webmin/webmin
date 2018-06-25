# freebsd-lib.pl
# Networking functions for FreeBSD

$virtual_netmask = "255.255.255.255";	# Netmask for virtual interfaces

# active_interfaces()
# Returns a list of currently ifconfig'd interfaces
sub active_interfaces
{
local(@rv, @lines, $l);
local @boot = &boot_interfaces();
local %boot = map { $_->{'address'}, $_ } @boot;
local %bootname = map { $_->{'fullname'}, $_ } @boot;
&open_execute_command(IFC, "ifconfig -a", 1, 1);
while(<IFC>) {
	s/\r|\n//g;
	if (/^\S+:/) { push(@lines, $_); }
	elsif (@lines) { $lines[$#lines] .= $_; }
	}
close(IFC);
foreach $l (@lines) {
	local %ifc;
	$l =~ /^([^:\s]+):/;
	$ifc{'name'} = $ifc{'fullname'} = $1;
	if ($l =~ /^(\S+):(\d+):\s/) { $ifc{'virtual'} = $2; }
	local $bootiface = $bootname{$ifc{'fullname'}};
	local $bootip = $bootiface ? $bootiface->{'address'} : undef;
	if ($l =~ s/inet\s+($bootip)\s+netmask\s+(\S+)\s+broadcast\s+(\S+)// ||
	    $l =~ s/inet\s+(\S+)\s+netmask\s+(\S+)\s+broadcast\s+(\S+)//) {
		$ifc{'address'} = $1;
		$ifc{'netmask'} = &parse_hex($2);
		$ifc{'broadcast'} = $3;
		}
	elsif ($l =~ s/inet\s+($bootip)\s+netmask\s+(\S+)// ||
	       $l =~ s/inet\s+(\S+)\s+netmask\s+(\S+)//) {
		$ifc{'address'} = $1;
		$ifc{'netmask'} = &parse_hex($2);
		}
	else { next; }
	if ($l =~ /ether\s+(\S+)/) { $ifc{'ether'} = $1; }
	if ($l =~ /mtu\s+(\S+)/) { $ifc{'mtu'} = $1; }
	$ifc{'up'}++ if ($l =~ /\<UP/);
	$ifc{'edit'} = &iface_type($ifc{'name'}) =~ /ethernet|loopback/i;
	$ifc{'index'} = scalar(@rv);
	if ($ifc{'ether'}) {
		$ifc{'ether'} = join(":", map { length($_) == 1 ? "0".$_ : $_ }
					      split(/:/, $ifc{'ether'}));
		}
	push(@rv, \%ifc);

	# Add v6 addresses
	local (@address6, @netmask6, @scope6);
	while($l =~ s/inet6\s+([0-9a-f:]+)(%\S+)?\s+prefixlen\s+(\d+)(\s+scopeid\s+(\S+))?//) {
		push(@address6, $1);
		push(@netmask6, $3);
		push(@scope6, $5);
		}
	$ifc{'address6'} = \@address6;
	$ifc{'netmask6'} = \@netmask6;
	$ifc{'scope6'} = \@scope6;

	# Add aliases as virtual interfaces. Try to match boot-time interface
	# numbers where possible
	local %vtaken = map { $_->{'virtual'}, 1 }
			    grep { $_->{'name'} eq $vifc{'name'} &&
				   $_->{'virtual'} ne "" } @boot;
	while($l =~ s/inet\s+(\S+)\s+netmask\s+(\S+)(\s+broadcast\s+(\S+))?//) {
		local %vifc = %ifc;
		$vifc{'address'} = $1;
		$vifc{'netmask'} = &parse_hex($2);
		$vifc{'broadcast'} = $4;
		$vifc{'up'} = 1;
		$vifc{'edit'} = $ifc{'edit'};
		local $boot = $boot{$vifc{'address'}};
		if ($boot) {
			$vifc{'virtual'} = $boot->{'virtual'};
			}
		else {
			for($vifc{'virtual'}=0; $vtaken{$vifc{'virtual'}};
						$vifc{'virtual'}++) { }
			}
		$vtaken{$vifc{'virtual'}}++;
		$vifc{'fullname'} = $vifc{'name'}.':'.$vifc{'virtual'};
		$vifc{'index'} = scalar(@rv);
		push(@rv, \%vifc);
		}
	}
return @rv;
}

# activate_interface(&details)
# Create or modify an interface
sub activate_interface
{
local %act = map { $_->{'fullname'}, $_ } &active_interfaces();
local $old = $act{$_[0]->{'fullname'}};
$act{$_[0]->{'fullname'}} = $_[0];
&interface_sync(\%act, $_[0]->{'name'}, $_[0]->{'fullname'});

if ($_[0]->{'virtual'} eq '') {
	# Remove old IPv6 addresses
	local $l = &backquote_command("ifconfig $_[0]->{'name'}");
	while($l =~ s/inet6\s*(\S+)\s+prefixlen\s+(\d+)//) {
		local $cmd = "ifconfig $_[0]->{'name'} inet6 $1 -alias 2>&1";
		$out = &backquote_logged($cmd);
		&error("Failed to remove old IPv6 address : $out") if ($?);
		}

	# Add IPv6 addresses
	for(my $i=0; $i<@{$_[0]->{'address6'}}; $i++) {
		local $cmd = "ifconfig $_[0]->{'name'} inet6 ".
			     $_[0]->{'address6'}->[$i].
			     " prefixlen ".$_[0]->{'netmask6'}->[$i]." 2>&1";
		$out = &backquote_logged($cmd);
		&error("Failed to add IPv6 address : $out") if ($?);
		}
	}
}

# deactivate_interface(&details)
# Deactive an interface
sub deactivate_interface
{
local %act;
local @act = &active_interfaces();
if ($_[0]->{'virtual'} eq '') {
	@act = grep { $_->{'name'} ne $_[0]->{'name'} } @act;
	}
else {
	@act = grep { $_->{'fullname'} ne $_[0]->{'fullname'} } @act;
	}
map { $act{$_->{'fullname'}} = $_ } @act;
&interface_sync(\%act, $_[0]->{'name'}, $_[0]->{'fullname'});
}

# interface_sync(&interfaces-hash, name, changee)
# Given a hash from interface name to details, make them live. This is needed
# because on FreeBSD, alias interfaces are just IPs on the main interface, 
# rather than separate eth0:N interfaces like on Linux.
sub interface_sync
{
# Remove all IP addresses except for the primary one (unless it is being edited)
local $pri = $_[0]->{$_[1]};
local $ifconfig = &has_command("ifconfig");
while(1) {
	local $out;
	&execute_command("$ifconfig $_[1]", undef, \$out);
	last if ($out !~ /([\000-\377]*)\s+inet\s+(\d+\.\d+\.\d+\.\d+)/);
	last if ($2 eq $pri->{'address'} && $_[2] ne $pri->{'fullname'});
	&system_logged("$ifconfig $_[1] delete $2 >/dev/null 2>&1");
	}

# Add them back again, except for the primary unless it is being changed
foreach $a (sort { $a->{'fullname'} cmp $b->{'fullname'} }
		 grep { $_->{'name'} eq $_[1] } values(%{$_[0]})) {
	next if ($a->{'fullname'} eq $pri->{'fullname'} &&
		 $_[2] ne $pri->{'fullname'});
	local $cmd = "$ifconfig $a->{'name'}";
	if ($a->{'virtual'} ne '') {
		$cmd .= " alias $a->{'address'}";
		}
	else {
		$cmd .= " $a->{'address'}";
		}
	if ($a->{'netmask'}) { $cmd .= " netmask $a->{'netmask'}"; }
	if ($a->{'broadcast'}) { $cmd .= " broadcast $a->{'broadcast'}"; }
	if ($a->{'mtu'}) { $cmd .= " mtu $a->{'mtu'}"; }
	local $out = &backquote_logged("$cmd 2>&1");
	#if ($? && $out !~ /file exists/i) {
	if ($?) {
		&error($out);
		}
	if ($a->{'virtual'} eq '') {
		if ($a->{'up'}) { $out = &backquote_logged("$ifconfig $a->{'name'} up 2>&1"); }
		else { $out = &backquote_logged("$ifconfig $a->{'name'} down 2>&1"); }
		&error($out) if ($?);
		}
	}

}

# boot_interfaces()
# Returns a list of interfaces brought up at boot time
sub boot_interfaces
{
local %rc = &get_rc_conf();
local @rv;
foreach my $r (keys %rc) {
	local $v = $rc{$r};
	local %ifc;
	if ($r =~ /^ifconfig_([a-z0-9]+)$/) {
		# Non-virtual interface
		%ifc = ( 'name' => $1,
			 'fullname' => $1 );
		}
	elsif ($r =~ /^ifconfig_([a-z0-9]+)_alias(\d+)$/) {
		# Virtual interface
		%ifc = ( 'name' => $1,
			 'virtual' => $2,
			 'fullname' => "$1:$2" );
		}
	else { next; }

	if ($v =~ /^inet\s+(\S+)/ || /^([0-9\.]+)/) {
		$ifc{'address'} = $1;
		}
	elsif ($v eq 'DHCP') {
		$ifc{'dhcp'} = 1;
		}
	local @a = split(/\./, $ifc{'address'});
	if ($v =~ /netmask\s+(0x\S+)/) {
		$ifc{'netmask'} = &parse_hex($1);
		}
	elsif ($v =~ /netmask\s+([0-9\.]+)/) {
		$ifc{'netmask'} = $1;
		}
	else {
		$ifc{'netmask'} = $a[0] >= 192 ? "255.255.255.0" :
				  $a[0] >= 128 ? "255.255.0.0" :
						 "255.0.0.0";
		}
	if ($v =~ /broadcast\s+(0x\S+)/) {
		$ifc{'broadcast'} = &parse_hex($1);
		}
	elsif ($v =~ /broadcast\s+([0-9\.]+)/) {
		$ifc{'broadcast'} = $1;
		}
	else {
		local @n = split(/\./, $ifc{'netmask'});
		$ifc{'broadcast'} = sprintf "%d.%d.%d.%d",
					($a[0] | ~int($n[0]))&0xff,
					($a[1] | ~int($n[1]))&0xff,
					($a[2] | ~int($n[2]))&0xff,
					($a[3] | ~int($n[3]))&0xff;
		}
	$ifc{'mtu'} = $1 if ($v =~ /mtu\s+(\d+)/);
	$ifc{'up'} = 1;
	$ifc{'edit'} = 1;
	$ifc{'index'} = scalar(@rv);
	$ifc{'file'} = "/etc/rc.conf";

	# Check for IPv6 params
	local $v6 = $rc{'ipv6_ifconfig_'.$ifc{'fullname'}};
	if ($v6 =~ /^inet6\s+(\S+)/ || $v6 =~ /^([0-9a-f:]+)/) {
		$ifc{'address6'} = [ $1 ];
		}
	elsif (!$v6 && $rc{'ipv6_enable'}) {
		$ifc{'auto6'} = 1;
		}
	if ($v6 =~ /prefixlen\s+(\d+)/) {
		$ifc{'netmask6'} = [ $1 ];
		}

	# Add IPv6 aliases
	foreach my $rr (sort { $a cmp $b } keys %rc) {
		if ($rr =~ /^ipv6_ifconfig_(\S+)_alias\d+$/ &&
		    $1 eq $ifc{'fullname'}) {
			local $v6 = $rc{$rr};
			if ($v6 =~ /^inet6\s+(\S+)/ || $v6 =~ /^([0-9a-f:]+)/) {
				push(@{$ifc{'address6'}}, $1);
				}
			if ($v6 =~ /prefixlen\s+(\d+)/) {
				push(@{$ifc{'netmask6'}}, $1);
				}
			}
		}

	push(@rv, \%ifc);
	}
return @rv;
}

# save_interface(&details)
# Create or update a boot-time interface
sub save_interface
{
local $str;
if ($_[0]->{'dhcp'}) {
	$str = "DHCP";
	}
else {
	$str = "inet $_[0]->{'address'}";
	$str .= " netmask $_[0]->{'netmask'}" if ($_[0]->{'netmask'});
	$str .= " broadcast $_[0]->{'broadcast'}" if ($_[0]->{'broadcast'});
	}
&lock_file("/etc/rc.conf");
if ($_[0]->{'virtual'} eq '') {
	&save_rc_conf('ifconfig_'.$_[0]->{'name'}, $str);
	}
else {
	local @boot = &boot_interfaces();
	local ($old) = grep { $_->{'fullname'} eq $_[0]->{'fullname'} } @boot;
	if (!$old && $_[0]->{'virtual'} ne '') {
		# A new virtual interface .. pick a virtual number automaticlly
		local $b;
		$_[0]->{'virtual'} = 0;
		foreach $b (&boot_interfaces()) {
			if ($b->{'name'} eq $_[0]->{'name'} &&
			    $b->{'virtual'} ne '' &&
			    $b->{'virtual'} >= $_[0]->{'virtual'}) {
				$_[0]->{'virtual'} = $b->{'virtual'}+1;
				}
			}
		$_[0]->{'fullname'} = $_[0]->{'name'}.':'.$_[0]->{'virtual'};
		}
	&save_rc_conf('ifconfig_'.$_[0]->{'name'}.'_alias'.$_[0]->{'virtual'},
		      $str);
	}

# Update IPv6 settings
if ($_[0]->{'virtual'} eq '') {
	local @a = @{$_[0]->{'address6'}};
	local @n = @{$_[0]->{'netmask6'}};
	if (@a || $_[0]->{'auto6'}) {
		&save_rc_conf('ipv6_enable', 'YES');
		}
	if (@a) {
		&save_rc_conf('ipv6_ifconfig_'.$_[0]->{'name'},
			      $a[0].' prefixlen '.$n[0]);
		}
	else {
		&save_rc_conf('ipv6_ifconfig_'.$_[0]->{'name'});
		}

	# Delete any IPv6 aliases
	local %rc = &get_rc_conf();
	foreach my $r (keys %rc) {
		if ($r =~ /^ipv6_ifconfig_(\S+)_alias\d+$/ &&
		    $1 eq $_[0]->{'fullname'}) {
			&save_rc_conf($r);
			}
		}

	# Re-create IPv6 aliases
	shift(@a);
	shift(@n);
	for(my $i=0; $i<@a; $i++) {
		&save_rc_conf(
			"ipv6_ifconfig_".$_[0]->{'fullname'}."_alias".$i,
			$a[$i]." prefixlen ".$n[$i]);
		}
	}

&unlock_file("/etc/rc.conf");
}

# delete_interface(&details, [noshift])
# Delete a boot-time interface
sub delete_interface
{
&lock_file("/etc/rc.conf");
if ($_[0]->{'virtual'} eq '') {
	# Remove the real interface
	&save_rc_conf('ifconfig_'.$_[0]->{'name'});
	&save_rc_conf('ipv6_ifconfig_'.$_[0]->{'name'});
	# XXX ipv6 too
	}
else {
	# Remove a virtual interface, and shift down all aliases above it
	&save_rc_conf('ifconfig_'.$_[0]->{'name'}.'_alias'.$_[0]->{'virtual'});
	if (!$_[1]) {
		local ($b, %lastb);
		foreach $b (&boot_interfaces()) {
			if ($b->{'name'} eq $_[0]->{'name'} &&
			    $b->{'virtual'} ne '' &&
			    $b->{'virtual'} > $_[0]->{'virtual'}) {
				# This one needs to be shifted down
				%lastb = %$b;
				$b->{'virtual'}--;
				&save_interface($b);
				}
			}
		&delete_interface(\%lastb, 1) if (%lastb);
		}
	}
&unlock_file("/etc/rc.conf");
}

# iface_type(name)
# Returns a human-readable interface type name
sub iface_type
{
return	$_[0] =~ /^tun/ ? "Loopback tunnel" :
	$_[0] =~ /^sl/ ? "SLIP" :
	$_[0] =~ /^ppp/ ? "PPP" :
	$_[0] =~ /^lo/ ? "Loopback" :
	$_[0] =~ /^ar/ ? "Arnet" :
	$_[0] =~ /^(wlan|athi|ral)/ ? "Wireless ethernet" :
	$_[0] =~ /^(bge|em|myk)/ ? "Gigabit ethernet" :
	$_[0] =~ /^(ax|mx|nve|pn|rl|tx|wb|nfe|sis)/ ? "Fast ethernet" :
	$_[0] =~ /^(cs|dc|de|ed|el|ex|fe|fxp|ie|le|lnc|tl|vr|vx|xl|ze|zp|re)/ ? "Ethernet" : $text{'ifcs_unknown'};
}

# iface_hardware(name)
# Does some interface have an editable hardware address
sub iface_hardware
{
return 0;
}

# can_edit(what)
# Can some boot-time interface parameter be edited?
sub can_edit
{
return $_[0] =~ /netmask|broadcast|dhcp/;
}

# valid_boot_address(address)
# Is some address valid for a bootup interface
sub valid_boot_address
{
return &check_ipaddress($_[0]);
}

# get_dns_config()
# Returns a hashtable containing keys nameserver, domain, search & order
sub get_dns_config
{
local $dns;
&open_readfile(RESOLV, "/etc/resolv.conf");
while(<RESOLV>) {
	s/\r|\n//g;
	s/#.*$//g;
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

local @order;
local $orderfile;
if (-r "/etc/nsswitch.conf") {
	# FreeBSD 5.0 and later use nsswitch.conf
	$orderfile = "/etc/nsswitch.conf";
	&open_readfile(SWITCH, $orderfile);
	while(<SWITCH>) {
		s/\r|\n//g;
		if (/^\s*hosts:\s+(.*)/) {
			$dns->{'order'} = $1;
			}
		}
	close(SWITCH);
	}
else {
	# Older versions use host.conf
	$orderfile = "/etc/host.conf";
	&open_readfile(HOST, $orderfile);
	while(<HOST>) {
		s/\r|\n//g;
		s/#.*$//;
		push(@order, $_) if (/\S/);
		}
	close(HOST);
	$dns->{'order'} = join(" ", @order);
	}
$dns->{'files'} = [ "/etc/resolv.conf", $orderfile ];
return $dns;
}

# save_dns_config(&config)
# Writes out the resolv.conf and host.conf files
sub save_dns_config
{
&lock_file("/etc/resolv.conf");
&open_readfile(RESOLV, "/etc/resolv.conf");
local @resolv = <RESOLV>;
close(RESOLV);
&open_tempfile(RESOLV, ">/etc/resolv.conf");
foreach (@{$_[0]->{'nameserver'}}) {
	print RESOLV "nameserver $_\n";
	}
if ($_[0]->{'domain'}) {
	if ($_[0]->{'domain'}->[1]) {
		&print_tempfile(RESOLV, "search ",join(" ", @{$_[0]->{'domain'}}),"\n");
		}
	else {
		&print_tempfile(RESOLV, "domain $_[0]->{'domain'}->[0]\n");
		}
	}
foreach (@resolv) {
	&print_tempfile(RESOLV, $_) if (!/^\s*(nameserver|domain|search)\s+/);
	}
&close_tempfile(RESOLV);
&unlock_file("/etc/resolv.conf");

if (-r "/etc/nsswitch.conf") {
	# Save to new nsswitch.conf, for FreeBSD 5.0 and later
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
	}
else {
	# Save to older host.conf
	&open_lock_tempfile(HOST, ">/etc/host.conf");
	foreach my $o (split(/\s+/, $_[0]->{'order'})) {
		&print_tempfile(HOST, $o,"\n");
		}
	&close_tempfile(HOST);
	}
}

$max_dns_servers = 3;

# order_input(&dns)
# Returns HTML for selecting the name resolution order
sub order_input
{
if (-r "/etc/nsswitch.conf") {
	# FreeBSD 5.0 and later use nsswitch.conf with more options
	return &common_order_input("order", $_[0]->{'order'},
		[ [ "files", "Files" ], [ "dns", "DNS" ],
		  [ "nis", "NIS" ], [ "cache", "NSCD" ] ]);
	}
else {
	# Older FreeBSD's have fewer options
	local $dnsopt = $_[0]->{'order'} =~ /dns/ ? 'dns' : 'bind';
	return &common_order_input("order", $_[0]->{'order'},
		[ [ "hosts", "Hosts" ], [ $dnsopt, "DNS" ], [ "nis", "NIS" ] ]);
	}
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

# get_hostname()
sub get_hostname
{
local %rc = &get_rc_conf();
if ($rc{'hostname'}) {
	return $rc{'hostname'};
	}
return &get_system_hostname();
}

# save_hostname(name)
sub save_hostname
{
&lock_file("/etc/rc.conf");
&system_logged("hostname $_[0] >/dev/null 2>&1");
&save_rc_conf('hostname', $_[0]);
&unlock_file("/etc/rc.conf");
undef(@main::get_system_hostname);      # clear cache
}

sub routing_config_files
{
return ( "/etc/defaults/rc.conf", "/etc/rc.conf" );
}

sub routing_input
{
local %rc = &get_rc_conf();

# Default router
local $defr = $rc{'defaultrouter'};
print &ui_table_row($text{'routes_default'},
	&ui_opt_textbox("defr", $defr eq 'NO' ? '' : $defr, 20,
			$text{'routes_none'}));

if (&supports_address6()) {
	# IPv6 efault router
	local $defr = $rc{'ipv6_defaultrouter'};
	print &ui_table_row($text{'routes_default6'},
		&ui_opt_textbox("defr6", $defr eq 'NO' ? '' : $defr, 20,
				$text{'routes_none'}));
	}

# Act as router?
local $gw = $rc{'gateway_enable'};
print &ui_table_row($text{'routes_forward'},
	&ui_radio("gw", $gw || 'NO', [ [ 'YES', $text{'yes'} ],
				       [ 'NO', $text{'no'} ] ]));

# Run route discovery
local $rd = $rc{'router_enable'};
print &ui_table_row($text{'routes_routed'},
	&ui_radio("rd", $rd || 'NO', [ [ 'YES', $text{'yes'} ],
				       [ 'NO', $text{'no'} ] ]));
}

sub parse_routing
{
&lock_file("/etc/rc.conf");
$in{'defr_def'} || &check_ipaddress($in{'defr'}) ||
	&error(&text('routes_edefault', $in{'defr'}));
&save_rc_conf('defaultrouter', $in{'defr_def'} ? 'NO' : $in{'defr'});
if (&supports_address6()) {
	$in{'defr6_def'} || &check_ip6address($in{'defr6'}) ||
		&error(&text('routes_edefault6', $in{'defr6'}));
	&save_rc_conf('ipv6_defaultrouter',
		      $in{'defr6_def'} ? 'NO' : $in{'defr6'});
	}
&save_rc_conf('gateway_enable', $in{'gw'});
&save_rc_conf('router_enable', $in{'rd'});
&unlock_file("/etc/rc.conf");
}

# save_rc_conf(name, value)
sub save_rc_conf
{
local $found;
&open_readfile(CONF, "/etc/rc.conf");
local @conf = <CONF>;
close(CONF);
&open_tempfile(CONF, ">/etc/rc.conf");
foreach (@conf) {
	if (/^\s*([^=]+)\s*=\s*(.*)/ && $1 eq $_[0]) {
		&print_tempfile(CONF, "$_[0]=\"$_[1]\"\n") if (@_ > 1);
		$found++;
		}
	else {
		&print_tempfile(CONF, $_);
		}
	}
if (!$found && @_ > 1) {
	&print_tempfile(CONF, "$_[0]=\"$_[1]\"\n");
	}
&close_tempfile(CONF);
}

# get_rc_conf()
sub get_rc_conf
{
local ($file, %rv);
foreach $file ("/etc/defaults/rc.conf",
	       glob("/etc/rc.conf.d/*"),
	       "/etc/rc.conf") {
	&open_readfile(FILE, $file);
	while(<FILE>) {
		s/\r|\n//g;
		s/#.*$//;
		if (/^\s*([^=\s]+)\s*=\s*"(.*)"/ ||
		    /^\s*([^=\s]+)\s*=\s*(\S+)/) {
			$rv{$1} = $2;
			}
		}
	close(FILE);
	}
return %rv;
}

# apply_network()
# Apply the interface and routing settings
sub apply_network
{
local $oldpwd = &get_current_dir();
chdir("/");

# Take down all active alias interfaces, and any that no longer exist
local %boot = map { $_->{'fullname'}, $_ } &boot_interfaces();
foreach my $i (&active_interfaces()) {
	if ($i->{'virtual'} ne '' || !$boot{$i->{'fullname'}}) {
		&deactivate_interface($i);
		}
	}
# Bring everything up
&system_logged("/etc/netstart >/dev/null 2>&1");
chdir($oldpwd);
}

# supports_address6([&iface])
# Returns 1 if managing IPv6 interfaces is supported
sub supports_address6
{
local ($iface) = @_;
return $gconfig{'os_version'} >= 8;
}

# list_routes()
# Returns a list of active routes
sub list_routes
{
local @rv;
&open_execute_command(ROUTES, "netstat -rn", 1, 1);
while(<ROUTES>) {
	s/\s+$//;
	if (/^([0-9\.]+|default)(\/\d+)?\s+([0-9\.]+|link\S+)\s+\S+\s+\S+\s+\S+\s+(\S+)/) {
		my $r = { 'dest' => $1,
			  'gateway' => $3,
			  'netmask' => $2,
			  'iface' => $4 };
		if ($r->{'gateway'} =~ /^link/) {
			$r->{'gateway'} = '0.0.0.0';
			}
		if ($r->{'dest'} eq 'default' &&
		    &check_ip6address($r->{'gateway'})) {
			$r->{'dest'} = '::';
			}
		elsif ($r->{'dest'} eq 'default') {
			$r->{'dest'} = '0.0.0.0';
			}
		if ($r->{'netmask'} =~ /^\/(\d+)$/) {
			$r->{'netmask'} = &prefix_to_mask($1);
			}
		push(@rv, $r);
		}
	}
close(ROUTES);
return @rv;
}

# get_default_gateway()
# Returns the default gateway IP (if one is set) and device (if set) boot time
# settings.
sub get_default_gateway
{
local %rc = &get_rc_conf();
return ( $rc{'defaultrouter'} eq 'NO' ? undef : $rc{'defaultrouter'},
	 undef );
}

# set_default_gateway(gateway, device)
# Sets the default gateway to the given IP accessible via the given device,
# in the boot time settings.
sub set_default_gateway
{
local ($gw, $gwdev) = @_;
&lock_file("/etc/rc.conf");
&save_rc_conf('defaultrouter', $gw || "NO");
&unlock_file("/etc/rc.conf");
}

1;

