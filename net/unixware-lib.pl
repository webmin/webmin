# unixware-lib.pl
# Networking functions for UnixWare

# active_interfaces()
# Returns a list of currently ifconfig'd interfaces
sub active_interfaces
{
local(@rv, @lines, $l);
&open_execute_command(IFC, "ifconfig -a", 1, 1);
while(<IFC>) {
	s/\r|\n//g;
	if (/^\S+:/) { push(@lines, $_); }
	else { $lines[$#lines] .= $_; }
	}
close(IFC);
foreach $l (@lines) {
	local %ifc;
	$l =~ /^([^:\s]+):/; $ifc{'name'} = $1;
	$l =~ /^(\S+):/; $ifc{'fullname'} = $1;
	if ($l =~ /^(\S+):(\d+):\s/) { $ifc{'virtual'} = $2; }
	if ($l =~ /inet\s+(\S+)/) { $ifc{'address'} = $1; }
	if ($l =~ /netmask\s+(\S+)/) { $ifc{'netmask'} = &parse_hex($1); }
	if ($l =~ /broadcast\s+(\S+)/) { $ifc{'broadcast'} = $1; }
	if ($l =~ /ether\s+(\S+)/) { $ifc{'ether'} = $1; }
	if ($l =~ /mtu\s+(\S+)/) { $ifc{'mtu'} = $1; }
	$ifc{'up'}++ if ($l =~ /\<UP/);
	$ifc{'edit'} = ($ifc{'name'} !~ /ipdptp|ppp/);
	$ifc{'index'} = scalar(@rv);
	if ($ifc{'ether'}) {
		$ifc{'ether'} = join(":", map { sprintf "%2.2d", $_ }
					      split(/:/, $ifc{'ether'}));
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
if ($a->{'virtual'} eq "") {
	local $out = &backquote_logged("ifconfig $a->{'name'} plumb 2>&1");
	if ($out) { &error("Interface '$a->{'name'}' does not exist"); }
	}
local $cmd = "ifconfig $a->{'name'}";
if ($a->{'virtual'} ne "") { $cmd .= ":$a->{'virtual'}"; }
$cmd .= " $a->{'address'}";
if ($a->{'netmask'}) { $cmd .= " netmask $a->{'netmask'}"; }
else { $cmd .= " netmask +"; }
if ($a->{'broadcast'}) { $cmd .= " broadcast $a->{'broadcast'}"; }
else { $cmd .= " broadcast +"; }
if ($a->{'mtu'}) { $cmd .= " mtu $a->{'mtu'}"; }
if ($a->{'up'}) { $cmd .= " up"; }
else { $cmd .= " down"; }
local $out = &backquote_logged("$cmd 2>&1");
if ($?) { &error($out); }
if ($a->{'ether'}) {
	$out = &backquote_logged(
		"ifconfig $a->{'name'} ether $a->{'ether'} 2>&1");
	if ($? && $out !~ /Device busy/) { &error($out); }
	}
}

# deactivate_interface(&details)
# Deactive an interface
sub deactivate_interface
{
local $cmd;
if ($a->{'virtual'} eq "") {
	$cmd = "ifconfig $a->{'name'} unplumb";
	}
else {
	$cmd = "ifconfig $a->{'name'}:$a->{'virtual'} 0.0.0.0 down";
	}
local $out = &backquote_logged("$cmd 2>&1");
if ($?) { &error($out); }
}

# boot_interfaces()
# Returns a list of interfaces brought up at boot time
sub boot_interfaces
{
local (@rv, $f, %mask);
push(@rv, { 'name' => 'lo0',
	    'fullname' => 'lo0',
	    'address' => '127.0.0.1',
	    'netmask' => '255.0.0.0',
	    'up' => 1,
	    'edit' => 0 });
open(MASK, "/etc/netmasks");
while(<MASK>) {
	s/\r|\n//g;
	s/#.*$//g;
	if (/([0-9\.]+)\s+([0-9\.]+)/) {
		$mask{$1} = $2;
		}
	}
close(MASK);
opendir(ETC, "/etc");
while($f = readdir(ETC)) {
	if ($f =~ /^hostname.(\S+):(\d+)$/ || $f =~ /^hostname.(\S+)/) {
		local %ifc;
		$ifc{'fullname'} = $ifc{'name'} = $1;
		$ifc{'virtual'} = $2 if (defined($2));
		$ifc{'fullname'} .= ":$2" if (defined($2));
		$ifc{'index'} = scalar(@rv);
		$ifc{'edit'}++;
		$ifc{'file'} = "/etc/$f";
		open(FILE, "/etc/$f");
		chop($ifc{'address'} = <FILE>);
		close(FILE);
		if ($ifc{'address'}) {
			&to_ipaddress($ifc{'address'})
				=~ /(\d+)\.(\d+)\.(\d+)\.(\d+)/;
			if ($mask{"$1.$2.$3.0"})
				{ $ifc{'netmask'} = $mask{"$1.$2.$3.0"}; }
			elsif ($mask{"$1.$2.0.0"})
				{ $ifc{'netmask'} = $mask{"$1.$2.0.0"}; }
			elsif ($mask{"$1.0.0.0"})
				{ $ifc{'netmask'} = $mask{"$1.0.0.0"}; }
			else
				{ $ifc{'netmask'} = "255.255.255.0"; }
			local ($a1, $a2, $a3, $a4) = ($1, $2, $3, $4);
			$ifc{'netmask'} =~ /(\d+)\.(\d+)\.(\d+)\.(\d+)/;
			$ifc{'broadcast'} = sprintf "%d.%d.%d.%d",
						($a1 | ~int($1))&0xff,
						($a2 | ~int($2))&0xff,
						($a3 | ~int($3))&0xff,
						($a4 | ~int($4))&0xff;
			}
		else {
			$ifc{'netmask'} = "Automatic";
			$ifc{'broadcast'} = "Automatic";
			$ifc{'dhcp'}++;
			}
		$ifc{'up'}++;
		push(@rv, \%ifc);
		}
	}
closedir(ETC);
return @rv;
}

# save_interface(&details)
# Create or update a boot-time interface
sub save_interface
{
local $name = $_[0]->{'virtual'} ne "" ? $_[0]->{'name'}.":".$_[0]->{'virtual'}
				       : $_[0]->{'name'};
&open_lock_tempfile(IFACE, ">/etc/hostname.$name");
if (!$_[0]->{'dhcp'}) {
	&print_tempfile(IFACE, $_[0]->{'address'},"\n");
	}
&close_tempfile(IFACE);
}

# delete_interface(&details)
# Delete a boot-time interface
sub delete_interface
{
local $name = $_[0]->{'virtual'} ne "" ? $_[0]->{'name'}.":".$_[0]->{'virtual'}
				       : $_[0]->{'name'};
&unlink_logged("/etc/hostname.$name");
}

# iface_type(name)
# Returns a human-readable interface type name
sub iface_type
{
return "Fast Ethernet" if ($_[0] =~ /^hme/);
return "Loopback" if ($_[0] =~ /^lo/);
return "Token Ring" if ($_[0] =~ /^tr/);
return "PPP" if ($_[0] =~ /^ipdptp/ || $_[0] =~ /^ppp/);
return "Ethernet";
}

# iface_hardware(name)
# Does some interface have an editable hardware address
sub iface_hardware
{
return $_[0] !~ /^(lo|ipdptp|ppp)/;
}

# can_edit(what)
# Can some boot-time interface parameter be edited?
sub can_edit
{
return $_[0] eq "dhcp";
}

# valid_boot_address(address)
# Is some address valid for a bootup interface
sub valid_boot_address
{
return &to_ipaddress($_[0]) ? 1 : 0;
}

# get_dns_config()
# Returns a hashtable containing keys nameserver, domain, search & order
sub get_dns_config
{
local $dns;
open(RESOLV, "/etc/resolv.conf");
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
open(SWITCH, "/etc/nsswitch.conf");
while(<SWITCH>) {
	s/\r|\n//g;
	if (/hosts:\s+(.*)/) {
		$dns->{'order'} = $1;
		}
	}
close(SWITCH);
$dns->{'files'} = [ "/etc/resolv.conf", "/etc/nsswitch.conf" ];
return $dns;
}

# save_dns_config(&config)
# Writes out the resolv.conf and nsswitch.conf files
sub save_dns_config
{
&lock_file("/etc/resolv.conf");
open(RESOLV, "/etc/resolv.conf");
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

&lock_file("/etc/nsswitch.conf");
open(SWITCH, "/etc/nsswitch.conf");
local @switch = <SWITCH>;
close(SWITCH);
&open_tempfile(SWITCH, ">/etc/nsswitch.conf");
foreach (@switch) {
	if (/hosts:\s+/) {
		&print_tempfile(SWITCH, "hosts:\t$_[0]->{'order'}\n");
		}
	else {
		&print_tempfile(SWITCH, $_);
		}
	}
&close_tempfile(SWITCH);
&unlock_file("/etc/nsswitch.conf");
}

$max_dns_servers = 3;

# order_input(&dns)
# Returns HTML for selecting the name resolution order
sub order_input
{
return &common_order_input("order", $_[0]->{'order'},
	[ [ "files", "Hosts" ], [ "dns", "DNS" ], [ "nis", "NIS" ],
	  [ "nisplus", "NIS+" ] ]);
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

sub get_hostname
{
return &get_system_hostname();
}

# save_hostname(name)
sub save_hostname
{
&system_logged("hostname $_[0] >/dev/null 2>&1");
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
&system_logged("domainname ".quotemeta($_[0]));
&lock_file("/etc/defaultdomain");
if ($_[0]) {
	&open_tempfile(DOMAIN, ">/etc/defaultdomain");
	&print_tempfile(DOMAIN, $_[0],"\n");
	&close_tempfile(DOMAIN);
	}
else {
	&unlink_file("/etc/defaultdomain");
	}
&unlock_file("/etc/defaultdomain");
}

sub routing_config_files
{
return ( "/etc/defaultrouter", "/etc/notrouter", "/etc/gateways" );
}

sub routing_input
{
# show default router(s) input
local(@defrt);
&open_readfile(DEFRT, "/etc/defaultrouter");
while(<DEFRT>) {
	s/#.*$//g;
	if (/(\S+)/) { push(@defrt, $1); }
	}
close(DEFRT);
print &ui_table_row($text{'routes_defaults'},
	&ui_textarea("defrt", join("\n", @defrt), 3, 40));

# show router input
local $notrt = (-r "/etc/notrouter");
local $gatew = (-r "/etc/gateways");
print &ui_table_row($text{'routes_forward'},
	&ui_radio("router", $gatew && !$notrt ? 0 :
			    !$gatew && !$notrt ? 1 : 2,
		  [ [ 0, $text{'yes'} ],
		    [ 1, $text{'routes_possible'} ],
		    [ 2, $text{'no'} ] ]));
}

sub parse_routing
{
local @defrt = split(/\s+/, $in{'defrt'});
foreach my $d (@defrt) {
	&to_ipaddress($d) || &error(&text('routes_edefault', $d));
	}
&lock_file("/etc/defaultrouter");
if (@defrt) {
	&open_tempfile(DEFRT, ">/etc/defaultrouter");
	foreach $d (@defrt) { &print_tempfile(DEFRT, $d,"\n"); }
	&close_tempfile(DEFRT);
	}
else {
	&unlink_file("/etc/defaultrouter");
	}
&unlock_file("/etc/defaultrouter");

&lock_file("/etc/gateways");
&lock_file("/etc/notrouter");
if ($in{'router'} == 0) {
	&create_empty_file("/etc/gateways");
	&unlink_file("/etc/notrouter");
	}
elsif ($in{'router'} == 2) {
	&create_empty_file("/etc/notrouter");
	&unlink_file("/etc/gateways");
	}
else {
	&unlink_file("/etc/gateways");
	&unlink_file("/etc/notrouter");
	}
&unlock_file("/etc/gateways");
&unlock_file("/etc/notrouter");
}

# create_empty_file(filename)
sub create_empty_file
{
if (!-r $_[0]) {
	&open_tempfile(EMPTY,">$_[0]");
	&close_tempfile(EMPTY);
	}
}

# supports_address6([&iface])
# Returns 1 if managing IPv6 interfaces is supported
sub supports_address6
{
local ($iface) = @_;
return 0;
}

1;

