# debian-linux-lib.pl
# Networking functions for Debian linux >= 2.2 (aka. potato)
# Really, this won't work with releases prior to 2.2, don't even try it.
#
# Rene Mayrhofer, July 2000
# Some code has been taken from redhat-linux-lib.pl

use File::Copy;

$network_interfaces_config = '/etc/network/interfaces';
$modules_config = '/etc/modprobe.d/arch/i386';
if (!-d $modules_config) {
	($modules_config) = glob('/etc/modprobe.d/arch/*');
	}
$network_interfaces = '/proc/net/dev';

do 'linux-lib.pl';

# boot_interfaces()
# Returns a list of interfaces brought up at boot time
sub boot_interfaces
{
my @ifaces = &get_interface_defs();
my @autos = &get_auto_defs();
my @rv;
my %v6map;
foreach $iface (@ifaces) {
	my ($name, $addrfam, $method, $options) = @$iface;
	if ($addrfam eq 'inet') {
		# IPv4 interface .. parse and add to list
		my $cfg = { };
		$cfg->{'fullname'} = $name;
		if ($cfg->{'fullname'} =~ /(\S+):(\d+)/) {
			$cfg->{'name'} = $1;
			$cfg->{'virtual'} = $2;
			}
		else {
			$cfg->{'name'} = $cfg->{'fullname'};
			}
		if ($gconfig{'os_version'} >= 3 || scalar(@autos)) {
			$cfg->{'up'} = &indexof($name, @autos) >= 0;
			}
		else {
			$cfg->{'up'} = 1;
			}
		foreach $option (@$options) {
			my ($param, $value) = @$option;
			if ($param eq 'noauto') {
				$cfg->{'up'} = 0;
				}
			elsif($param eq 'up') { 
				$cfg->{"partner"} =
				  &get_teaming_partner($cfg->{'name'}, $value);
				%options = &get_module_defs($name);
				$cfg->{'mode'} = $options{'mode'};
				$cfg->{'miimon'} = $options{'miimon'};
				$cfg->{'downdelay'} = $options{'downdelay'};
				$cfg->{'updelay'} = $options{'updelay'};
				}
			elsif($param eq 'bond_mode') { 
				$cfg->{'mode'} = $value;
				}
			elsif($param eq 'bond_miimon') { 
				$cfg->{'miimon'} = $value;
				}
			elsif($param eq 'bond_downdelay') { 
				$cfg->{'downdelay'} = $value;
				}
			elsif($param eq 'bond_updelay') { 
				$cfg->{'updelay'} = $value;
				}
			elsif($param eq 'slaves') { 
				$cfg->{'partner'} = $value;
				}
			elsif($param eq 'hwaddr') {
				local @v = split(/\s+/, $value);
				$cfg->{'ether_type'} = $v[0];
				$cfg->{'ether'} = $v[1];
				}
			else {
				$cfg->{$param} = $value;
				}
			}
		$cfg->{'dhcp'} = ($method eq 'dhcp');
		$cfg->{'bootp'} = ($method eq 'bootp');
		$cfg->{'edit'} = ($cfg->{'name'} !~ /^ppp|lo/);
		$cfg->{'index'} = scalar(@rv);	
		$cfg->{'file'} = $network_interfaces_config;
		if (!$cfg->{'broadcast'} &&
		    $cfg->{'address'} && $cfg->{'netmask'}) {
			$cfg->{'broadcast'} = &compute_broadcast(
				$cfg->{'address'}, $cfg->{'netmask'});
			}
		push(@rv, $cfg);
		}
	elsif ($addrfam eq "inet6") {
		# IPv6 interface .. add to matching v4 block
		my $v6cfg = { 'address6' => [ ],
			      'netmask6' => [ ] };
		foreach $option (@$options) {
			my ($param, $value) = @$option;
			if ($param eq "address") {
				push(@{$v6cfg->{'address6'}}, $value);
				}
			elsif ($param eq "netmask") {
				push(@{$v6cfg->{'netmask6'}}, $value);
				}
			elsif ($param eq "up" &&
			       $value =~ /ifconfig\s+(\S+)\s+inet6\s+add\s+([a-f0-9:]+)\/(\d+)/ &&
				$1 eq $name) {
				# Additional v6 address
				push(@{$v6cfg->{'address6'}}, $2);
				push(@{$v6cfg->{'netmask6'}}, $3);
				}
			}
		$v6map{$name} = $v6cfg;
		}
	}
# Merge in v6 interface settings
foreach my $iface (@rv) {
	my $v6cfg = $v6map{$iface->{'fullname'}};
	if ($v6cfg) {
		foreach my $k (keys %$v6cfg) {
			$iface->{$k} = $v6cfg->{$k};
			}
		}
	}
return @rv;
}

