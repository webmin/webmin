# Networking functions for Ubuntu 17+, which uses Netplan by default

$netplan_dir = "/etc/netplan";

do 'linux-lib.pl';

sub boot_interfaces
{
my @rv;
foreach my $f (glob("$netplan_dir/*.yaml")) {
	my $yaml = &read_yaml_file($f);
	next if (!$yaml || !@$yaml);
	my ($network) = grep { $_->{'name'} eq 'network' } @$yaml;
	next if (!$network);
	my ($ens) = grep { $_->{'name'} eq 'ethernets' }
			 @{$network->{'members'}};
	next if (!$ens);
	foreach my $e (@{$ens->{'members'}}) {
		my $cfg = { 'name' => $e->{'name'},
			    'fullname' => $e->{'name'},
			    'file' => $f,
			    'line' => $e->{'line'},
			    'eline' => $e->{'eline'},
			    'up' => 1 };
		my ($dhcp) = grep { $_->{'name'} eq 'dhcp4' }
				  @{$e->{'members'}};
		if (&is_true_value($dhcp)) {
			$cfg->{'dhcp'} = 1;
			}

		# IPv4 and v6 addresses
		my ($addresses) = grep { $_->{'name'} eq 'addresses' }
				       @{$e->{'members'}};
		my @addrs;
		my @addrs6;
		if ($addresses) {
			@addrs = grep { !&check_ip6address($_) }
				      @{$addresses->{'value'}};
			@addrs6 = grep { &check_ip6address($_) }
				       @{$addresses->{'value'}};
			my $a = shift(@addrs);
			($cfg->{'address'}, $cfg->{'netmask'}) =
				&split_addr_netmask($a);
			}
		foreach my $a6 (@addrs6) {
			if ($a6 =~ /^(\S+)\/(\d+)$/) {
				push(@{$cfg->{'address6'}}, $1);
				push(@{$cfg->{'netmask6'}}, $2);
				}
			else {
				push(@{$cfg->{'address6'}}, $a6);
				push(@{$cfg->{'netmask6'}}, 64);
				}
			}

		# IPv4 and v4 gateways
		my ($gateway4) = grep { $_->{'name'} eq 'gateway4' }
				      @{$e->{'members'}};
		if ($gateway4) {
			$cfg->{'gateway'} = $gateway4->{'value'};
			}
		my ($gateway6) = grep { $_->{'name'} eq 'gateway6' }
				      @{$e->{'members'}};
		if ($gateway6) {
			$cfg->{'gateway6'} = $gateway6->{'value'};
			}
		push(@rv, $cfg);

		# Nameservers (which are used to generate resolv.conf)
		my ($nameservers) = grep { $_->{'name'} eq 'nameservers' }
                                         @{$e->{'members'}};
		if ($nameservers) {
			my ($nsa) = grep { $_->{'name'} eq 'addresses' }
					 @{$nameservers->{'members'}};
			my ($search) = grep { $_->{'name'} eq 'search' }
					 @{$nameservers->{'members'}};
			if ($nsa) {
				$cfg->{'nameserver'} = $nsa->{'value'};
				}
			if ($search) {
				$cfg->{'search'} = $search->{'value'};
				}
			}

		# Add IPv4 alias interfaces
		foreach my $aa (@addrs) {
			# XXX
			}
		}
	}
return @rv;
}

# save_interface(&details)
# Create or update a boot-time interface
sub save_interface
{
my ($iface) = @_;
if ($iface->{'alias'}) {
	# XXX alias interface
	}
else {
	# Build interface config lines
	my $id = " " x 8;
	my @lines;
	push(@lines, $id.$iface->{'fullname'});
	my @addrs;
	if ($iface->{'dhcp'}) {
		push(@lines, $id."    "."dhp4: true");
		}
	else {
		push(@addrs, $iface->{'address'}."/".
			     &mask_to_prefix($iface->{'netmask'}));
		}
	for(my $i=0; $i<@{$iface->{'address6'}}; $i++) {
		push(@addrs, $iface->{'address6'}->[$i]."/".
			     $iface->{'netmask6'}->[$i]);
		}
	if (@addrs) {
		push(@lines, $id."    "."addresses: [".join(",", @addrs)."]");
		}
	if ($iface->{'gateway'}) {
		push(@lines, $id."    "."gateway4: ".$iface->{'gateway'});
		}
	if ($iface->{'gateway6'}) {
		push(@lines, $id."    "."gateway6: ".$iface->{'gateway6'});
		}
	if ($iface->{'nameserver'}) {
		push(@lines, $id."    "."nameservers:");
		push(@lines, $id."        "."addresses: [".
			     join(",", @{$iface->{'nameserver'}})."]");
		if ($iface->{'search'}) {
			push(@lines, $id."        "."search: ".
				     $iface->{'search'});
			}
		}

	if ($iface->{'file'}) {
		# Replacing an existing interface
		my $lref = &read_file_lines($iface->{'file'});
		splice(@$lref, $iface->{'line'},
		       $iface->{'eline'} - $iface->{'line'} + 1, @lines);
		&flush_file_lines($iface->{'file'});
		}
	else {
		# Adding a new one (to it's own file)
		$iface->{'file'} = $netplan_dir."/".$iface->{'name'}.".yaml";
		@lines = ( "network:",
			   "    ethernets:",
			   @lines );
		my $lref = &read_file_lines($iface->{'file'});
		push(@$lref, @lines);
		&flush_file_lines($iface->{'file'});
		}
	}
}

