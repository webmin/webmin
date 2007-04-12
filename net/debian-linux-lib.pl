# debian-linux-lib.pl
# Networking functions for Debian linux >= 2.2 (aka. potato)
# Really, this won't work with releases prior to 2.2, don't even try it.
#
# Rene Mayrhofer, July 2000
# Some code has been taken from redhat-linux-lib.pl

use File::Copy;

$network_interfaces_config = '/etc/network/interfaces';

do 'linux-lib.pl';

# boot_interfaces()
# Returns a list of interfaces brought up at boot time
sub boot_interfaces
{
my @ifaces = &get_interface_defs();
my @autos = &get_auto_defs();
my @rv;
foreach $iface (@ifaces) {
	my ($name, $addrfam, $method, $options) = @$iface;
	my $cfg;
	if ($addrfam eq 'inet') {
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
			($param, $value) = @$option;
			if ($param eq 'noauto') { $cfg->{'up'} = 0; }
			else { $cfg->{$param} = $value; }
			}
		$cfg->{'dhcp'} = ($method eq 'dhcp');
		$cfg->{'bootp'} = ($method eq 'bootp');
		$cfg->{'edit'} = ($cfg->{'name'} !~ /^ppp|lo/);
		$cfg->{'index'} = scalar(@rv);	
		$cfg->{'file'} = $network_interfaces_config;
		push(@rv, $cfg);
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
if ($cfg->{'dhcp'} == 1) { $method = 'dhcp'; }
elsif ($cfg->{'bootp'} == 1) { $method = 'bootp'; }
else {
	$method = 'static';
	push(@options, ['address', $cfg->{'address'}]);
	push(@options, ['netmask', $cfg->{'netmask'}]);
	push(@options, ['broadcast', $cfg->{'broadcast'}]);
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
	}
my @autos = get_auto_defs();
my $amode = $gconfig{'os_version'} > 3 || scalar(@autos);
if (!$cfg->{'up'} && !$amode) { push(@options, ['noauto', '']); }

my @ifaces = get_interface_defs();
my $changeit = 0;
foreach $iface (@ifaces) {
	if ($iface->[0] eq $cfg->{'fullname'}) {
		$changeit = 1;
		foreach $o (@{$iface->[3]}) {
			if ($o->[0] eq 'gateway') {
				push(@options, $o);
				}
			}
		}
	}
if ($changeit == 0) {
	new_interface_def($cfg->{'fullname'}, 'inet', $method, \@options);
	}
else {
	modify_interface_def($cfg->{'fullname'}, 'inet', $method, \@options, 0);
	}
if ($amode) {
	if ($cfg->{'up'}) {
		@autos = &unique(@autos, $cfg->{'fullname'});
		}
	else {
		@autos = grep { $_ ne $cfg->{'fullname'} } @autos;
		}
	&modify_auto_defs(@autos);
	}
}

# delete_interface(&details)
# Delete a boot-time interface
sub delete_interface
{
my $cfg = $_[0];
delete_interface_def($cfg->{'fullname'}, 'inet');
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
return &check_ipaddress($_[0]);
}

# get_hostname()
sub get_hostname
{
return &get_system_hostname(1);
}

# save_hostname(name)
sub save_hostname
{
local (%conf, $f);
&system_logged("hostname $_[0] >/dev/null 2>&1");
foreach $f ("/etc/hostname", "/etc/HOSTNAME") {
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

# show default router and device
sub routing_input
{
local ($addr, $router) = &get_default_gateway();
local @ifaces = &get_interface_defs();

# Show default gateway
print "<tr> <td><b>$text{'routes_default'}</b></td>\n";
printf "<td><input type=radio name=gateway_def value=1 %s> %s\n",
	$addr ? '' : 'checked', $text{'routes_none'};
printf "<input type=radio name=gateway_def value=0 %s> %s\n",
	$addr ? 'checked' : '', $text{'routes_gateway'};
printf "<input name=gateway size=15 value='%s'>\n", $addr;
print "$text{'routes_device'}\n";
print "<select name=gatewaydev>\n";
foreach $iface (@ifaces) {
	next if ($iface->[0] eq 'lo');
	printf "<option %s>%s\n",
		$router eq $iface->[0] ? 'selected' : '', $iface->[0];
	}
print "</select></td> </tr>\n";

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
print "<tr> <td valign=top><b>$text{'routes_static'}</b></td>\n";
print "<td><table border>\n";
print "<tr $tb> <td><b>$text{'routes_ifc'}</b></td> ",
      "<td><b>$text{'routes_net'}</b></td> ",
      "<td><b>$text{'routes_mask'}</b></td> ",
      "<td><b>$text{'routes_gateway'}</b></td> </tr>\n";
local $i;
for($i=0; $i<=@st; $i++) {
	local $st = $st[$i];
	print "<tr $cb>\n";
	print "<td><input name=dev_$i size=6 value='$st->[0]'></td>\n";
	print "<td><input name=net_$i size=15 value='$st->[1]'></td>\n";
	print "<td><input name=netmask_$i size=15 value='$st->[2]'></td>\n";
	print "<td><input name=gw_$i size=15 value='$st->[3]'></td>\n";
	print "</tr>\n";
	}
print "</table></td> </tr>\n";

# Show static host routes
print "<tr> <td valign=top><b>$text{'routes_local'}</b></td>\n";
print "<td><table border>\n";
print "<tr $tb> <td><b>$text{'routes_ifc'}</b></td> ",
      "<td><b>$text{'routes_net'}</b></td> ",
      "<td><b>$text{'routes_mask'}</b></td> </tr>\n";
for($i=0; $i<=@hr; $i++) {
	local $st = $hr[$i];
	print "<tr $cb>\n";
	print "<td><input name=ldev_$i size=6 value='$st->[0]'></td>\n";
	print "<td><input name=lnet_$i size=15 value='$st->[1]'></td>\n";
	print "<td><input name=lnetmask_$i size=15 value='$st->[2]'></td>\n";
	print "</tr>\n";
	}
print "</table></td> </tr>\n";
}

sub parse_routing
{
local ($dev, $gw);
if (!$in{'gateway_def'}) {
	&check_ipaddress($in{'gateway'}) ||
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
	gethostbyname($net) || &error(&text('routes_enet', $net));
	&check_ipaddress($netmask) || &error(&text('routes_emask', $netmask));
	gethostbyname($gw) || &error(&text('routes_egateway', $gw));
	local $prefix = &mask_to_prefix($netmask);
	push(@{$st{$dev}}, [ "up", "ip route add $net/$prefix via $gw" ]);
	}
local %hr;
for($i=0; defined($dev = $in{"ldev_$i"}); $i++) {
	local $net = $in{"lnet_$i"};
	local $netmask = $in{"lnetmask_$i"};
	next if (!$dev && !$net);
	$dev =~ /^\S+$/ || &error(&text('routes_edevice', $dev));
	gethostbyname($net) || $net =~ /^(\S+)\/(\d+)$/ && gethostbyname($1) ||
		&error(&text('routes_enet', $net));
	&check_ipaddress($netmask) || &error(&text('routes_emask', $netmask));
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

1;