# save_interface(&details)
# Create or update a boot-time interface
sub save_interface
{
my $cfg = $_[0];
my $name = $cfg->{'virtual'} ne "" ? $cfg->{'name'}.":".$cfg->{'virtual'}
				       : $cfg->{'name'};
my @options;
my $method;
my @modules_var;
if ($cfg->{'dhcp'} == 1) { $method = 'dhcp'; }
elsif ($cfg->{'bootp'} == 1) { $method = 'bootp'; }
else {
	$method = 'static';
	push(@options, ['address', $cfg->{'address'}]);
	push(@options, ['netmask', $cfg->{'netmask'}]);
	push(@options, ['broadcast', $cfg->{'broadcast'}])
	    if ($cfg->{'broadcast'} && !&is_ipv6_address($cfg->{'address'}));
	my ($ip1, $ip2, $ip3, $ip4) = split(/\./, $cfg->{'address'});
	my ($nm1, $nm2, $nm3, $nm4) = split(/\./, $cfg->{'netmask'});
	if ($cfg->{'address'} && $cfg->{'netmask'} && !&is_ipv6_address($cfg->{'address'})) {
		my $network = sprintf "%d.%d.%d.%d",
					($ip1 & int($nm1))&0xff,
					($ip2 & int($nm2))&0xff,
					($ip3 & int($nm3))&0xff,
					($ip4 & int($nm4))&0xff;
		push(@options, ['network', $network]);
		}
	if(&is_ipv6_address($cfg->{'address'})){
		push(@options, ['pre-up', 'modprobe ipv6']);
	}
	}
my @autos = get_auto_defs();
my $amode = $gconfig{'os_version'} > 3 || scalar(@autos);
if (!$cfg->{'up'} && !$amode) { push(@options, ['noauto', '']); }
if ($cfg->{'ether'}) {
	push(@options, [ 'hwaddr', ($cfg->{'ether_type'} || 'ether').' '.
				   $cfg->{'ether'} ]);
	}

# Set bonding parameters
if(($cfg->{'bond'} == 1) && ($gconfig{'os_version'} >= 5)) {
	push(@options, ['bond_mode ' . $cfg->{'mode'}]);
	push(@options, ['bond_miimon ' . $cfg->{'miimon'}]);
	push(@options, ['bond_updelay ' . $cfg->{'updelay'}]);
	push(@options, ['bond_downdelay ' . $cfg->{'downdelay'}]);
	push(@options, ['slaves ' . $cfg->{'partner'}]);
}
elsif($cfg->{'bond'} == 1) {
	push(@options, ['up', '/sbin/ifenslave ' . $cfg->{'name'} . " " . $cfg->{'partner'}]);
	push(@options, ['down', '/sbin/ifenslave -d ' . $cfg->{'name'} . " " . $cfg->{'partner'}]);
}

# Set specific lines for vlan tagging
if($cfg->{'vlan'} == 1){
	push(@options, ['pre-up', 'vconfig add ' . $cfg->{'physical'} . ' ' . $cfg->{'vlanid'}]);
	push(@options, ['post-down', 'vconfig rem ' . $cfg->{'physical'} . ' ' . $cfg->{'vlanid'}]);
}

my @ifaces = get_interface_defs();
my $changeit = 0;
foreach $iface (@ifaces) {
	local $address;
	foreach $opt(@{$iface->[3]}){
		if($opt->[0] eq 'address'){
			$address = $opt->[1];
			last;
		}			
	}
	if( ($iface->[0] eq $cfg->{'fullname'}) && 
	( ($iface->[1] eq 'inet' && !&is_ipv6_address($cfg->{'address'}))||
	  ($iface->[1] eq 'inet6' && &is_ipv6_address($cfg->{'address'}) && $address eq $cfg->{'address'}) ) ){
		$changeit = 1;
		foreach $o (@{$iface->[3]}) {
			if ($o->[0] eq 'gateway') {
				push(@options, $o);
			}
		}
	}
}
if ($changeit == 0) {
	if($in{'vlan'} == 1) {
		new_interface_def($cfg->{'physical'} . '.' . $cfg->{'vlanid'}, 'inet', $method, \@options);
	} elsif (&is_ipv6_address($cfg->{'address'})) {
		new_interface_def($cfg->{'name'}, 'inet6', $method, \@options);
	}
	else{
		new_interface_def($cfg->{'fullname'}, 'inet', $method, \@options);
	}
	if (($cfg->{'bond'} == 1) && ($gconfig{'os_version'} >= 5)) {}
	elsif ($cfg->{'bond'} == 1) {
		new_module_def($cfg->{'fullname'}, $cfg->{'mode'}, $cfg->{'miimon'}, $cfg->{'downdelay'}, $cfg->{'updelay'});
	}
} 
else {
	if($in{'vlan'} == 1) {
		modify_interface_def($cfg->{'physical'} . '.' . $cfg->{'vlanid'}, 'inet', $method, \@options, 0);
	} elsif (&is_ipv6_address($cfg->{'address'})) {
		modify_interface_def($cfg->{'name'}, 'inet6', $method, \@options, 0);
	}
	else{
		modify_interface_def($cfg->{'fullname'}, 'inet', $method, \@options, 0);
	}
	if (($cfg->{'bond'} == 1) && ($gconfig{'os_version'} >= 5)) {}
        elsif ($cfg->{'bond'} == 1) {
		modify_module_def($cfg->{'fullname'}, 0, $cfg->{'mode'}, $cfg->{'miimon'}, $cfg->{'downdelay'}, $cfg->{'updelay'});
	}
}

if ($amode) {
	if ($cfg->{'up'}) {
		if($in{'vlan'} == 1) {
			@autos = &unique(@autos, $cfg->{'physical'} . '.' . $cfg->{'vlanid'});
		} else {
			@autos = &unique(@autos, $cfg->{'fullname'});
 		}
	}
	else {
		@autos = grep { $_ ne $cfg->{'fullname'} } @autos;
		}
	&modify_auto_defs(@autos);
	}
}

