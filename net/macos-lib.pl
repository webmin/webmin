# macos-lib.pl
# Networking functions for OSX

$virtual_netmask = "255.255.255.255";	# Netmask for virtual interfaces

$iftab_file = "/etc/iftab";
$hostconfig_file = "/etc/hostconfig";

# active_interfaces()
# Returns a list of currently ifconfig'd interfaces
sub active_interfaces
{
local(@rv, @lines, $l);
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
	if ($l =~ s/inet\s+(\S+)\s+netmask\s+(\S+)\s+broadcast\s+(\S+)//) {
		$ifc{'address'} = $1;
		$ifc{'netmask'} = &parse_hex($2);
		$ifc{'broadcast'} = $3;
		}
	elsif ($l =~ s/inet\s+(\S+)\s+netmask\s+(\S+)//) {
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
		$ifc{'ether'} = join(":", map { sprintf "%2.2d", $_ }
					      split(/:/, $ifc{'ether'}));
		}
	push(@rv, \%ifc);

	# Add aliases as virtual interfaces
	local $v = 0;
	while($l =~ s/inet\s+(\S+)\s+netmask\s+(\S+)\s+broadcast\s+(\S+)//) {
		local %vifc = %ifc;
		$vifc{'address'} = $1;
		$vifc{'netmask'} = &parse_hex($2);
		$vifc{'broadcast'} = $3;
		$vifc{'up'} = 1;
		$vifc{'edit'} = $ifc{'edit'};
		$vifc{'virtual'} = $v++;
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
local %act;
map { $act{$_->{'fullname'}} = $_ } &active_interfaces();
local $old = $act{$_[0]->{'fullname'}};
$act{$_[0]->{'fullname'}} = $_[0];
&interface_sync(\%act, $_[0]->{'name'}, $_[0]->{'fullname'});
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

# interface_sync(interfaces, name, changee)
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
local @rv;
local %virtual_count;
local $lnum = 0;
&open_readfile(IFTAB, $iftab_file);
while(<IFTAB>) {
	s/\r|\n//g;
	s/#.*$//;
	if (/^(\S+)\s+(inet)\s+(.*)/i) {
		local $ifc = { 'name' => $1,
			       'index' => scalar(@rv),
			       'line' => $lnum };
		local $opts = $3;
		next if ($opts =~ /^!/);
		$ifc->{'edit'} = 1 if ($ifc->{'name'} =~ /^[a-z]+[0-9]*$/i);
		if ($opts eq "-AUTOMATIC-" || $opts eq "-BOOTP-") {
			$ifc->{'bootp'} = 1;
			$ifc->{'up'} = 1;
			}
		elsif ($opts eq "-DHCP-") {
			$ifc->{'dhcp'} = 1;
			$ifc->{'up'} = 1;
			}
		else {
			# Parse the ifconfig params
			if ($opts =~ /^([0-9\.]+)/) {
				$ifc->{'address'} = $1;
				}
			local @a = split(/\./, $ifc->{'address'});
			if ($opts =~ /netmask\s+([0-9\.]+)/) {
				$ifc->{'netmask'} = $1;
				}
			else {
				$ifc{'netmask'} = $a[0] >= 192 ? "255.255.255.0" :
						  $a[0] >= 128 ? "255.255.0.0" :
								 "255.0.0.0";
				}
			if ($opts =~ /broadcast\s+([0-9\.]+)/) {
				$ifc->{'broadcast'} = $1;
				}
			else {
				local @n = split(/\./, $ifc->{'netmask'});
				$ifc->{'broadcast'} = sprintf "%d.%d.%d.%d",
						($a[0] | ~int($n[0]))&0xff,
						($a[1] | ~int($n[1]))&0xff,
						($a[2] | ~int($n[2]))&0xff,
						($a[3] | ~int($n[3]))&0xff;
				}
			if ($opts =~ /mtu\s+([0-9\.]+)/) {
				$ifc->{'mtu'} = $1;
				}
			if ($opts =~ /\s+up/) {
				$ifc->{'up'} = 1;
				}
			if ($opts =~ /\s+alias/) {
				$ifc->{'up'} = 1;
				$ifc->{'virtual'} =
					int($virtual_count{$ifc->{'name'}}++);
				}
			}
		$ifc->{'fullname'} = $ifc->{'name'};
		$ifc->{'fullname'} .= ":$ifc->{'virtual'}"
			if ($ifc->{'virtual'} ne "");
		$ifc->{'file'} = $iftab_file;
		push(@rv, $ifc);
		}
	$lnum++;
	}
close(IFTAB);
return @rv;
}

# save_interface(&details)
# Create or update a boot-time interface
sub save_interface
{
local $str = "$_[0]->{'name'} inet";
if ($_[0]->{'dhcp'}) {
	$str .= " -DHCP-";
	}
elsif ($_[0]->{'bootp'}) {
	$str .= " -AUTOMATIC-";
	}
else {
	$str .= " $_[0]->{'address'}";
	$str .= " netmask $_[0]->{'netmask'}" if ($_[0]->{'netmask'});
	$str .= " broadcast $_[0]->{'broadcast'}" if ($_[0]->{'broadcast'});
	$str .= " mtu $_[0]->{'mtu'}" if ($_[0]->{'mtu'});
	if ($_[0]->{'virtual'} eq '') {
		$str .= " up";
		}
	else {
		$str .= " alias";
		}
	}
&lock_file($iftab_file);
local $lref = &read_file_lines($iftab_file);
local @boot = &boot_interfaces();
local ($old) = grep { $_->{'fullname'} eq $_[0]->{'fullname'} } @boot;
if ($old) {
	# Replacing existing interface
	$lref->[$old->{'line'}] = $str;
	}
else {
	# Adding new interface
	push(@$lref, $str);
	if ($_[0]->{'virtual'} ne '') {
		# Work out new virtual num
		$_[0]->{'virtual'} = 0;
		foreach $b (@boot) {
			if ($b->{'name'} eq $_[0]->{'name'} &&
			    $b->{'virtual'} ne '' &&
			    $b->{'virtual'} >= $_[0]->{'virtual'}) {
				$_[0]->{'virtual'} = $b->{'virtual'}+1;
				}
			}
		$_[0]->{'fullname'} = $_[0]->{'name'}.':'.$_[0]->{'virtual'};
		}
	}
&flush_file_lines();
&unlock_file($iftab_file);
}

# delete_interface(&details)
# Delete a boot-time interface
sub delete_interface
{
&lock_file($iftab_file);
local $lref = &read_file_lines($iftab_file);
splice(@$lref, $_[0]->{'line'}, 1);
&flush_file_lines();
&unlock_file($iftab_file);
}

# iface_type(name)
# Returns a human-readable interface type name
sub iface_type
{
return	$_[0] =~ /^ppp/ ? "PPP" :
	$_[0] =~ /^pppoe/ ? "PPPoE" :
	$_[0] =~ /^lo/ ? "Loopback" :
        $_[0] eq "*" ? $text{'ifcs_all'} :
	$_[0] =~ /^en/ ? "Ethernet" : $text{'ifcs_unknown'};
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
return $_[0] =~ /netmask|broadcast|dhcp|bootp/;
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
$dns->{'files'} = [ "/etc/resolv.conf" ];
return $dns;
}

# save_dns_config(&config)
# Writes out the resolv.conf file
sub save_dns_config
{
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
}

$max_dns_servers = 3;

# order_input(&dns)
# Returns HTML for selecting the name resolution order
sub order_input
{
return undef;
}

# parse_order(&dns)
# Parses the form created by order_input()
sub parse_order
{
return undef;
}

# get_hostname()
sub get_hostname
{
local $hc = &read_hostconfig();
if ($hc->{'HOSTNAME'}) {
	return $hc->{'HOSTNAME'};
	}
return &get_system_hostname();
}

# save_hostname(name)
sub save_hostname
{
&system_logged("hostname $_[0] >/dev/null 2>&1");
&lock_file($hostconfig);
&set_hostconfig("HOSTNAME", $_[0]);
&unlock_file($hostconfig);
undef(@main::get_system_hostname);      # clear cache
}

sub routing_config_files
{
return ( $hostconfig_file );
}

sub routing_input
{
local $hc = &read_hostconfig();
local $r = $hc->{'ROUTER'};
local $mode = $r eq "-AUTOMATIC-" ? 1 : $r ? 2 : 0;

# Default router
print &ui_table_row($text{'routes_default'},
	&ui_radio("router_mode", $mode,
		  [ [ 0, $text{'routes_none2'} ],
		    [ 1, $text{'routes_auto'} ],
		    [ 2, &ui_textbox("router", $mode == 2 ? $r : "", 20) ] ]));

# Forward traffic?
local $f = $hc->{'IPFORWARDING'};
print &ui_table_row($text{'routes_forward'},
	&ui_yesno_radio("forward", $f eq '-YES-'));
}

sub parse_routing
{
local $r;
if ($in{'router_mode'} == 0) {
	$r = undef;
	}
elsif ($in{'router_mode'} == 1) {
	$r = "-AUTOMATIC-";
	}
else {
	$r = $in{'router'};
	&check_ipaddress($r) || &error(&text('routes_edefault', $r));
	}
&lock_file($hostconfig_file);
&set_hostconfig("ROUTER", $r);
&set_hostconfig("IPFORWARDING", $in{'forward'} ? "-YES-" : "-NO-");
&unlock_file($hostconfig_file);
}

# set_hostconfig(name, value)
# Add or update an entry in the hostconfig file
sub set_hostconfig
{
local $lref = &read_file_lines($hostconfig_file);
local ($i, $found);
for($i=0; $i<@$lref; $i++) {
	if ($lref->[$i] =~ /^(\S+)\s*=/ && lc($1) eq lc($_[0])) {
		$lref->[$i] = "$_[0]=$_[1]";
		$found++;
		}
	}
if (!$found) {
	push(@$lref, "$_[0]=$_[1]");
	}
&flush_file_lines();
}

# read_hostconfig()
# Returns a hash of hostconfig file values
sub read_hostconfig
{
local %rv;
&open_readfile(HOST, $hostconfig_file);
while(<HOST>) {
	s/\r|\n//g;
	s/#.*$//;
	if (/^(\S+)\s*=\s*(.*)/) {
		$rv{$1} = $2;
		}
	}
close(HOST);
return \%rv;
}

# apply_network()
# Apply the interface and routing settings
#sub apply_network
#{
#system("killall ipconfigd && ipconfigd </dev/null >/dev/null 2>&1 &");
#system("ipconfig waitall >/dev/null 2>&1");
#local $hc = &read_hostconfig();
#system("killall -HUP netinfod >/dev/null 2>&1");
#system("killall -HUP lookupd >/dev/null 2>&1");
#}

# supports_address6([&iface])
# Returns 1 if managing IPv6 interfaces is supported
sub supports_address6
{
local ($iface) = @_;
return 0;
}

1;

