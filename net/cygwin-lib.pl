# cygwin-lib.pl
# Networking functions for cygwin
#
# TODO:
# * detect when netsh isn't available
# * save domain list
# * save domainname

my $logfile = "/dev/null";
#my $logfile = "/tmp/debugwb";

#define variables that modify the behavior of the .cgi scripts
#that are different than any other OS.
$noos_support_add_ifcs = 1; #Windows doesn't supporting adding interfaces
$noos_support_delete_ifcs = 1; #Windows doesn't supporting deleting interfaces
$always_apply_ifcs = 1; #Changes made to interfaces are always applied
$routes_active_now = 1; #Changes made to routes are always applied
#Note: some changes Windows requires a reboot, some don't.
#TODO2: determine which changes require a reboot.

# active_interfaces()
# Returns a list of currently ifconfig'd interfaces
# ifc keys: 'name','fullname','virtual','address','netmask','broadcast',
#           'ether','mtu','up','edit','index','dhcp'
sub active_interfaces
{
    local(@rv, @lines, $line);
    &open_execute_command(IFC, "ipconfig /all", 1, 1);
    while (<IFC>) {
	s/\r|\n//g;
	push(@lines, $_);
    }
    close(IFC);
    #Need to get the list of boottime interfaces, because ipconfig /all
    #doesn't return ipaddr if cable is disconnected
    my @bootifs = boot_interfaces();
    my %ifc = ();
    foreach $line (@lines) {
	if ($line =~ /Ethernet adapter (.*):/) {
	    my $name = $1;
	    if (defined($ifc{'name'})) {
		#save the previous one
		$ifc{'index'} = scalar(@rv);
		local ($a1, $a2, $a3, $a4) = ($1, $2, $3, $4);
		if ($ifc{'address'}) {
		    $ifc{'netmask'} =~ /(\d+)\.(\d+)\.(\d+)\.(\d+)/;
		    $ifc{'broadcast'} = sprintf("%d.%d.%d.%d",
						($a1 | ~int($1))&0xff,
						($a2 | ~int($2))&0xff,
						($a3 | ~int($3))&0xff,
						($a4 | ~int($4))&0xff);
		}
		my %tmp = %ifc;
		push(@rv, \%tmp);
	    }
	    %ifc = ();
	    $ifc{'name'} = $ifc{'fullname'} = $name;
	}
	elsif ($line =~ /Media State.*: (.*)/) {
	    $ifc{'up'} = ($1 !~ /Disconnected/);
	    foreach (@bootifs) {
		if ($_->{'name'} eq $ifc{'name'}) {
		    $ifc{'dhcp'} = $_->{'dhcp'};
		    $ifc{'address'} = $_->{'address'};
		    $ifc{'netmask'} = $_->{'netmask'};
		}
	    }
	}
	elsif ($line =~ /Description.*: (.*) \#(\d+)\s*$/) {
	    $ifc{'desc'} = $1;
	    $ifc{'index'} = $2;
	}
	elsif ($line =~ /Description.*: (.*)$/) {
	    $ifc{'desc'} = $1;
	    chop($ifc{'desc'});
	    $ifc{'num'} = 1;
	}
	elsif ($line =~ /Physical Address.*: (.+)$/) {
	    $ifc{'ether'} = $1;
	    $ifc{'ether'} =~ s/-/:/g;
	}
	elsif ($line =~ /IP Address.*: (.+)$/) {
	    $ifc{'address'} = $1;
	    $ifc{'up'} = 1 if ! defined $ifc{'up'};
	}
	elsif ($line =~ /Subnet Mask.*: (.+)$/) {
	    $ifc{'netmask'} = $1;
	}
	elsif ($line =~ /Default Gateway.*: (.+)$/) {
	    #this is used for the router subroutines below
	    $ifc{'gateway'} = $1;
	}
	elsif ($line =~ /DHCP Enabled.*: (.+)$/) {
	    $ifc{'dhcp'} = ($1 =~ /Yes/);
	}
    }
    if (defined($ifc{'name'})) {
	#save the last one
	$ifc{'index'} = scalar(@rv);
	local ($a1, $a2, $a3, $a4) = ($1, $2, $3, $4);
	if ($ifc{'address'}) {
	    $ifc{'netmask'} =~ /(\d+)\.(\d+)\.(\d+)\.(\d+)/;
	    $ifc{'broadcast'} = sprintf("%d.%d.%d.%d",
					($a1 | ~int($1))&0xff,
					($a2 | ~int($2))&0xff,
					($a3 | ~int($3))&0xff,
					($a4 | ~int($4))&0xff);
	}
	my %tmp = %ifc;
	push(@rv, \%tmp);
    }
    return @rv;
}

# activate_interface(&details)
# Create or modify an interface
sub activate_interface
{
    save_interface($@);
    #Windows doesn't support adding or removing interfaces
}

# apply_interface(&details)
# Save changes to an interface active now
sub apply_interface
{
    save_interface($@);
}