# Modifies a entry in /etc/modprobe.d/arch/i386 that concerns
# to the interface mentioned
# modify_module_def(name, delete, mode, miimon, downdelay, updelay)
sub modify_module_def
{
        return if (!$modules_config);
	my ($name, $delete, $mode, $miimon, $downdelay, $updelay) = @_;
	my $modify_block = 0;
	
	# make a backup copy
	copy("$modules_config", "$modules_config~");
	local *OLDCFGFILE, *NEWCFGFILE;
	&open_readfile(OLDCFGFILE, "$modules_config~") ||
		error("Unable to open $modules_config");
	&lock_file($network_interfaces_config);
	&open_tempfile(NEWCFGFILE, "> $modules_config", 1) ||
		error("Unable to open $modules_config");

		
	while (defined ($line=<OLDCFGFILE>)) {
		chomp($line);
		@splitted_line = split(" ", $line);
		if($splitted_line[0] eq 'alias' && $splitted_line[1] eq $name) {
			# Found start of block we are changing
			$modify_block = 1;		
			if (!$delete) {
				&print_tempfile(NEWCFGFILE, $line . "\n");
				}
		} elsif ($splitted_line[0] eq 'alias' && !($splitted_line[1] eq $name)){
			# Found start of another block
			$modify_block = 0;
		}
		
		# if $delete == 1; write nothing
		if($modify_block == 1 && $splitted_line[0] eq "options" && $delete != 1) {
			$options_line = "options bonding ";
			for($i = 2; $i < scalar(@splitted_line); $i++){
					($key, $value) = split("=", $splitted_line[$i]);
					if($key eq "mode") {
						$options_line .= "mode=" . $mode . " ";
					} elsif($key eq "miimon") {
						$options_line .= "miimon=" . $miimon . " ";
					} elsif($key eq "downdelay") {
						$options_line .= "downdelay=" . $downdelay . " ";
					} elsif($key eq "updelay") {
						$options_line .= "updelay=" . $updelay . " ";
					} else {
						$options_line .= $key . "=" . $value . " ";
					}			
			}
			
			chop($options_line);
			&print_tempfile(NEWCFGFILE, $options_line . "\n");
			$modify_block == 0;
		} elsif($modify_block == 0) {
			&print_tempfile(NEWCFGFILE, $line . "\n");
		}
	}
	&close_tempfile(NEWCFGFILE);
	&unlock_file($modules_config);
}

