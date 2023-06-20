# Networking functions for Network Manager
# XXX DNS config change

$nm_conn_dir = "/etc/NetworkManager/system-connections";

do 'linux-lib.pl';

# boot_interfaces()
# Returns a list of all interfaces activated at boot time
sub boot_interfaces
{
my @rv;
foreach my $f (glob("$nm_conn_dir/*.nmconnection")) {
	my $cfg = &read_nm_config($f);
	my $iface = { 'name' => &find_nm_config($cfg, "connection", "id"),
		      'file' => $f,
		      'cfg' => $cfg,
		      'edit' => 1,
		      'up' => 1 };
	$iface->{'fullname'} = $iface->{'name'};

	# Is DHCP enabled?
	my $method = &find_nm_config($cfg, "ipv4", "method");
	if ($method eq "auto") {
		$iface->{'dhcp'} = 1;
		}
	elsif ($method eq "disabled") {
		$iface->{'up'} = 0;
		}
	my $method6 = &find_nm_config($cfg, "ipv6", "method");
	if ($method6 eq "auto") {
		$iface->{'auto6'} = 1;
		}

	# IPv4 addresses
	my @virts;
	for(my $i=1; defined(my $addr = &find_nm_config($cfg, "ipv4", "address$i")); $i++) {
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
	# XXX IPv6 gateway??
	for(my $i=1; defined(my $addr = &find_nm_config($cfg, "ipv6", "address$i")); $i++) {
		my ($ad, $cidr) = split(/\//, $addr);
		push(@{$cfg->{'address6'}}, $ad);
		push(@{$cfg->{'netmask6'}}, $cidr || 64);
		}

	# Nameservers
	my @ns = split(/\s*;\s*/, &find_nm_config($cfg, "ipv4", "dns"));
	if (@ns) {
		$iface->{'nameserver'} = \@ns;
		}
	my @sr = split(/\s*;\s*/, &find_nm_config($cfg, "ipv4", "dns-search"));
	if (@sr) {
		$iface->{'search'} = \@sr;
		}

	# Mac address
	$iface->{'ether'} = &find_nm_config($cfg, "ethernet",
					    "cloned-mac-address");

	push(@rv, $iface);
	push(@rv, @virts);
	}
return @rv;
}

# save_interface(&iface, &old-ifaces)
# Update the network manager config for an interface
sub save_interface
{
my ($iface, $boot) = @_;
$boot ||= [ &boot_interfaces() ];
my $f;
if ($iface->{'virtual'} ne '') {
	# Virtual IP on a real interface
	my ($baseiface) = grep { $_->{'fullname'} eq $iface->{'name'} } @$boot;
	$baseiface || &error("Base interface $iface->{'name'} does not exist");
	my $i = $iface->{'virtual'}+2;
	my $v = $iface->{'address'}."/".&mask_to_prefix($iface->{'netmask'});
	$f = $baseiface->{'file'};
	&lock_file($f);
	&save_nm_config($baseiface->{'cfg'}, "ipv4", "address".$i, $v);
	}
else {
	my $cfg;
	if ($iface->{'file'}) {
		# Config file already exists
		$f = $iface->{'file'};
		$cfg = $iface->{'cfg'};
		&lock_file($f);
		}
	else {
		# Need to create a new empty config
		my $uuid = &read_file_contents("/proc/sys/kernel/random/uuid");
		$uuid =~ s/\r|\n//g;
		$cfg = [ { 'sect' => 'connection',
			   'members' => [
				{ 'name' => 'id',
				  'value' => $iface->{'name'} },
				{ 'name' => 'uuid',
				  'value' => $uuid },
				{ 'name' => 'type',
				  'value' => 'ethernet' },
				{ 'name' => 'interface-name',
				  'value' => $iface->{'name'} },
				],
			 },
		       ];
		$f = $nm_conn_dir."/".$iface->{'name'}.".nmconnection";
		&lock_file($f);
		&write_nm_config($f, $cfg);
		}

	# Update address
	my $v = $iface->{'address'}."/".&mask_to_prefix($iface->{'netmask'});
	if ($iface->{'gateway'}) {
		$v .= ",".$iface->{'gateway'};
		}
	&save_nm_config($cfg, "ipv4", "address1", $v);

	# Update DHCP mode
	&save_nm_config($cfg, "ipv4", "method",
		!$iface->{'up'} ? "disabled" :
		$iface->{'dhcp'} ? "auto" : "manual");

	# Update IPv6 addresses
	my $maxv6 = 0;
	for(my $i=0; $i<@{$iface->{'address6'}}; $i++) {
		my $v = $iface->{'address6'}->[$i]."/".
			$iface->{'netmask6'}->[$i];
		$maxv6 = $i+1;
		&save_nm_config($cfg, "ipv6", "address".($i+1), $v);
		}
	for(my $i=$maxv6+1; &find_nm_config($cfg, "ipv6", $i); $i++) {
		&save_nm_config($cfg, "ipv6", "address".$i, undef);
		}

	# Update nameservers
	my @ns = $iface->{'nameserver'} ? @{$iface->{'nameserver'}} : ();
	&save_nm_config($cfg, "ipv4", "dns",
			@ns ? join(";", @ns) : undef);
	my @sr = $iface->{'search'} ? @{$iface->{'search'}} : ();
	&save_nm_config($cfg, "ipv4", "dns-search",
			@sr ? join(";", @sr) : undef);

	# Update MAC address
	&save_nm_config($cfg, "ethernet", "cloned-mac-address",
			$iface->{'ether'});
	}
&flush_file_lines($f);
&unlock_file($f);
}

# delete_interface(&iface)
# Remove a boot-time interface
sub delete_interface
{
my ($iface) = @_;
if ($iface->{'virtual'} ne '') {
	# Just remove the virtual address and shift down
	&lock_file($iface->{'file'});
	my $i = $iface->{'virtual'}+2;
	while(1) {
		my $nv = &find_nm_config(
			$baseiface->{'cfg'}, "ipv4", "address".($i+1));
		&save_nm_config($baseiface->{'cfg'}, "ipv4", "address".$i, $nv);
		last if (!$nv);
		}
	&flush_file_lines($iface->{'file'});
	&unlock_file($iface->{'file'});
	}
else {
	# Remove the whole interface file
	&unlink_logged($iface->{'file'});
	}
}

# valid_boot_address(address)
# Is some address valid for a bootup interface
sub valid_boot_address
{
my ($a) = @_;
return &check_ipaddress_any($a);
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

# apply_network()
# Apply the interface and routing settings
sub apply_network
{
&system_logged("(cd / ; nmcli networking off; nmcli networking on) >/dev/null 2>&1");
}

sub network_config_files
{
return ( "/etc/hostname", "/etc/HOSTNAME", "/etc/mailname" );
}

# read_nm_config(file)
# Reads an ini-format network manager config file
sub read_nm_config
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

# write_nm_config(file, &config)
# Writes out an ini-format network manager config file
sub write_nm_config
{
my ($file, $cfg) = @_;
my $lnum = 0;
&open_lock_tempfile(NW, ">$file");
foreach my $sect (@$cfg) {
	$sect->{'line'} = $lnum;
	$sect->{'file'} = $file;
	&print_tempfile(NW, "[$sect->{'sect'}]\n");
	$lnum++;
	foreach my $dir (@{$sect->{'members'}}) {
		&print_tempfile(NW, $dir->{'name'}."=".$dir->{'value'}."\n");
		$dir->{'eline'} = $dir->{'eline'} = $sect->{'eline'} = $lnum;
		$dir->{'file'} = $file;
		$lnum++;
		}
	&print_tempfile(NW, "\n");
	$lnum++;
	}
&close_tempfile(NW);
}

# find_nm_config(&config, section, name)
# Returns the value of a directive in some section, or undef
sub find_nm_config
{
my ($cfg, $sname, $name) = @_;
my ($sect) = grep { $_->{'sect'} eq $sname } @$cfg;
return undef if (!$sect);
my ($dir) = grep { $_->{'name'} eq $name } @{$sect->{'members'}};
return undef if (!$dir);
return $dir->{'value'};
}

# save_nm_config(&config, section, name, value, [file])
# Updates, creates or deletes a directive in some section
sub save_nm_config
{
my ($cfg, $sname, $name, $value, $file) = @_;
$file ||= $cfg->[0]->{'file'};
my $lref = &read_file_lines($file);

# Find or create a new section
my ($sect) = grep { $_->{'sect'} eq $sname } @$cfg;
if (!$sect && !defined($value)) {
	# No value, but the section doesn't exist!
	return;
	}
if (!$sect) {
	$sect = { 'sect' => $sname,
		  'members' => [ ],
		  'file' => $file,
		  'line' => scalar(@$lref),
		  'eline' => scalar(@$lref) };
	push(@$cfg, $sect);
	push(@$lref, "[$sect->{'name'}]");
	}

# Find the directive
my ($dir) = grep { $_->{'name'} eq $name } @{$sect->{'members'}};
if ($dir && defined($value)) {
	# Update existing line
	$dir->{'value'} = $value;
	$lref->[$dir->{'line'}] = $name."=".$value;
	}
elsif ($dir && !defined($value)) {
	# Remove existing line
	$sect->{'members'} = [ grep { $_ ne $dir } @{$sect->{'members'}} ];
	splice(@$lref, $dir->{'line'}, 1);
	&renumber_nm_config($cfg, $dir->{'line'}, -1);
	}
elsif (!$dir && defined($value)) {
	# Add a new line
	$dir = { 'name' => $name,
		 'value' => $value,
		 'file' => $file,
		 'line' => $sect->{'eline'}+1,
		 'eline' => $sect->{'eline'}+1 };
	splice(@$lref, $sect->{'eline'}+1, $name."=".$value);
	&renumber_nm_config($cfg, $sect->{'eline'}, 1);
	push(@{$sect->{'members'}}, $dir);
	}
elsif (!$dir && !defined($value)) {
	# No value, and it's not current set either .. so nothing to do!
	}
}

# renumber_nm_config(&config, line, offset)
# Adjust line numbers in the config file
sub renumber_nm_config
{
my ($cfg, $line, $offset) = @_;
foreach my $sect (@$cfg) {
	$sect->{'line'} += $offset if ($sect->{'line'} >= $line);
	$sect->{'eline'} += $offset if ($sect->{'eline'} >= $line);
	foreach my $dir (@{$sect->{'members'}}) {
		$dir->{'line'} += $offset if ($dir->{'line'} >= $line);
		$dir->{'eline'} += $offset if ($dir->{'eline'} >= $line);
		}
	}
}

