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
$sysctl_config = "/etc/sysctl.conf";

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
		if ($cfg->{'fullname'} =~ /^br(\d+)$/) {
			$cfg->{'bridge'} = 1;
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
				$cfg->{'primary'} = $options{'primary'};
				}
			elsif($param =~ /^bond[_\-](mode|miimon|downdelay|updelay|primary)$/) {
				$cfg->{$1} = $value;
				}
			elsif($param eq 'slaves') { 
				$cfg->{'partner'} = $value;
				}
			elsif($param eq 'hwaddress' || $param eq 'hwaddr') {
				local @v = split(/\s+/, $value);
				$cfg->{'ether_type'} = $v[0];
				$cfg->{'ether'} = $v[1];
				}
			elsif ($param eq 'bridge_ports') {
				$cfg->{'bridgeto'} = $value;
				}
			elsif ($param eq 'bridge_stp') {
				$cfg->{'bridgestp'} = $value;
				}
			elsif ($param eq 'bridge_fd') {
				$cfg->{'bridgefd'} = $value;
				}
			elsif ($param eq 'bridge_waitport') {
				$cfg->{'bridgewait'} = $value;
				}
			elsif ($param eq 'pre-up' &&
			       $value =~ /brctl\s+addif\s+br\d+\s+(\S+)/) {
				$cfg->{'bridgeto'} = $1;
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
				$value =~ s/\s+dev\s+(\S+)//;
				if ($value =~ /^(\S+)\/(\d+)$/) {
					push(@{$v6cfg->{'address6'}}, $1);
					push(@{$v6cfg->{'netmask6'}}, $2);
					}
				else {
					push(@{$v6cfg->{'address6'}}, $value);
					}
				}
			elsif ($param eq "netmask") {
				push(@{$v6cfg->{'netmask6'}}, $value);
				}
			elsif ($param eq "gateway") {
				$v6cfg->{'gateway6'} = $value;
				}
			elsif ($param eq "up" &&
			       $value =~ /ifconfig\s+(\S+)\s+inet6\s+add\s+([a-f0-9:]+)\/(\d+)/ &&
				$1 eq $name) {
				# Additional v6 address with ifconfig command,
				# like :
				# ifconfig eth0 inet6 add 2607:f3:aaab:3::10/64
				push(@{$v6cfg->{'address6'}}, $2);
				push(@{$v6cfg->{'netmask6'}}, $3);
				}
			elsif ($param eq "up" &&
			       $value =~ /ip\s+addr\s+add\s+([a-f0-9:]+)\/(\d+)\s+dev\s+(\S+)/ &&
				$3 eq $name) {
				# Additional v6 address with ip command, like :
				# ip addr add 2607:f3:aaab:3::10/64 dev eth0
				push(@{$v6cfg->{'address6'}}, $1);
				push(@{$v6cfg->{'netmask6'}}, $2);
				}
			}
		if ($method eq "manual" && !@{$v6cfg->{'address6'}}) {
			$v6cfg->{'auto6'} = 1;
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
if ($cfg->{'dhcp'} == 1) {
	$method = 'dhcp';
	}
elsif ($cfg->{'bootp'} == 1) {
	$method = 'bootp';
	}
elsif ($cfg->{'address'}) {
	$method = 'static';
	push(@options, ['address', $cfg->{'address'}]);
	push(@options, ['netmask', $cfg->{'netmask'}]);
	push(@options, ['broadcast', $cfg->{'broadcast'}])
		if ($cfg->{'broadcast'});
	my ($ip1, $ip2, $ip3, $ip4) = split(/\./, $cfg->{'address'});
	my ($nm1, $nm2, $nm3, $nm4) = split(/\./, $cfg->{'netmask'});
	if ($cfg->{'address'} && $cfg->{'netmask'}) {
		my $network = sprintf "%d.%d.%d.%d",
					($ip1 & int($nm1))&0xff,
					($ip2 & int($nm2))&0xff,
					($ip3 & int($nm3))&0xff,
					($ip4 & int($nm4))&0xff;
		push(@options, ['network', $network]);
		}
	if ($cfg->{'mtu'}) {
		push(@options, ['mtu', $cfg->{'mtu'}]);
		}
	}
else {
	$method = 'manual';
	}
my @autos = get_auto_defs();
my $amode = $gconfig{'os_version'} > 3 || scalar(@autos);
if (!$cfg->{'up'} && !$amode) { push(@options, ['noauto', '']); }
if ($cfg->{'ether'}) {
	push(@options, [ 'hwaddress',
			 ($cfg->{'ether_type'} || 'ether').' '.
			 $cfg->{'ether'} ]);
	}
if ($cfg->{'bridge'}) {
	&has_command("brctl") || &error("Bridges cannot be created unless the ".
					"brctl command is installed");
	if ($cfg->{'bridgeto'}) {
		push(@options, [ 'bridge_ports', $cfg->{'bridgeto'} ]);
		}
	else {
		push(@options, [ 'pre-up', 'brctl addbr '.$name ]);
		}
	if ($cfg->{'bridgestp'}) {
		push(@options, [ 'bridge_stp', $cfg->{'bridgestp'} ]);
		}
	if ($cfg->{'bridgefd'}) {
		push(@options, [ 'bridge_fd', $cfg->{'bridgefd'} ]);
		}
	if ($cfg->{'bridgewait'}) {
		push(@options, [ 'bridge_waitport', $cfg->{'bridgewait'} ]);
		}
	}

# Set bonding parameters
if(($cfg->{'bond'} == 1) && ($gconfig{'os_version'} >= 5)) {
	push(@options, [&bonding_option('mode').' '.$cfg->{'mode'}]);
	push(@options, [&bonding_option('miimon').' '.$cfg->{'miimon'}]) if ($cfg->{'miimon'});
	push(@options, [&bonding_option('updelay').' '.$cfg->{'updelay'}]) if ($cfg->{'updelay'});
	push(@options, [&bonding_option('downdelay').' '.$cfg->{'downdelay'}]) if ($cfg->{'downdelay'});
	push(@options, [&bonding_option('primary').' '.$cfg->{'primary'}]) if ($cfg->{'primary'});
	push(@options, ['slaves '.$cfg->{'partner'}]);
	}
elsif ($cfg->{'bond'} == 1) {
	push(@options, ['up', '/sbin/ifenslave '.$cfg->{'name'}." ".
			      $cfg->{'partner'}]);
	push(@options, ['down', '/sbin/ifenslave -d '.$cfg->{'name'}." ".
			        $cfg->{'partner'}]);
	}

# Set specific lines for vlan tagging
if(($cfg->{'vlan'} == 1) && ($gconfig{'os_version'} < 5)) {
	push(@options, ['pre-up', 'vconfig add '.$cfg->{'physical'}.' '.
				  $cfg->{'vlanid'}]);
	push(@options, ['post-down', 'vconfig rem '.$cfg->{'physical'}.' '.
				     $cfg->{'vlanid'}]);
	}
if(($cfg->{'vlan'} == 1) && ($cfg->{'mtu'})) {
	push(@options, ['pre-up', '/sbin/ifconfig '.$cfg->{'physical'}.' mtu '.$cfg->{'mtu'}]);
	}

# Find the existing interface section
my @ifaces = get_interface_defs();
my $found = 0;
my $found6 = 0;
foreach $iface (@ifaces) {
	local $address;
	foreach my $opt (@{$iface->[3]}) {
		if($opt->[0] eq 'address'){
			$address = $opt->[1];
			last;
			}
		}
	if ($iface->[0] eq $cfg->{'fullname'} && $iface->[1] eq 'inet') {
		# Found interface to change
		$found = 1;
		foreach my $o (@{$iface->[3]}) {
			if ($o->[0] eq 'gateway' ||
			    $o->[0] eq 'pre-up' && $o->[1] =~ /brctl/ ||
			    $o->[0] =~ /^(pre-)?up$/ && $o->[1] =~ /ip\s+route/ ||
			    $o->[0] eq 'post-up' && $o->[1] =~ /iptables-restore/) {
				push(@options, $o);
				}
			}
		}
	if ($iface->[0] eq $cfg->{'fullname'} && $iface->[1] eq 'inet6') {
		# Found IPv6 block
		$found6 = 1;
		}
	}

# Remove any duplicate options
my %done;
@options = grep { !$done{$_->[0],$_->[1]}++ } @options;

if (!$found) {
	# Add a new interface section
	if ($in{'vlan'} == 1) {
		&new_interface_def($cfg->{'physical'}.'.'.$cfg->{'vlanid'},
				   'inet', $method, \@options);
		}
	else {
		&new_interface_def($cfg->{'fullname'},
				   'inet', $method, \@options);
		}
	if ($cfg->{'bond'} == 1 && $gconfig{'os_version'} < 5) {
		&new_module_def($cfg->{'fullname'}, $cfg->{'mode'},
			        $cfg->{'miimon'}, $cfg->{'downdelay'},
			        $cfg->{'updelay'});
		}
	} 
else {
	# Update existing section
	if($in{'vlan'} == 1) {
		&modify_interface_def($cfg->{'physical'}.'.'.$cfg->{'vlanid'},
				      'inet', $method, \@options, 0);
		}
	else {
		&modify_interface_def($cfg->{'fullname'},
				      'inet', $method, \@options, 0);
		}
	if ($cfg->{'bond'} == 1 && $gconfig{'os_version'} < 5) {
		&modify_module_def($cfg->{'fullname'}, 0, $cfg->{'mode'},
				   $cfg->{'miimon'}, $cfg->{'downdelay'},
				   $cfg->{'updelay'});
		}
	}

# Create IPv6 options
my @options6;
my @address6 = @{$cfg->{'address6'}};
my @netmask6 = @{$cfg->{'netmask6'}};
if (@address6 || $cfg->{'auto6'}) {
	push(@options6, ['pre-up', '/sbin/modprobe -q ipv6 ; /bin/true']);
	}
if (@address6) {
	push(@options6, [ "address", shift(@address6) ]);
	push(@options6, [ "netmask", shift(@netmask6) ]);
	}
while(@address6) {
	my $a = shift(@address6);
	my $n = shift(@netmask6);
	push(@options6, [ "up","ifconfig $cfg->{'fullname'} inet6 add $a/$n" ]);
	}
if ($cfg->{'gateway6'}) {
	push(@options6, [ "gateway", $cfg->{'gateway6'} ]);
	}

# Add, update or delete IPv6 inteface
my $method = $cfg->{'auto6'} ? "manual" : "static";
if (!$found6 && @options6) {
	# Need to add IPv6 block
	&new_interface_def($cfg->{'fullname'},
			   'inet6', $method, \@options6);
	}
elsif ($found6 && @options6) {
	# Need to update IPv6 block
	&modify_interface_def($cfg->{'fullname'},
			      'inet6', $method, \@options6, 0);
	}
elsif ($found6 && !@options6) {
	# Need to delete IPv6 block
	&delete_interface_def($cfg->{'fullname'}, 'inet6');
	}

# Set auto option to include this interface, or not
if ($amode) {
	if ($cfg->{'up'}) {
		if($in{'vlan'} == 1) {
			@autos = &unique(@autos, $cfg->{'physical'}.'.'.
				 		 $cfg->{'vlanid'});
			}
		else {
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
&delete_interface_def($cfg->{'fullname'}, 'inet');
if (@{$cfg->{'address6'}}) {
	&delete_interface_def($cfg->{'fullname'}, 'inet6');
	}
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
return $_[0];
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
return ( $network_interfaces_config, $sysctl_config );
}

sub network_config_files
{
return ( "/etc/hostname", "/etc/HOSTNAME", "/etc/mailname" );
}

# show default router and device
sub routing_input
{
local ($addr, $router) = &get_default_gateway();
local ($addr6, $router6) = &get_default_ipv6_gateway();
local @ifaces = grep { $_->[1] eq 'inet' && $_->[0] ne 'lo' }
		     &get_interface_defs();
local @ifaces6 = grep { $_->[1] eq 'inet6' && $_->[0] ne 'lo' }
		      &get_interface_defs();

# Show default gateway
print &ui_table_row($text{'routes_default'},
	&ui_radio("gateway_def", $addr ? 0 : 1,
		  [ [ 1, $text{'routes_none'} ],
		    [ 0, $text{'routes_gateway'}." ".
			 &ui_textbox("gateway", $addr, 15)." ".
			 &ui_select("gatewaydev", $router,
				[ map { $_->[0] } @ifaces ]) ] ]));

if (@ifaces6) {
	# Show default IPv6 gateway
	print &ui_table_row($text{'routes_default6'},
		&ui_radio("gateway6_def", $addr6 ? 0 : 1,
			  [ [ 1, $text{'routes_none'} ],
			    [ 0, $text{'routes_gateway'}." ".
				 &ui_textbox("gateway6", $addr6, 30)." ".
				 &ui_select("gatewaydev6", $router6,
					[ map { $_->[0] } @ifaces6 ]) ] ]));
	}

# Act as router?
local %sysctl;
&read_env_file($sysctl_config, \%sysctl);
print &ui_table_row($text{'routes_forward'},
	&ui_yesno_radio("forward",
			$sysctl{'net.ipv4.ip_forward'} ? 1 : 0));

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
# Save IPv4 address
local ($dev, $gw);
if (!$in{'gateway_def'}) {
	&check_ipaddress($in{'gateway'}) ||
		&error(&text('routes_egateway', $in{'gateway'}));
	$gw = $in{'gateway'};
	$dev = $in{'gatewaydev'};
	}
&set_default_gateway($gw, $dev);

# Save IPv6 address
local @ifaces6 = grep { $_->[1] eq 'inet6' && $_->[0] ne 'lo' }
		      &get_interface_defs();
if (@ifaces6) {
	local ($dev6, $gw6);
	if (!$in{'gateway6_def'}) {
		&check_ip6address($in{'gateway6'}) ||
			&error(&text('routes_egateway6', $in{'gateway6'}));
		$gw6 = $in{'gateway6'};
		$dev6 = $in{'gatewaydev6'};
		}
	&set_default_ipv6_gateway($gw6, $dev6);
	}

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

# Save routing flag
local %sysctl;
&lock_file($sysctl_config);
&read_env_file($sysctl_config, \%sysctl);
$sysctl{'net.ipv4.ip_forward'} = $in{'forward'};
&write_env_file($sysctl_config, \%sysctl);
&unlock_file($sysctl_config);
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
		while(defined($line) && $line !~ /^\s*(iface|mapping|auto|source|allow-hotplug)/) {
			$line = <CFGFILE>;
			next;
			}
		}
	elsif ($line =~ /^\s*mapping/) {
		# skip mapping stanzas
		$line = <CFGFILE>;
		while(defined($line) && $line !~ /^\s*(iface|mapping|auto|source|allow-hotplug)/) {
			$line = <CFGFILE>;
			next;
			}
		}
	elsif ($line =~ /^\s*source/) {
		# Skip includes
		$line = <CFGFILE>;
		}
	elsif ($line =~ /^\s*allow-hotplug/) {
		# Skip hotplug lines
		$line = <CFGFILE>;
		}
	elsif (my ($name, $addrfam, $method) = ($line =~ /^\s*iface\s+(\S+)\s+(\S+)\s+(\S+)\s*$/) ) {
		# only lines starting with "iface" are expected here
		my @iface_options;
		# now read everything until the next iface definition
		$line = <CFGFILE>;
		while (defined $line && ! ($line =~ /^\s*(iface|mapping|auto|source|allow-hotplug)/)) {
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
local @ifaces = sort { length($a) <=> length($b) } @_;
for($i=0; $i<@$lref; $i++) {
	local $l = $lref->[$i];
	$l =~ s/\r|\n//g;
	$l =~ s/^\s*#.*$//g;
	if ($l =~ /^\s*auto\s*(.*)/) {
		if (!$found++) {
			# Replace the auto line
			$lref->[$i] = "auto ".join(" ", @ifaces);
			}
		else {
			# Remove another auto line
			splice(@$lref, $i--, 1);
			}
		}
	}
if (!$found) {
	splice(@$lref, 0, 0, "auto ".join(" ", @ifaces));
	}
&flush_file_lines($network_interfaces_config);
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
	        $line =~ /^\s*source/ ||
	        $line =~ /^\s*allow-hotplug/ ||
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
&modify_interface_def($name, $addrfam, '', [], 1);
&modify_module_def($name, 1);
}

# apply_network()
# Apply the interface and routing settings
sub apply_network
{
&system_logged("(cd / ; /etc/init.d/networking restart) >/dev/null 2>&1");
}

# get_default_gateway()
# Returns the default gateway IP (if one is set) and device (if set) boot time
# settings.
sub get_default_gateway
{
local @ifaces = &get_interface_defs();
local ($router, $addr);
foreach $iface (grep { $_->[1] eq 'inet' } @ifaces) {
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
foreach my $iface (grep { $_->[1] eq 'inet' } @ifaces) {
	# Remove the gateway directive
	$iface->[3] = [ grep { $_->[0] ne 'gateway' } @{$iface->[3]} ];

	# Add if needed
	if ($iface->[0] eq $_[1]) {
		push(@{$iface->[3]}, [ 'gateway', $_[0] ]);
		}
	&modify_interface_def(@$iface);
	}
}

# get_default_ipv6_gateway()
# Returns the default gateway IPv6 address (if one is set) and device (if set)
# boot time settings.
sub get_default_ipv6_gateway
{
local @ifaces = &get_interface_defs();
local ($router, $addr);
foreach $iface (grep { $_->[1] eq 'inet6' } @ifaces) {
	foreach $o (@{$iface->[3]}) {
		if ($o->[0] eq 'gateway') {
			return ( $o->[1], $iface->[0] );
			}
		}
	}
return ( );
}

# set_default_ipv6_gateway([gateway, device])
# Sets the default IPv6 gateway to the given IP accessible via the given device,
# in the boot time settings.
sub set_default_ipv6_gateway
{
local @ifaces = &get_interface_defs();
foreach my $iface (grep { $_->[1] eq 'inet6' } @ifaces) {
	# Remove the gateway directive
	$iface->[3] = [ grep { $_->[0] ne 'gateway' } @{$iface->[3]} ];

	# Add if needed
	if ($iface->[0] eq $_[1] && $_[0]) {
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
return 1;
}

# bonding_option(suffix)
# Adds bond_ or bond- as appropriate
sub bonding_option
{
my ($sfx) = @_;
return ($gconfig{'os_version'} >= 7 ? "bond-" : "bond_").$sfx;
}

# os_save_dns_config(&config)
# On Debian, DNS resolves can also be stored in the interfaces file. Returns
# a flag indicating if a network restart is needed, and a flag indicating if
# /etc/resolv.conf is updated automatically.
sub os_save_dns_config
{
local ($conf) = @_;
local @ifaces = &get_interface_defs();
local @dnssearch;
local $need_apply = 0;
local $generated_resolv = -l "/etc/resolv.conf" ? 1 : 0;
if (@{$conf->{'domain'}} > 1) {
	@dnssearch = ( [ 'dns-domain', join(" ", @{$conf->{'domain'}}) ] );
	}
elsif (@{$conf->{'domain'}}) {
	@dnssearch = ( [ 'dns-domain', $conf->{'domain'}->[0] ] );
	}
foreach my $i (@ifaces) {
	local ($ns) = grep { $_->[0] eq 'dns-nameservers' } @{$i->[3]};
	if ($ns) {
		if (@{$conf->{'nameserver'}}) {
			$ns->[1] = join(' ', @{$conf->{'nameserver'}});
			}
		else {
			$i->[3] = [ grep { $_->[0] ne 'nameservers' }
					 @{$i->[3]} ];
			}
		$i->[3] = [ grep { $_->[0] ne 'dns-domain' &&
				   $_->[0] ne 'dns-search' }
				 @{$i->[3]} ];
		push(@{$i->[3]}, @dnssearch);
		&modify_interface_def($i->[0], $i->[1], $i->[2],
				      $i->[3], 0);
		$need_apply = 1;
		}
	}
if (!$need_apply && $generated_resolv) {
	# Nameservers have to be defined in the interfaces file, but
	# no interfaces have them yet. Find the first non-local
	# interface with an IP, and add them there
	foreach my $i (@ifaces) {
		next if ($i->[0] =~ /^lo/);
		local ($a) = grep { $_->[0] eq 'address' &&
			    &check_ipaddress($_->[1]) } @{$i->[3]};
		next if (!$a);
		if (@{$conf->{'nameserver'}}) {
			push(@{$i->[3]}, [ 'dns-nameservers',
				   join(' ', @{$conf->{'nameserver'}}) ]);
			}
		push(@{$i->[3]}, @dnssearch);
		&modify_interface_def($i->[0], $i->[1], $i->[2],
				      $i->[3], 0);
		$need_apply = 1;
		last;
		}
	}
return ($need_apply, $generated_resolv);
}

1;