# Deletes an the module concerning entry
# delete_module_def(name) 1 for deleting operation
sub delete_module_def
{
	my ($name) = @_;
	modify_interface_def($name, 1);
}

# get_module_defs(device)
# Returns the modul options form /etc/modprobe.d/arch/i386
# for a special device
# Return hash: ($mode, $miimon, $downdelay, $updelay)
sub get_module_defs
{
        return ( ) if (!$modules_config);
	local *CFGFILE;
	my($device) = @_;
	my %ret;
	&open_readfile(CFGFILE, $modules_config) ||
		error("Unable to open $modules_config");
	
	$line = <CFGFILE>;
	while(defined($line)){
		chomp($line);
		@params = split(" ", $line);
		
		# Search for an entry concerning to the device
		if($params[0] eq "alias" && $params[1] eq $device){
			$line = <CFGFILE>;
			chomp $line;
			@params = split(" ", $line);		
			# Check if it is an options line
			if($params[0] eq "options" && $params[1] eq "bonding") {
				for($i = 2; $i < scalar(@params); $i++){
					($key, $value) = split("=", $params[$i]);
					$ret{$key} = $value;	
				}
			}		
		}
		$line = <CFGFILE>;		
	}
	return %ret;
}

# creates a new entry for in the modules file
# Parameters should be (name, mode, miimon, downdelay, updelay)
sub new_module_def
{
	local ($name, $mode, $miimon, $downdelay, $updelay) = @_;
        return if (!$modules_config);
	copy("$modules_config", "$modules_config~");
	local *CFGFILE;
	&open_lock_tempfile(CFGFILE, ">> $modules_config") ||
		error("Unable to open $modules_config");
	&print_tempfile(CFGFILE, "alias " . $name . " bonding");
	&print_tempfile(CFGFILE, "\noptions bonding");
	
	if($mode ne '') {
		&print_tempfile(CFGFILE, " mode=" . $mode);
	}
	if($miimon ne '') {
		&print_tempfile(CFGFILE, " miimon=" . $miimon);
	}
	if($downdelay ne '') {
		&print_tempfile(CFGFILE, " downdelay=" . $downdelay);
	}
	if($updelay ne '') {
		&print_tempfile(CFGFILE, " updelay=" . $updelay);
	}
	# Add Newline
	&print_tempfile(CFGFILE, "\n");
	&close_tempfile(CFGFILE);
}

