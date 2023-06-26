# Networking functions for Network Manager
# XXX apply new interface
# XXX UUID has to match

$nm_conn_dir = "/etc/NetworkManager/system-connections";
$sysctl_config = "/etc/sysctl.conf";

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
				      'virtual' => $i-2,
				      'file' => $f,
				      'cfg' => $cfg,
				      'edit' => 1,
				      'up' => 1,
				      'address' => $ad,
				      'netmask' => $nm });
			}
		}

	# IPv6 addresses
	for(my $i=1; defined(my $addr = &find_nm_config($cfg, "ipv6", "address$i")); $i++) {
		my ($ad, $gw) = split(/,/, $addr);
		my ($ad, $cidr) = split(/\//, $addr);
		push(@{$iface->{'address6'}}, $ad);
		push(@{$iface->{'netmask6'}}, $cidr || 64);
		$iface->{'gateway6'} ||= $gw;
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

	# MTU
	$iface->{'mtu'} = &find_nm_config($cfg, "ethernet", "mtu");

	# Static routes
	my @routes;
	for(my $i=1; defined($r = &find_nm_config($cfg, "ipv4", "route$i")); $i++) {
		push(@routes, $r);
		}
	$iface->{'routes'} = \@routes if (@routes);

	push(@rv, $iface);
	push(@rv, @virts);
	}
for(my $i=0; $i<@rv; $i++) {
	$rv[$i]->{'index'} = $i;
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
		my $uuid;
		my $out = &backquote_command("nmcli conn show");
		foreach my $l (split(/\r?\n/, $out)) {
			my @w = split(/\s+/, $l);
			if ($w[@w-1] eq $iface->{'name'}) {
				$uuid = $w[@w-3];
				last;
				}
			}
		if (!$uuid) {
			# Make one up!
			$uuid = &read_file_contents(
				"/proc/sys/kernel/random/uuid");
			$uuid =~ s/\r|\n//g;
			}
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
				{ 'name' => 'autoconnect-priority',
				  'value' => '-999' },
				{ 'name' => 'timestamp',
				  'value' => time() },
				],
			 },
			 { 'sect' => 'ethernet',
			   'members' => [ ],
			 },
			 { 'sect' => 'ipv4',
			   'members' => [ ],
			 },
			 { 'sect' => 'ipv6',
			   'members' => [
				{ 'name' => 'addr-gen-mode',
				  'value' => 'default' },
				],
			 },
			 { 'sect' => 'ethernet',
			   'members' => [ ],
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
	for(my $i=$maxv6+1; &find_nm_config($cfg, "ipv6", "address".$i); $i++) {
		&save_nm_config($cfg, "ipv6", "address".$i, undef);
		}
	&save_nm_config($cfg, "ipv6", "method",
		$iface->{'auto6'} ? "auto" :
		@{$iface->{'address6'}} ? "manual" : undef);

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

	# Update MTU
	&save_nm_config($cfg, "ethernet", "mtu", $iface->{'mtu'});

	# Update static routes
	my $maxrt = 0;
	for(my $i=0; $i<@{$iface->{'routes'}}; $i++) {
		$maxrt = $i+1;
		&save_nm_config($cfg, "ipv4", "route".($i+1),
				$iface->{'routes'}->[$i]);
		}
	for(my $i=$maxrt+1; &find_nm_config($cfg, "ipv4", "route".$i); $i++) {
		&save_nm_config($cfg, "ipv6", "route".$i, undef);
		}
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
		&save_nm_config($iface->{'cfg'}, "ipv4", "address".$i, $nv);
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

# get_domainname()
sub get_domainname
{
my $d;
&execute_command("domainname", undef, \$d, undef);
chop($d);
return $d;
}

# save_domainname(domain)
sub save_domainname
{
my ($domain) = @_;
&execute_command("domainname ".quotemeta($domain));
}

sub routing_config_files
{
return ( $nm_conn_dir );
}

# routing_input()
# show default router and device
sub routing_input
{
my ($addr, $router) = &get_default_gateway();
my ($addr6, $router6) = &get_default_ipv6_gateway();
my @ifaces = grep { $_->{'virtual'} eq '' } &boot_interfaces();
my @inames = map { $_->{'name'} } @ifaces;

# Show default gateway
print &ui_table_row($text{'routes_default'},
	&ui_radio("gateway_def", $addr ? 0 : 1,
		  [ [ 1, $text{'routes_none'} ],
		    [ 0, $text{'routes_gateway'}." ".
			 &ui_textbox("gateway", $addr, 15)." ".
			 &ui_select("gatewaydev", $router, \@inames) ] ]));

# Show default IPv6 gateway
print &ui_table_row($text{'routes_default6'},
	&ui_radio("gateway6_def", $addr6 ? 0 : 1,
		  [ [ 1, $text{'routes_none'} ],
		    [ 0, $text{'routes_gateway'}." ".
			 &ui_textbox("gateway6", $addr6, 30)." ".
			 &ui_select("gatewaydev6", $router6, \@inames) ] ]));

# Act as router?
my %sysctl;
&read_env_file($sysctl_config, \%sysctl);
print &ui_table_row($text{'routes_forward'},
	&ui_yesno_radio("forward",
			$sysctl{'net.ipv4.ip_forward'} ? 1 : 0));

# Static routes
my $rtable = &ui_columns_start([ $text{'routes_ifc'},
			       $text{'routes_net'},
			       $text{'routes_mask'},
			       $text{'routes_gateway'} ]);
my $i = 0;
@inames = ( "", @inames );
foreach my $b (@ifaces) {
	foreach my $v (@{$b->{'routes'}}) {
		my ($net, $gw) = split(/,/, $v);
		my $cidr;
		($net, $cidr) = split(/\//, $net);
		my $mask = &prefix_to_mask($cidr);
		$rtable .= &ui_columns_row([
		    &ui_select("dev_$i", $b->{'fullname'}, \@inames, 1, 0, 1),
		    &ui_textbox("net_$i", $net, 15),
		    &ui_textbox("mask_$i", $mask, 15),
		    &ui_textbox("gw_$i", $gw, 15),
		    ]);
		$i++;
		}
	}
$rtable .= &ui_columns_row([
	&ui_select("dev_$i", "", \@inames, 1, 0, 1),
	&ui_textbox("net_$i", "", 15),
	&ui_textbox("mask_$i", "", 15),
	&ui_textbox("gw_$i", "", 15),
	]);
$rtable .= &ui_columns_end();
print &ui_table_row($text{'routes_static'}, $rtable);
}

# parse_routing()
# Save the form generated by routing_input
sub parse_routing
{
# Save IPv4 address
my ($dev, $gw);
if (!$in{'gateway_def'}) {
	&check_ipaddress($in{'gateway'}) ||
		&error(&text('routes_egateway', &html_escape($in{'gateway'})));
	$gw = $in{'gateway'};
	$dev = $in{'gatewaydev'};
	}
&set_default_gateway($gw, $dev);

# Save IPv6 address
my ($dev6, $gw6);
if (!$in{'gateway6_def'}) {
	&check_ip6address($in{'gateway6'}) ||
		&error(&text('routes_egateway6',&html_escape($in{'gateway6'})));
	$gw6 = $in{'gateway6'};
	$dev6 = $in{'gatewaydev6'};
	}
&set_default_ipv6_gateway($gw6, $dev6);

# Save routing flag
my %sysctl;
&lock_file($sysctl_config);
&read_env_file($sysctl_config, \%sysctl);
$sysctl{'net.ipv4.ip_forward'} = $in{'forward'};
&write_env_file($sysctl_config, \%sysctl);
&unlock_file($sysctl_config);

# Save static routes
my @boot =  &boot_interfaces();
foreach my $b (grep { $_->{'virtual'} eq '' } @boot) {
	my @r;
	for(my $i=0; defined($in{"dev_$i"}); $i++) {
		if ($in{"dev_$i"} eq $b->{'fullname'}) {
			&check_ipaddress($in{"net_$i"}) ||
				&error(&text('routes_enet', $in{"net_$i"}));
			&check_ipaddress($in{"mask_$i"}) ||
				&error(&text('routes_emask', $in{"mask_$i"}));
			my $to = $in{"net_$i"}."/".
				 &mask_to_prefix($in{"mask_$i"});
			&check_ipaddress($in{"gw_$i"}) ||
				&error(&text('routes_egateway', $in{"gw_$i"}));
			push(@r, $to.",".$in{"gw_$i"});
			}
		}
	if (@r) {
		$b->{'routes'} = \@r;
		}
	else {
		delete($b->{'routes'});
		}
	&save_interface($b, \@boot);
	}
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

# get_default_gateway()
# Returns the default gateway IP (if one is set) and device (if set) boot time
# settings.
sub get_default_gateway
{
foreach my $iface (&boot_interfaces()) {
	if ($iface->{'gateway'}) {
		return ( $iface->{'gateway'}, $iface->{'fullname'} );
		}
	}
return ( );
}

# set_default_gateway([gateway, device])
# Sets the default gateway to the given IP accessible via the given device,
# in the boot time settings.
sub set_default_gateway
{
my ($gw, $dev) = @_;
foreach my $iface (&boot_interfaces()) {
	if ($iface->{'fullname'} eq $dev && $iface->{'gateway'} ne $gw) {
		# Need to add to this interface
		$iface->{'gateway'} = $gw;
		&save_interface($iface);
		}
	elsif ($iface->{'fullname'} ne $dev && $iface->{'gateway'}) {
		# Need to remove from this interface
		delete($iface->{'gateway'});
		&save_interface($iface);
		}
	}
}

# get_default_ipv6_gateway()
# Returns the default gateway IPv6 address (if one is set) and device (if set)
# boot time settings.
sub get_default_ipv6_gateway
{
foreach my $iface (&boot_interfaces()) {
	if ($iface->{'gateway6'}) {
		return ( $iface->{'gateway6'}, $iface->{'fullname'} );
		}
	}
return ( );
}

# set_default_ipv6_gateway([gateway, device])
# Sets the default IPv6 gateway to the given IP accessible via the given device,
# in the boot time settings.
sub set_default_ipv6_gateway
{
my ($gw, $dev) = @_;
foreach my $iface (&boot_interfaces()) {
	if ($iface->{'fullname'} eq $dev && $iface->{'gateway6'} ne $gw) {
		# Need to add to this interface
		$iface->{'gateway6'} = $gw;
		&save_interface($iface);
		}
	elsif ($iface->{'fullname'} ne $dev && $iface->{'gateway6'}) {
		# Need to remove from this interface
		delete($iface->{'gateway6'});
		&save_interface($iface);
		}
	}
}

# os_save_dns_config(&config)
# DNS servers are stored in the Network Manager config files
sub os_save_dns_config
{
my ($conf) = @_;
my @boot = &boot_interfaces();
my @fix = grep { $_->{'nameserver'} } @boot;
@fix = @boot if (!@fix);
foreach my $iface (@fix) {
	$iface->{'nameserver'} = $conf->{'nameserver'};
	$iface->{'search'} = $conf->{'domain'};
	&save_interface($iface);
	}
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
	$sect->{'eline'} = $lnum;
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
my @dirs = grep { $_->{'name'} eq $name } @{$sect->{'members'}};
return wantarray ? map { $_->{'value'} } @dirs :
       @dirs ? $dirs[0]->{'value'} : undef;
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
	push(@$lref, "[$sect->{'sect'}]");
	}

# Find the directive
my @dirs = grep { $_->{'name'} eq $name } @{$sect->{'members'}};
my @values = ref($value) ? @$value :
	     defined($value) ? ( $value ) : ( );
for(my $i=0; $i<@dirs || $i<@values; $i++) {
	my $dir = $i<@dirs ? $dirs[$i] : undef;
	my $val = $i<@values ? $values[$i] : undef;
	if ($dir && defined($val)) {
		# Update existing line
		$dir->{'value'} = $val;
		$lref->[$dir->{'line'}] = $name."=".$val;
		}
	elsif ($dir && !defined($val)) {
		# Remove existing line
		$sect->{'members'} = [ grep { $_ ne $dir } @{$sect->{'members'}} ];
		splice(@$lref, $dir->{'line'}, 1);
		&renumber_nm_config($cfg, $dir->{'line'}, -1);
		}
	elsif (!$dir && defined($val)) {
		# Add a new line
		$dir = { 'name' => $name,
			 'value' => $val,
			 'file' => $file,
			 'line' => $sect->{'eline'}+1,
			 'eline' => $sect->{'eline'}+1 };
		splice(@$lref, $sect->{'eline'}+1, 0, $name."=".$val);
		&renumber_nm_config($cfg, $sect->{'eline'}, 1);
		push(@{$sect->{'members'}}, $dir);
		}
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

