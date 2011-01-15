# Networking functions for Gentoo 2006+

do 'linux-lib.pl';

$gentoo_net_config = "/etc/conf.d/net";
$min_virtual_number = 1;

# parse_gentoo_net()
# Parses the Gentoo net config file into an array of named sections
sub parse_gentoo_net
{
local @rv;
local $sect;
local $lnum = 0;
open(CONF, $gentoo_net_config);
while(<CONF>) {
	s/\r|\n//g;
	s/#.*$//;
	if (/^\s*(\S+)\s*=\s*\((.*)/) {
		# Start of some section, which may span several lines
		$sect = { 'name' => $1,
			  'line' => $lnum };
		push(@rv, $sect);
		local $v = $2;
		if ($v =~ /^(.*)\)/) {
			# Ends on same line
			$sect->{'values'} = [ &split_gentoo_values("$1") ];
			$sect->{'eline'} = $lnum;
			$sect = undef;
			}
		else {
			# May span multiple
			$sect->{'values'} = [ &split_gentoo_values($v) ];
			}
		}
	elsif (/^\s*\)/ && $sect) {
		# End of a section
		$sect->{'eline'} = $lnum;
		$sect = undef;
		}
	elsif (/^\s*(".*")\s*\)/ && $sect) {
		# End of a section, but with some values before it
		push(@{$sect->{'values'}}, &split_gentoo_values("$1"));
		$sect->{'eline'} = $lnum;
		$sect = undef;
		}
	elsif (/^\s*(".*")/ && $sect) {
		# Values within a section
		push(@{$sect->{'values'}}, &split_gentoo_values("$1"));
		}
	$lnum++;
	}
close(CONF);
return @rv;
}

# save_gentoo_net(&old, &new)
# Update or create a Gentoo net config file section
sub save_gentoo_net
{
local ($old, $new) = @_;
local @lines;
if ($new) {
	push(@lines, $new->{'name'}."=(");
	foreach my $v (@{$new->{'values'}}) {
		push(@lines,"  \"$v\"");
		}
	push(@lines, ")");
	}
local $lref = &read_file_lines($gentoo_net_config);
if ($old && $new) {
	# Replace section
	splice(@$lref, $old->{'line'}, $old->{'eline'}-$old->{'line'}+1,
	       @lines);
	$new->{'eline'} = $new->{'line'}+scalar(@lines)-1;
	}
elsif ($old && !$new) {
	# Delete section
	splice(@$lref, $old->{'line'}, $old->{'eline'}-$old->{'line'}+1);
	}
elsif (!$old && $new) {
	# Add section
	$new->{'line'} = scalar(@$lref);
	$new->{'eline'} = $new->{'line'}+scalar(@lines)-1;
	push(@$lref, @lines);
	}
&flush_file_lines($gentoo_net_config);
}

# split_gentoo_values(string)
# Splits a string like "foo bar" "smeg spod" into an array
sub split_gentoo_values
{
local ($str) = @_;
local @rv;
while($str =~ /^\s*"([^"]+)",?(.*)/) {
	push(@rv, $1);
	$str = $2;
	}
return @rv;
}

# boot_interfaces()
# Returns a list of interfaces brought up at boot time
sub boot_interfaces
{
local @rv;
foreach my $g (&parse_gentoo_net()) {
	if ($g->{'name'} =~ /^config_(\S+)/) {
		local $gn = $1;
		local $n = 0;
		foreach my $v (@{$g->{'values'}}) {
			# An interface definition
			local $iface = { 'name' => $gn,
					 'up' => 1,
					 'edit' => 1,
					 'index' => scalar(@rv) };
			if ($n == 0) {
				$iface->{'fullname'} = $gn;
				}
			else {
				$iface->{'fullname'} = $gn.":".$n;
				$iface->{'virtual'} = $n;
				}
			local @w = split(/\s+/, $v);
			if ($w[0] eq "dhcp") {
				$iface->{'dhcp'} = 1;
				}
			elsif ($w[0] eq "noop") {
				# Skipped, but still uses a up a number
				$n++;
				next;
				}
			if (&check_ipaddress($w[0])) {
				$iface->{'address'} = $w[0];
				}
			elsif ($w[0] =~ /^([0-9\.]+)\/(\d+)$/) {
				$iface->{'address'} = $1;
				$iface->{'netmask'} = &prefix_to_mask($2);
				}
			for($i=1; $i<@w; $i++) {
				if ($w[$i] eq "netmask") {
					$iface->{'netmask'} = $w[++$i];
					}
				elsif ($w[$i] eq "broadcast") {
					$iface->{'broadcast'} = $w[++$i];
					}
				elsif ($w[$i] eq "mtu") {
					$iface->{'mtu'} = $w[++$i];
					}
				}
			if ($iface->{'address'} && $iface->{'netmask'}) {
				$iface->{'broadcast'} ||= &compute_broadcast(
				    $iface->{'address'}, $iface->{'netmask'}); 
				}
			$iface->{'gentoo'} = $g;
			push(@rv, $iface);
			$n++;
			}
		}
	elsif ($g->{'name'} =~ /^routes_(\S+)/) {
		# A route definition for an interface
		local ($iface) = grep { $_->{'fullname'} eq $1 } @rv;
		local $spec = $g->{'values'}->[0];
		if ($iface) {
			if ($spec =~ /default\s+via\s+([0-9\.]+)/ ||
			    $spec =~ /default\s+([0-9\.]+)/) {
				$iface->{'gateway'} = $1;
				$iface->{'gentoogw'} = $g;
				}
			}
		}
	$lnum++;
	}
return @rv;
}