# delete_interface(&details)
# Delete a boot-time interface
sub delete_interface
{
my $cfg = $_[0];
	local @address = ('address',$cfg->{'address'});
	delete_interface_def(&is_ipv6_address($cfg->{'address'})?$cfg->{'name'}:$cfg->{'fullname'}, &is_ipv6_address($cfg->{'address'})?'inet6':'inet','',\@address);
	my @autos = get_auto_defs();
	if ($gconfig{'os_version'} >= 3 || scalar(@autos)) {
		@autos = grep { $_ ne $cfg->{'fullname'} } @autos;
		&modify_auto_defs(@autos);
	}
}

# can_edit(what)
# Can some boot-time interface parameter be edited?
sub can_edit
{
return $_[0] ne "mtu";
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
return ( $network_interfaces_config );
}

sub network_config_files
{
return ( "/etc/hostname", "/etc/HOSTNAME", "/etc/mailname" );
}

# show default router and device
sub routing_input
{
local ($addr, $router) = &get_default_gateway();
local @ifaces = &get_interface_defs();

# Show default gateway
print &ui_table_row($text{'routes_default'},
	&ui_radio("gateway_def", $addr ? 0 : 1,
		  [ [ 1, $text{'routes_none'} ],
		    [ 0, $text{'routes_gateway'}." ".
			 &ui_textbox("gateway", $addr, 15)." ".
			 &ui_select("gatewaydev", $router,
				[ map { $_->[0] } grep { $_->[0] ne 'lo' }
				      @ifaces ]) ] ]));

# Get static routes
local ($d, @st, @hr);
foreach $d (@ifaces) {
	local ($name, $addrfam, $method, $options) = @$d;
	local $o;
	local $onum = -1;
	foreach $o (@$options) {
		$onum++;
		next if ($o->[0] ne "up");
		if ($o->[1] =~ /^ip\s+route\s+add\s+([0-9\.]+)\/(\d+)\s+dev\s+(\S+)/) {
			push(@hr, [ $name, $1, &prefix_to_mask($2) ]);
			}
		elsif ($o->[1] =~ /^ip\s+route\s+add\s+([0-9\.]+)\/(\d+)\s+via\s+(\S+)/) {
			push(@st, [ $name, $1, &prefix_to_mask($2), $3 ]);
			}
		}
	}

# Show static routes via gateways
my @table;
for($i=0; $i<=@st; $i++) {
	local $st = $st[$i];
	push(@table, [ &ui_textbox("dev_$i", $st->[0], 6),
		       &ui_textbox("net_$i", $st->[1], 15),
		       &ui_textbox("netmask_$i", $st->[2], 15),
		       &ui_textbox("gw_$i", $st->[3], 15), ]);
	}
print &ui_table_row($text{'routes_static'},
	&ui_columns_table([ $text{'routes_ifc'}, $text{'routes_net'},
			    $text{'routes_mask'}, $text{'routes_gateway'} ],
			  undef, \@table, undef, 1));

# Show static host routes
my @table;
for($i=0; $i<=@hr; $i++) {
	local $st = $hr[$i];
	push(@table, [ &ui_textbox("ldev_$i", $st->[0], 6),
		       &ui_textbox("lnet_$i", $st->[1], 15),
		       &ui_textbox("lnetmask_$i", $st->[2], 15) ]);
	}
print &ui_table_row($text{'routes_local'},
	&ui_columns_table([ $text{'routes_ifc'}, $text{'routes_net'},
			    $text{'routes_mask'} ],
			  undef, \@table, undef, 1));
}