# deactivate_interface(&details)
# Deactive an interface
sub deactivate_interface
{
    #TODO2: determine how to deactivate an interface
}

# boot_interfaces()
# Returns a list of interfaces brought up at boot time
sub boot_interfaces
{
    my @rv = ();
    #It doesn't seem to really help to display the loopback since
    #there's no mechanism in Windows to edit it.
#    push(@rv, { 'name' => 'lo0',
#		'fullname' => 'lo0',
#		'address' => '127.0.0.1',
#		'netmask' => '255.0.0.0',
#		'up' => 1,
#		'edit' => 0 });
    my (@lines, $l);
    &open_execute_command(IFC, "netsh interface ip dump", 1);
    while (<IFC>) {
	s/\r|\n//g;
	push(@lines, $_);
    }
    close(IFC);
    #my %ifc = ();
    foreach $l (@lines) {
	#TODO2: handle this message:
	#"Cannot access configuration.
	# Connection UI or someone else is accessing it."
	if ($l =~ /^set address name = "(.*)" source = dhcp/) {
	    local %ifc;
	    $ifc{'fullname'} = $ifc{'name'} = $1;
	    $ifc{'index'} = scalar(@rv);
	    $ifc{'edit'}++;
	    $ifc{'dhcp'} = 1;
	    $ifc{'up'} = 1;
	    push(@rv, \%ifc);
	} elsif ($l =~ /^set address name = "(.*)" source = static addr = ([\d\.]+) mask = ([\d\.]+)/) {
	    local %ifc;
	    $ifc{'fullname'} = $ifc{'name'} = $1;
	    $ifc{'address'} = $2;
	    $ifc{'netmask'} = $3;
	    $ifc{'index'} = scalar(@rv);
	    $ifc{'edit'}++;
	    $ifc{'address'} =~ /(\d+)\.(\d+)\.(\d+)\.(\d+)/;
	    local ($a1, $a2, $a3, $a4) = ($1, $2, $3, $4);
	    $ifc{'netmask'} =~ /(\d+)\.(\d+)\.(\d+)\.(\d+)/;
	    $ifc{'broadcast'} = sprintf("%d.%d.%d.%d",
					($a1 | ~int($1))&0xff,
					($a2 | ~int($2))&0xff,
					($a3 | ~int($3))&0xff,
					($a4 | ~int($4))&0xff);
	    $ifc{'dhcp'} = 0;
	    $ifc{'up'} = 1;
	    push(@rv, \%ifc);
	} elsif ($l =~ /^set address name = "(.*)" gateway = ([\d\.]+) gwmetric = (\d)/) {
	    foreach (@rv) {
		if ($_->{'name'} eq $1) {
		    $_->{'gateway'} = $2;
		    $_->{'gwmetric'} = $3;
		}
	    }
	}
    }
    return @rv;
}

# save_interface(&details)
# Create or update a boot-time interface
sub save_interface
{
    my $ifc = $_[0];
    my $cmd = "netsh interface ip set address name = \"" .
	"$ifc->{'name'}\" source = ";
    if ($ifc->{'dhcp'}) {
	$cmd .= "dhcp";
    } else {
	$cmd .= "static addr = $ifc->{'address'} mask = $ifc->{'netmask'}";
    }
    system_logged("$cmd >$logfile 2>&1");
}

# delete_interface(&details)
# Delete a boot-time interface
sub delete_interface
{
    #Windows doesn't support adding or removing interfaces
}

# iface_type(name)
# Returns a human-readable interface type name
sub iface_type
{
#TODO2
#return "Fast Ethernet" if
#return "Token Ring" if
#return "PPP" if
return "Loopback" if $_[0] =~ /^lo0$/;
return "Ethernet";
}

# iface_hardware(name)
# Does some interface have an editable hardware address
sub iface_hardware
{
#TODO2: PPP
return $_[0] !~ /^(lo\d)$/;
}

# can_edit(what)
# Can some boot-time interface parameter be edited?
sub can_edit
{
return $_[0] =~ /^(dhcp|netmask)$/;
}

# valid_boot_address(address)
# Is some address valid for a bootup interface
sub valid_boot_address
{
return &to_ipaddress($_[0]) ? 1 : 0;
}

