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
		$ifc{'ether'} = join(":", map { sprintf "%2.2d", $_ }
					      split(/:/, $ifc{'ether'}));
		}
	push(@rv, \%ifc);

	# Add aliases as virtual interfaces. Try to match boot-time interface
	# numbers where possible
	local %vtaken = map { $_->{'virtual'}, 1 }
			    grep { $_->{'name'} eq $vifc{'name'} &&
				   $_->{'virtual'} ne "" } @boot;
	while($l =~ s/inet\s+(\S+)\s+netmask\s+(\S+)\s+broadcast\s+(\S+)//) {
		local %vifc = %ifc;
		$vifc{'address'} = $1;
		$vifc{'netmask'} = &parse_hex($2);
		$vifc{'broadcast'} = $3;
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
local %rc = &get_rc_conf();
local @rv;
foreach $r (keys %rc) {
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
	else { next; }
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
	push(@rv, \%ifc);
	}
return @rv;
}

# save_interface(&details)
# Create or update a boot-time interface
sub save_interface
{
local $str = "inet $_[0]->{'address'}";
$str .= " netmask $_[0]->{'netmask'}" if ($_[0]->{'netmask'});
$str .= " broadcast $_[0]->{'broadcast'}" if ($_[0]->{'broadcast'});
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
	$_[0] =~ /^(bge|em)/ ? "Gigabit ethernet" :
	$_[0] =~ /^(ax|mx|pn|rl|tx|wb)/ ? "Fast ethernet" :
	$_[0] =~ /^(cs|dc|de|ed|el|ex|fe|fxp|ie|le|lnc|tl|vr|vx|xl|ze|zp)/ ? "Ethernet" : $text{'ifcs_unknown'};
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
return $_[0] =~ /netmask|broadcast/;
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

&open_readfile(HOST, "/etc/host.conf");
while(<HOST>) {
	s/\r|\n//g;
	s/#.*$//;
	push(@{$dns->{'order'}}, $_) if (/\S/);
	}
close(HOST);
$dns->{'files'} = [ "/etc/resolv.conf", "/etc/host.conf" ];
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

&open_lock_tempfile(HOST, ">/etc/host.conf");
foreach (@{$_[0]->{'order'}}) {
	&print_tempfile(HOST, $_,"\n");
	}
&close_tempfile(HOST);
}

$max_dns_servers = 3;

# order_input(&dns)
# Returns HTML for selecting the name resolution order
sub order_input
{
local @o = @{$_[0]->{'order'}};
local ($rv, $i, $j);
local @srcs = ( "", "hosts", "bind", "nis" );
local @srcn = ( "", "Hosts", "DNS", "NIS" );
for($i=1; $i<@srcs; $i++) {
	local $ii = $i-1;
	$rv .= "<select name=order_$ii>\n";
	for($j=0; $j<@srcs; $j++) {
		$rv .= sprintf "<option value=\"%s\" %s>%s\n",
				$srcs[$j],
				$o[$ii] eq $srcs[$j] ? "selected" : "",
				$srcn[$j] ? $srcn[$j] : "&nbsp;";
		}
	$rv .= "</select>\n";
	}
return $rv;
}

# parse_order(&dns)
# Parses the form created by order_input()
sub parse_order
{
local($i, @order);
for($i=0; defined($in{"order_$i"}); $i++) {
	push(@order, $in{"order_$i"}) if ($in{"order_$i"});
	}
$_[0]->{'order'} = \@order;
}

# get_hostname()
sub get_hostname
{
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
local $defr = $rc{'defaultrouter'};
print "<tr> <td><b>$text{'routes_default'}</b></td> <td>\n";
printf "<input name=defr_def type=radio value=1 %s> %s\n",
	$defr eq 'NO' ? 'checked' : '', $text{'routes_none'};
printf "<input name=defr_def type=radio value=0 %s>\n",
	$defr eq 'NO' ? '' : 'checked';
printf "<input name=defr size=20 value='%s'></td> </tr>\n",
	$defr eq 'NO' ? '' : $defr;

local $gw = $rc{'gateway_enable'};
print "<tr> <td><b>$text{'routes_forward'}</b></td> <td>\n";
printf "<input name=gw type=radio value=YES %s> %s\n",
	$gw eq 'YES' ? 'checked' : '', $text{'yes'};
printf "<input name=gw type=radio value=NO %s> %s</td> </tr>\n",
	$gw eq 'YES' ? '' : 'checked', $text{'no'};

local $rd = $rc{'router_enable'};
print "<tr> <td><b>$text{'routes_routed'}</b></td> <td>\n";
printf "<input name=rd type=radio value=YES %s> %s\n",
	$rd eq 'YES' ? 'checked' : '', $text{'yes'};
printf "<input name=rd type=radio value=NO %s> %s</td> </tr>\n",
	$rd eq 'YES' ? '' : 'checked', $text{'no'};
}

sub parse_routing
{
&lock_file("/etc/rc.conf");
$in{'defr_def'} || &check_ipaddress($in{'defr'}) ||
	&error(&text('routes_edefault', $in{'defr'}));
&save_rc_conf('defaultrouter', $in{'defr_def'} ? 'NO' : $in{'defr'});
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
foreach $file ("/etc/defaults/rc.conf", "/etc/rc.conf") {
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
&system_logged("(cd / ; /etc/netstart) >/dev/null 2>&1");
}

sub os_feedback_files
{
return ( "/etc/rc.conf", "/etc/resolv.conf", "/etc/host.conf",
	 "/etc/resolv.conf" );
}

1;