sub parse_routing
{
local ($dev, $gw);
if (!$in{'gateway_def'}) {
		&check_ipaddress_any($in{'gateway'}) ||
		&error(&text('routes_egateway', $in{'gateway'}));
	$gw = $in{'gateway'};
	$dev = $in{'gatewaydev'};
	}
&set_default_gateway($gw, $dev);

# Parse static and local routes
local %st;
local $i;
local $dev;
for($i=0; defined($dev = $in{"dev_$i"}); $i++) {
	next if (!$dev);
	local $net = $in{"net_$i"};
	local $netmask = $in{"netmask_$i"};
	local $gw = $in{"gw_$i"};
	$dev =~ /^\S+$/ || &error(&text('routes_edevice', $dev));
	&to_ipaddress($net) || &error(&text('routes_enet', $net));
	&check_ipaddress_any($netmask) ||
		&error(&text('routes_emask', $netmask));
	&to_ipaddress($gw) || &error(&text('routes_egateway', $gw));
	local $prefix = &mask_to_prefix($netmask);
	push(@{$st{$dev}}, [ "up", "ip route add $net/$prefix via $gw" ]);
	}
local %hr;
for($i=0; defined($dev = $in{"ldev_$i"}); $i++) {
	local $net = $in{"lnet_$i"};
	local $netmask = $in{"lnetmask_$i"};
	next if (!$dev && !$net);
	$dev =~ /^\S+$/ || &error(&text('routes_edevice', $dev));
	&to_ipaddress($net) ||
	    $net =~ /^(\S+)\/(\d+)$/ && &to_ipaddress("$1") ||
		&error(&text('routes_enet', $net));
	&check_ipaddress_any($netmask) ||
		&error(&text('routes_emask', $netmask));
	local $prefix = &mask_to_prefix($netmask);
	push(@{$hr{$dev}}, [ "up", "ip route add $net/$prefix dev $dev" ]);
	}

# Replace old routing directives
local @ifaces = &get_interface_defs();
foreach $iface (@ifaces) {
	local @o = @{$iface->[3]};
	@o = grep { $_->[0] ne "up" ||
		    $_->[1] !~ /^ip\s+route\s+add/ } @o;
	push(@o, @{$st{$iface->[0]}});
	push(@o, @{$hr{$iface->[0]}});
	$iface->[3] = \@o;
	&modify_interface_def($iface->[0], $iface->[1], $iface->[2],
			      $iface->[3], 0);
	}
}


###############################################################################
# helper functions for file-internal use

# gets a list of interface definitions (including their options) from the
# central config file
# the returned list is an array whose contents are tupels of
# (name, addrfam, method, options) with
#    name          the interface name (e.g. eth0)
#    addrfam       the address family (e.g. inet, inet6)
#    method        the address activation method (e.g. static, dhcp, loopback)
#    options       is a list of (param, value) pairs
sub get_interface_defs
{
local *CFGFILE;
my @ret;
&open_readfile(CFGFILE, $network_interfaces_config) ||
	error("Unable to open $network_interfaces_config");
# read the file line by line
$line = <CFGFILE>;
while (defined $line) {
	chomp($line);
	# skip comments
	if ($line =~ /^\s*#/ || $line =~ /^\s*$/) {
		$line = <CFGFILE>;
		next;
		}

	if ($line =~ /^\s*auto/) {
		# skip auto stanzas
		$line = <CFGFILE>;
		while(defined($line) && $line !~ /^\s*(iface|mapping|auto)/) {
			$line = <CFGFILE>;
			next;
			}
		}
	elsif ($line =~ /^\s*mapping/) {
		# skip mapping stanzas
		$line = <CFGFILE>;
		while(defined($line) && $line !~ /^\s*(iface|mapping|auto)/) {
			$line = <CFGFILE>;
			next;
			}
		}
	elsif (my ($name, $addrfam, $method) = ($line =~ /^\s*iface\s+(\S+)\s+(\S+)\s+(\S+)\s*$/) ) {
		# only lines starting with "iface" are expected here
		my @iface_options;
		# now read everything until the next iface definition
		$line = <CFGFILE>;
		while (defined $line && ! ($line =~ /^\s*(iface|mapping|auto)/)) {
			# skip comments and empty lines
			if ($line =~ /^\s*#/ || $line =~ /^\s*$/) {
				$line = <CFGFILE>;
				next;
				}
			my ($param, $value);
			if ( ($param, $value) = ($line =~ /^\s*(\S+)\s+(.*)\s*$/) ) {
				push(@iface_options, [$param, $value]);
				}
			elsif ( ($param) = ($line =~ /^\s*(\S+)\s*$/) ) {
				push(@iface_options, [$param, '']);
				}
			else {
				error("Error in option line: '$line' invalid");
				}
			$line = <CFGFILE>;
			}
		push(@ret, [$name, $addrfam, $method, \@iface_options]);
		}
	else {
		error("Error reading file $pathname: unexpected line '$line'");
		}
	}
close(CFGFILE);
return @ret;
}

