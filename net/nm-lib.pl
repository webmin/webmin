# Networking functions for Network Manager

$nm_conn_dir = "/etc/NetworkManager/system-connections";

do 'linux-lib.pl';

# boot_interfaces()
# Returns a list of all interfaces activated at boot time
sub boot_interfaces
{
my @rv;
foreach my $f (glob("$nm_conn_dir/*.nmconnection")) {
	my $cfg = &read_nw_config($f);
	my $iface = { 'name' => &find_nw_config($cfg, "connection", "id"),
		      'file' => $f,
		      'cfg' => $cfg,
		      'edit' => 1,
		      'up' => 1 };
	$iface->{'fullname'} = $iface->{'name'};

	# Is DHCP enabled?
	my $method = &find_nw_config($cfg, "ipv4", "method");
	if ($method eq "auto") {
		$iface->{'dhcp'} = 1;
		}
	elsif ($method eq "disabled") {
		$iface->{'up'} = 0;
		}
	my $method6 = &find_nw_config($cfg, "ipv6", "method");
	if ($method6 eq "auto") {
		$iface->{'auto6'} = 1;
		}

	# IPv4 addresses
	my @virts;
	for(my $i=1; defined(my $addr = &find_nw_config($cfg, "ipv4", "address$i")); $i++) {
		my ($ad, $gw) = split(/,/, $addr);
		my ($ad, $cidr) = split(/\//, $ad);
		my $nm = &prefix_to_mask($cidr);
		if ($i == 1) {
			$iface->{'address'} = $ad;
			$iface->{'netmask'} = $nm;
			$iface->{'gateway'} = $gw;
			}
		else {
			push(@virts,{ 'name' => $iface->{'name'},
				      'fullname' => $iface->{'name'}.":".($i-2),
				      'file' => $f,
				      'edit' => 1,
				      'up' => 1,
				      'address' => $ad,
				      'netmask' => $nm });
			}
		}

	# IPv6 addresses
	for(my $i=1; defined(my $addr = &find_nw_config($cfg, "ipv6", "address$i")); $i++) {
		my ($ad, $cidr) = split(/\//, $addr);
		push(@{$cfg->{'address6'}}, $ad);
		push(@{$cfg->{'netmask6'}}, $cidr || 64);
		}

	# Nameservers
	my @ns = split(/\s*;\s*/, &find_nw_config($cfg, "ipv4", "dns"));
	if (@ns) {
		$iface->{'nameserver'} = \@ns;
		}
	my @sr = split(/\s*;\s*/, &find_nw_config($cfg, "ipv4", "dns-search"));
	if (@sr) {
		$iface->{'search'} = \@sr;
		}

	# XXX mac address

	push(@rv, $iface);
	push(@rv, @virts);
	}
return @rv;
}

# save_interface(&iface, &old-iface)
# Update the network manager config for an interface
sub save_interface
{
my ($iface, $oldiface) = @_;
if (!$oldiface) {
	# Need to create a new empty config
	}
else {
	# Can update existing one
	}
}

# get_hostname()
sub get_hostname
{
my $hn = &read_file_contents("/etc/hostname");
$hn =~ s/\r|\n//g;
if ($hn) {
	return $hn;
	}
return &get_system_hostname();
}

# save_hostname(name)
sub save_hostname
{
my ($hostname) = @_;
&system_logged("hostname ".quotemeta($hostname)." >/dev/null 2>&1");
foreach my $f ("/etc/hostname", "/etc/HOSTNAME", "/etc/mailname") {
	if (-r $f) {
		&open_lock_tempfile(HOST, ">$f");
		&print_tempfile(HOST, $hostname,"\n");
		&close_tempfile(HOST);
		}
	}

# Use the hostnamectl command as well
if (&has_command("hostnamectl")) {
	&system_logged("hostnamectl set-hostname ".quotemeta($hostname).
		       " >/dev/null 2>&1");
	}

undef(@main::get_system_hostname);      # clear cache
}

sub supports_address6
{
return 1;
}

sub supports_no_address
{
return 1;
}

sub supports_bridges
{
return 0;	# XXX add later
}

sub supports_bonding
{
return 0;	# XXX fix later
}

sub supports_vlans
{
return 0;	# XXX fix later
}

# can_edit(what)
# Can some boot-time interface parameter be edited?
sub can_edit
{
return 1;
}

# read_nw_config(file)
# Reads an ini-format network manager config file
sub read_nw_config
{
my ($f) = @_;
my $lref = &read_file_lines($f, 1);
my @rv;
my $sect;
my $lnum = 0;
foreach my $l (@$lref) {
	if ($l =~ /^\s*\[(\S+)\]/) {
		# Start of a section
		$sect =  { 'sect' => $1,
			   'members' => [ ],
			   'file' => $f,
			   'line' => $lnum,
			   'eline' => $lnum };
		push(@rv, $sect);
		}
	elsif ($l =~ /^\s*([^ =]+)\s*=\s*(.*)/ && $sect) {
		# Variable in a section
		push(@{$sect->{'members'}}, { 'name' => $1,
					      'value' => $2,
					      'file' => $f,
					      'line' => $lnum,
					      'eline' => $lnum });
		$sect->{'eline'} = $lnum;
		}
	$lnum++;
	}
return \@rv;
}

# write_nw_config(file, &config)
# Writes out an ini-format network manager config file
sub write_nw_config
{
}

# find_nw_config(&config, section, name)
# Returns the value of a directive in some section, or undef
sub find_nw_config
{
my ($cfg, $sname, $name) = @_;
my ($sect) = grep { $_->{'sect'} eq $sname } @$cfg;
return undef if (!$sect);
my ($dir) = grep { $_->{'name'} eq $name } @{$sect->{'members'}};
return undef if (!$dir);
return $dir->{'value'};
}

# save_nw_config(&config, section, name, value)
# Updates, creates or deletes a directive in some section
sub save_nw_config
{
my ($cfg, $sname, $name, $value) = @_;
my ($sect) = grep { $_->{'sect'} eq $sname } @$cfg;
# XXX
}