# get_dns_config()
# Returns a hashtable containing keys nameserver, domain, order
sub get_dns_config
{
    my @lines = ();
    my $dns = {'domain' => []};
    my $i = 0;
    if (&open_execute_command(CMD, "ipconfig /all", 1)) {
	my $doing_domain = 0;
	while (<CMD>) {
	    s/[\n\r]//g;
	    if ($doing_domain) {
		if (/(Ethernet adapter|:)/) {
		    $doing_domain = 0;
		} elsif (/^\s*([^:]+\.[^:]+)$/) {
		    push(@{$dns->{"domain"}}, $1);
		}
	    }
	    if (/Primary DNS Suffix.*: (.*)/) {
		push(@{$dns->{"domain"}}, $1);
	    } elsif (/DNS Suffix Search List.*: (.*)/) {
		$doing_domain = 1;
		push(@{$dns->{"domain"}}, $1);
	    } elsif (/^Ethernet adapter (.*):/) {
		$dns->{"name"}[$i++] = $1;
	    }
	}
	close(CMD);
    }
    if (&open_execute_command(CMD, "netsh interface ip show dns", 1)) {
	my $doing_nameserver = 0;
	my $i = -1;
	my $key = "nameserver";
	while (<CMD>) {
	    s/\r|\n//g;
	    if ($doing_nameserver) {
		if (/(Configuration for interface|:)/) {
		    $doing_nameserver = 0;
		} elsif (/^\s*([\d\.]+)/) {
		    push(@{$dns->{$key}}, $1);
		}
	    }
	    if (/Configuration for interface "(.*)"/) {
		$dns->{'name'}[++$i] = $1;
		$key = "nameserver";
		$key .= $i if $i > 0;
	    } elsif (/Statically Configured DNS Servers:\s*([\d\.]+)/) {
		push(@{$dns->{$key}}, $1);
		$doing_nameserver = 1;
	    }
	}
	close(CMD);
    }
    return $dns;
}

# save_dns_config(&config)
# Configures the DNS settings
sub save_dns_config
{
    my $dns = $_[0];
    for ($i=0; $i < @{$dns->{'name'}}; $i++) {
	my $key = "nameserver";
	$key .= $i if $i > 0;
	if (@{$dns->{$key}}) {
	    my $cmd_fmt = "netsh interface ip %s dns name = \"" .
		$dns->{'name'}[$i] . "\"%s addr = %s";
	    my $addr = pop(@{$dns->{$key}});
	    my $cmd = sprintf($cmd_fmt, "set", " source = static", $addr);
	    &system_logged("$cmd >$logfile 2>&1");
	    #add the new ones (any old list of adds was erased by the set cmd)
	    foreach (@{$dns->{$key}}) {
		$cmd = sprintf($cmd_fmt, "add", "", $_);
		&system_logged("$cmd >$logfile 2>&1");
	    }
	} else {
	    #set it to be obtained automatically
	    my $cmd = "netsh interface ip set dns name = \"" .
		$dns->{'name'}[$i] . "\" source = dhcp";
	    &system_logged("$cmd >$logfile 2>&1");
	    #any old list of adds was erased by the set cmd
	}
    }
    #TODO: support saving the domain list
    #if ($_[0]->{'domain'}) {
}

$max_dns_servers = 16; #more is possible, but this is realistic

# order_input(&dns)
# Returns HTML for selecting the name resolution order
sub order_input
{
#TODO2
}

# parse_order(&dns)
# Parses the form created by order_input()
sub parse_order
{
#TODO2
}

# get_hostname()
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
#TODO: determine how to get
return "";
}

# save_domainname(domain)
sub save_domainname
{
#TODO: determine how to set
}

sub routing_config_files
{
return map { $_->{'file'} } &boot_interfaces();
}

sub routing_input
{
    # show default router(s) input
    my @if = boot_interfaces();
    my $i = 0;
    foreach (@if) {
	next if $_->{'address'} eq "127.0.0.1";
	my $none_or_dhcp = defined($ifc{'gateway'}) ? 0 : 1;
	my $desc = $_->{'name'} . ($_->{'dhcp'}? "" : " ($_->{'address'})");
	print &ui_table_row("$desc $text{'routes_default'}",
		&ui_radio("gateway${i}_def", $none_or_dhcp,
		  [ [ 1, $text{'routes_none'} ],
		    [ 0, $text{'routes_gateway'}." ".
		         &ui_textbox("gateway$i", $_->{'gateway'}, 15)." ".
			 $text{'routes_gwmetric'}." ".
		         &ui_textbox("gwmetric$i", $_->{'gwmetric'}, 4) ] ]).
		&ui_hidden("ifname${i}", $_->{'name'}));
	$i++;
    }
}

sub parse_routing
{
    my $i = 0;
    my @if = boot_interfaces();
    while (defined($in{"gateway${i}_def"})) {
	my $name = $in{"ifname$i"};
	my $gateway = $in{"gateway$i"};
	my $gwmetric = $in{"gwmetric$i"};
	foreach (@if) {
	    if ($_->{'name'} eq $name) {
		if (! $in{"gateway${i}_def"}) {
		    if ($gateway != $_->{'gateway'} ||
			$gwmetric != $_->{'gwmetric'}) {
			&check_ipaddress($gateway) ||
			    &error(&text('routes_egateway', $gateway));
			my $cmd = "netsh interface ip set address name = \"" .
			    $_->{'name'} . "\" gateway = $gateway " .
				"gwmetric = $gwmetric";
			system_logged("$cmd > $logfile 2>&1");
		    }
		} else {
		    if (defined($_->{'gateway'})) {
			my $cmd = "netsh interface ip delete address name = \""
			    . $_->{'name'} . "\" gateway = $_->{'gateway'}";
			system_logged("$cmd > $logfile 2>&1");
		    }
		}
	    }
	}
	$i++;
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