# get_auto_defs()
# Returns a list of interfaces in auto lines
sub get_auto_defs
{
local @rv;
&open_readfile(CFGFILE, $network_interfaces_config);
while(<CFGFILE>) {
	s/\r|\n//g;
	s/^\s*#.*$//g;
	if (/^\s*auto\s*(.*)/) {
		push(@rv, split(/\s+/, $1));
		}
	}
close(CFGFILE);
return @rv;
}

# modify_auto_defs(iface, ...)
# Replaces all auto lines with one containing the interfaces given as params
sub modify_auto_defs
{
local $lref = &read_file_lines($network_interfaces_config);
local $i;
local $found;
for($i=0; $i<@$lref; $i++) {
	local $l = $lref->[$i];
	$l =~ s/\r|\n//g;
	$l =~ s/^\s*#.*$//g;
	if ($l =~ /^\s*auto\s*(.*)/) {
		if (!$found++) {
			# Replace the auto line
			$lref->[$i] = "auto ".join(" ", @_);
			}
		else {
			# Remove another auto line
			splice(@$lref, $i--, 1);
			}
		}
	}
if (!$found) {
	splice(@$lref, 0, 0, "auto ".join(" ", @_));
	}
&flush_file_lines();
}

# modifies the options of an already stored interface definition
# the parameters should be (name, addrfam, method, options, mode)
# with options being an array of (param, value) pairs
# and mode being 0 for modify and 1 for delete
sub modify_interface_def
{
my ($name, $addrfam, $method, $options, $mode) = @_;
# make a backup copy
copy("$network_interfaces_config", "$network_interfaces_config~");
local *OLDCFGFILE, *NEWCFGFILE;
&open_readfile(OLDCFGFILE, "$network_interfaces_config~") ||
	error("Unable to open $network_interfaces_config");
&lock_file($network_interfaces_config);
&open_tempfile(NEWCFGFILE, "> $network_interfaces_config", 1) ||
	error("Unable to open $network_interfaces_config");

my $inside_modify_region = 0;
my $iface_line = 0;
my $new_options_wrote;
while (defined ($line=<OLDCFGFILE>)) {
	if ($inside_modify_region == 0 &&
           $line =~ /^\s*iface\s+$name\s+$addrfam\s+\S+\s*$/) {
	   	# Start of the iface section to modify
		$inside_modify_region = 1;
		$iface_line = 1;
		$new_options_wrote = 0;
		}
	elsif ($inside_modify_region == 1 &&
               ($line =~ /^\s*iface\s+\S+\s+\S+\s+\S+\s*$/ ||
	        $line =~ /^\s*mapping/ ||
		$line =~ /^\s*auto/)) {
	      	# End of an iface section
		$inside_modify_region = 0;
		}
	# preserve comments and blank lnks
	if ($line =~ /^\s*#/ || $line =~ /^\s*$/) {
		&print_tempfile(NEWCFGFILE, $line);
		}
	# inside modify region or not ?
	elsif ($inside_modify_region == 0) {
               &print_tempfile(NEWCFGFILE, $line);
		}
	else {
		# should the iface line be changed or the options ?
		if ($iface_line == 1 && $mode == 0) {
			&print_tempfile(NEWCFGFILE, "iface $name $addrfam $method\n");
			}
               # only write the new options and skip the old ones or just do
               # nothing if mode is delete
               # write only upon first entrance here
               if ($mode == 0 && $new_options_wrote == 0) {
                       $new_options_wrote = 1;
                       foreach $option (@$options) {
                               my ($param, $value) = @$option;
                               &print_tempfile(NEWCFGFILE, "\t$param $value\n");
				}
			}
		}
	$iface_line = 0;
	}

close(OLDCFGFILE);
&close_tempfile(NEWCFGFILE);
&unlock_file($network_interfaces_config);
}