# save_interface(&details)
# Create or update a boot-time interface
sub save_interface
{
local ($iface) = @_;
&lock_file($gentoo_net_config);

# Build the interface line
local @w;
if ($iface->{'dhcp'}) {
	push(@w, "dhcp");
	}
else {
	push(@w, $iface->{'address'});
	if ($iface->{'netmask'}) {
		push(@w, "netmask", $iface->{'netmask'});
		}
	if ($iface->{'broadcast'}) {
		push(@w, "broadcast", $iface->{'broadcast'});
		}
	if ($iface->{'mtu'}) {
		push(@w, "mtu", $iface->{'mtu'});
		}
	}

# Find the current block for this interface
local @gentoo = &parse_gentoo_net();
local ($g) = grep { $_->{'name'} eq 'config_'.$iface->{'name'} } @gentoo;
if ($g) {
	# Found it .. append or replace
	while (!$g->{'values'}->[$iface->{'virtual'}]) {
		push(@{$g->{'values'}}, "noop");
		}
	$g->{'values'}->[$iface->{'virtual'}] = join(" ", @w);
	&save_gentoo_net($g, $g);
	}
else {
	# Needs a new block
	$g = { 'name' => $iface->{'name'},
	       'values' => [ join(" ", @w) ] };
	&save_gentoo_net(undef, $g);
	}
&unlock_file($gentoo_net_config);
}

# delete_interface(&details)
# Delete a boot-time interface
sub delete_interface
{
local ($iface) = @_;

# Find the current block for this interface
&lock_file($gentoo_net_config);
local @gentoo = &parse_gentoo_net();
local ($g) = grep { $_->{'name'} eq 'config_'.$iface->{'name'} } @gentoo;
if ($g) {
	# Found it .. take out the interface
	if ($iface->{'virtual'} == scalar(@{$g->{'values'}})-1) {
		# Last one
		pop(@{$g->{'values'}});
		}
	else {
		$g->{'values'}->[$iface->{'virtual'}] = 'noop';
		}
	&save_gentoo_net($g, $g);
	}
&unlock_file($gentoo_net_config);
}

# can_edit(what)
# Can some boot-time interface parameter be edited?
sub can_edit
{
return $_[0] ne 'up' && $_[0] ne 'bootp';
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
local %host;
&read_env_file("/etc/conf.d/hostname", \%host);
if ($host{'HOSTNAME'}) {
	return $host{'HOSTNAME'};
	}
return &get_system_hostname(1);
}

# save_hostname(name)
sub save_hostname
{
local %host;
&read_env_file("/etc/conf.d/hostname", \%host);
$host{'HOSTNAME'} = $_[0];
&write_env_file("/etc/conf.d/hostname", \%host);
&system_logged("hostname $_[0] >/dev/null 2>&1");
}

# routing_input()
# Prints HTML for editing routing settings
sub routing_input
{
local ($gw, $dev) = &get_default_gateway();
local @ifaces = grep { $_->{'virtual'} eq '' } &boot_interfaces();
print &ui_table_row($text{'routes_def'},
      &ui_radio("route_def", $gw ? 0 : 1,
		[ [ 1, $text{'routes_nogw'}."<br>" ],
		  [ 0, &text('routes_ggw',
			  &ui_textbox("gw", $gw, 20),
			  &ui_select("dev", $dev,
			    [ map { $_->{'name'} } @ifaces ])) ] ]));
}

# parse_routing()
# Applies settings from routing_input form
sub parse_routing
{
if ($in{'route_def'}) {
	&set_default_gateway();
	}
else {
	&check_ipaddress($in{'gw'}) ||
		&error(&text('routes_edefault', $in{'gw'}));
	&set_default_gateway($in{'gw'}, $in{'dev'});
	}
}

# apply_network()
# Apply the interface and routing settings
sub apply_network
{
opendir(DIR, "/etc/init.d");
foreach my $f (readdir(DIR)) {
	if ($f =~ /^net.(\S+)/ && $1 ne "lo") {
		&system_logged("cd / ; /etc/init.d/$f restart >/dev/null 2>&1 </dev/null");
		}
	}
closedir(DIR);
}

# get_default_gateway()
# Returns the default gateway IP (if one is set) and device (if set) boot time
# settings.
sub get_default_gateway
{
local @ifaces = &boot_interfaces();
local ($iface) = grep { $_->{'gateway'} } @ifaces;
if ($iface) {
	return ( $iface->{'gateway'}, $iface->{'name'} );
	}
else {
	return ( );
	}
}

# set_default_gateway(gateway, device)
# Sets the default gateway to the given IP accessible via the given device,
# in the boot time settings.
sub set_default_gateway
{
local ($gw, $dev) = @_;
&lock_file($gentoo_net_config);
local @ifaces = &boot_interfaces();
local ($iface) = grep { $_->{'gateway'} } @ifaces;
if ($iface && $gw) {
	# Change existing default route
	$g = $iface->{'gentoogw'};
	$g->{'name'} = 'routes_'.$dev;
	$g->{'values'}->[0] = "default via $gw";
	&save_gentoo_net($g, $g);
	}
elsif ($iface && !$gw) {
	# Deleting existing default route
	$g = $iface->{'gentoogw'};
	&save_gentoo_net($g, undef);
	}
elsif (!$iface && $gw) {
	# Adding new default route
	$g = { 'name' => 'routes_'.$dev,
	       'values' => [ "default via $gw" ] };
	&save_gentoo_net(undef, $g);
	}
&unlock_file($gentoo_net_config);
}

# supports_address6([&iface])
# Returns 1 if managing IPv6 interfaces is supported
sub supports_address6
{
local ($iface) = @_;
return 0;
}