# delete_interface(&details)
# Remove a boot-time interface
sub delete_interface
{
my ($cfg) = @_;
my $lref = &read_file_lines($cfg->{'file'});
splice(@$lref, $cfg->{'line'}, $cfg->{'eline'} - $cfg->{'line'} + 1);
&flush_file_lines($cfg->{'file'});
}

sub supports_bonding
{
return 0;	# XXX fix later
}

sub supports_vlans
{
return 0;	# XXX fix later
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
return 0;	# XXX fix later
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
return ( $netplan_dir, $sysctl_config );
}

sub network_config_files
{
return ( "/etc/hostname", "/etc/HOSTNAME", "/etc/mailname" );
}

# apply_network()
# Apply the interface and routing settings
sub apply_network
{
&system_logged("(cd / ; netplan apply) >/dev/null 2>&1");
}

# read_yaml_file(file)
# Converts a YAML file into a nested hash ref
sub read_yaml_file
{
my ($file) = @_;
my $lref = &read_file_lines($file, 1);
my $lnum = 0;
my $rv = [ ];
my $parent = { 'members' => $rv,
	       'indent' => -1 };
foreach my $origl (@$lref) {
	my $l = $origl;
	$l =~ s/#.*$//;
	if ($l =~ /^(\s*)(\S+):\s*(\S.*)/) {
		# Value line
		my $i = length($1);
		my $dir = { 'indent' => length($1),
			    'name' => $2,
			    'value' => $3,
			    'line' => $lnum,
			    'eline' => $lnum,
			    'parent' => $parent,
			  };
		if ($dir->{'value'} =~ /^\[(.*)\]$/) {
			$dir->{'value'} = [ split(/,/, $1) ];
			}
		push(@{$parent->{'members'}}, $dir);
		&set_parent_elines($parent, $lnum);
		}
	elsif ($l =~ /^(\s*)(\S+):\s*$/) {
		# Section header line
		my $i = length($1);
		my $dir = { 'indent' => length($1),
			    'name' => $2,
			    'members' => [ ],
			    'line' => $lnum,
			    'eline' => $lnum,
			  };
		if ($i > $parent->{'indent'}) {
			# Start of a sub-section inside the current directive
			push(@{$parent->{'members'}}, $dir);
			$dir->{'parent'} = $parent;
			&set_parent_elines($parent, $lnum);
			$parent = $dir;
			}
		else {
			# Pop up a level (or more)
			while($i <= $parent->{'indent'}) {
				$parent = $parent->{'parent'};
				}
			}
		}
	$lnum++;
	}
return $rv;
}

# set_parent_elines(&conf, eline)
sub set_parent_elines
{
my ($c, $eline) = @_;
$c->{'eline'} = $eline;
&set_parent_elines($c->{'parent'}) if ($c->{'parent'});
}

# split_addr_netmask(addr-string)
# Splits a string like 1.2.3.4/24 into an address and netmask
sub split_addr_netmask
{
my ($a) = @_;
if ($a =~ /^([0-9\.]+)\/(\d+)$/) {
	return ($1, &prefix_to_mask($2));
	}
elsif ($a =~ /^([0-9\.]+)\/([0-9\.]+)$/) {
	return ($1, $2);
	}
else {
	return $a;
	}
}

sub is_true_value
{
my ($dir) = @_;
return $dir && $dir->{'value'} =~ /true|yes|1/i;
}

1;