# creates a new interface definition in the config file
# the parameters should be (name, addrfam, method, options)
# with options being an array of (param, value) pairs
# the selection key is (name, addrfam)
sub new_interface_def
{
# make a backup copy
copy("$network_interfaces_config", "$network_interfaces_config~");
local *CFGFILE;
&open_lock_tempfile(CFGFILE, ">> $network_interfaces_config") ||
	error("Unable to open $network_interfaces_config");
local ($name, $addrfam, $method, $options) = @_;
&print_tempfile(CFGFILE, "\niface $name $addrfam $method\n");
foreach $option (@$options) {
	my ($param, $value) = @$option;
	&print_tempfile(CFGFILE, "\t$param $value\n");
	}
&close_tempfile(CFGFILE);
}

# delete an already defined interface
# the parameters should be (name, addrfam)
sub delete_interface_def
{
	local ($name, $addrfam, $method) = @_;
	modify_interface_def($name, $addrfam, '', [], 1);
	modify_module_def($name, 1);
}

sub os_feedback_files
{
return ( $network_interfaces_config, "/etc/nsswitch.conf", "/etc/resolv.conf",
	 "/etc/HOSTNAME" );
}

# apply_network()
# Apply the interface and routing settings
sub apply_network
{
&system_logged("(cd / ; /etc/init.d/networking stop ; /etc/init.d/networking start) >/dev/null 2>&1");
}

# get_default_gateway()
# Returns the default gateway IP (if one is set) and device (if set) boot time
# settings.
sub get_default_gateway
{
local @ifaces = &get_interface_defs();
local ($router, $addr);
foreach $iface (@ifaces) {
	foreach $o (@{$iface->[3]}) {
		if ($o->[0] eq 'gateway') {
			return ( $o->[1], $iface->[0] );
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
local @ifaces = &get_interface_defs();
local $iface;
foreach $iface (@ifaces) {
	# Remove the gateway directive
	$iface->[3] = [ grep { $_->[0] ne 'gateway' } @{$iface->[3]} ];

	# Add if needed
	if ($iface->[0] eq $_[1]) {
		push(@{$iface->[3]}, [ 'gateway', $_[0] ]);
		}
	&modify_interface_def(@$iface);
	}
}

# get_teaming_partner(devicename, line)
# Gets the teamingpartner of a configuration line
# Example configuration line: "/sbin/ifenslave bond0 eth0 eth1"
sub get_teaming_partner
{
	my($deviceName, $line) = @_;
	@params = split(/ /, $line);
	my $return;
		
	
	for($i = scalar(@params); $i > 0; $i--){
		if($deviceName eq $params[$i]){
			break;
		} else {
			$return = $params[$i] . " " . $return;
		}
	}
	chop $return;
	return $return;
}

sub supports_bonding
{
return $gconfig{'os_type'} eq 'debian-linux' && &has_command("ifenslave");
}

sub supports_vlans
{
return $gconfig{'os_type'} eq 'debian-linux' && &has_command("vconfig");
}

sub boot_iface_hardware
{
return $_[0] =~ /^eth/;
}

# supports_address6([&iface])
# Returns 1 if managing IPv6 interfaces is supported
sub supports_address6
{
local ($iface) = @_;
return !$iface || $iface->{'virtual'} eq '';
}

1;

