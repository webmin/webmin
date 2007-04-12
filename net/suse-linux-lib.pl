# suse-linux-lib.pl
# Networking functions for SuSE linux

$rc_config = "/etc/rc.config";
$route_conf = "/etc/route.conf";

$use_suse_dns = 1;
do 'linux-lib.pl';

# boot_interfaces()
# Returns a list of interfaces brought up at boot time
sub boot_interfaces
{
local $rc = &parse_rc_config();
local @rv;
push(@rv, { 'fullname' => 'lo',
	    'name' => 'lo',
	    'up' => $rc->{'START_LOOPBACK'}->{'value'} =~ /yes/,
	    'address' => '127.0.0.1',
	    'netmask' => '255.0.0.0',
	    'broadcast' => '127.255.255.255',
	    'edit' => 0,
	    'file' => $rc_config,
	    'index' => scalar(@rv) });
local @nc = split(/\s+/, $rc->{'NETCONFIG'}->{'value'});
foreach $nc (@nc) {
	local $ip = $rc->{"IPADDR$nc"}->{'value'};
	local $dev = $rc->{"NETDEV$nc"}->{'value'};
	local $conf = $rc->{"IFCONFIG$nc"}->{'value'};
	if ($dev) {
		local $b;
		$b->{'fullname'} = $dev;
		if ($b->{'fullname'} =~ /(\S+):(\d+)/) {
			$b->{'name'} = $1;
			$b->{'virtual'} = $2;
			}
		else { $b->{'name'} = $b->{'fullname'}; }
		if ($conf =~ /^([0-9\.]+)/) {
			$b->{'address'} = $1;
			if ($conf =~ /broadcast\s+(\S+)/) {
				$b->{'broadcast'} = $1;
				}
			if ($conf =~ /netmask\s+(\S+)/) {
				$b->{'netmask'} = $1;
				}
			if ($conf =~ /\s+up/ || $gconfig{'os_version'} >= 7.1) {
				$b->{'up'} = 1;
				}
			}
		elsif ($conf =~ /bootp/) {
			$b->{'bootp'} = 1;
			$b->{'netmask'} = 'Automatic';
			$b->{'broadcast'} = 'Automatic';
			$b->{'up'}++;
			}
		elsif ($conf =~ /dhcpclient/) {
			$b->{'dhcp'} = 1;
			$b->{'netmask'} = 'Automatic';
			$b->{'broadcast'} = 'Automatic';
			$b->{'up'}++;
			}
		$b->{'edit'} = 1;
		$b->{'index'} = scalar(@rv);
		$b->{'nc'} = $nc;
		$b->{'file'} => $rc_config,
		push(@rv, $b);
		}
	}
return @rv;
}

# save_interface(&details)
# Create or update a boot-time interface
sub save_interface
{
# Find existing interface, if any
&lock_file($rc_config);
local $rc = &parse_rc_config();
local @boot = &boot_interfaces();
local ($o, $old, $found);
foreach $o (@boot) {
	if ($o->{'name'} eq $_[0]->{'name'} &&
	    $o->{'virtual'} eq $_[0]->{'virtual'}) {
		$found++; $old = $o;
		last;
		}
	}

# build interface detail strings
local $fullname = $_[0]->{'name'};
$fullname .= ":".$_[0]->{'virtual'} if (defined($_[0]->{'virtual'}));
local $ifconfig;
if ($_[0]->{'bootp'}) {
	$ifconfig = 'bootp';
	}
elsif ($_[0]->{'dhcp'}) {
	$ifconfig = 'dhcpclient';
	}
else {
	$ifconfig = $_[0]->{'address'};
	$ifconfig .= " broadcast $_[0]->{'broadcast'}"
		if ($_[0]->{'broadcast'});
	$ifconfig .= " netmask $_[0]->{'netmask'}"
		if ($_[0]->{'netmask'});
	$ifconfig .= " up" if ($_[0]->{'up'});
	}

if ($found) {
	# Updating an existing interface
	local $nnc = $old->{'nc'};
	&save_rc_config($rc, "IPADDR$nnc", $_[0]->{'address'});
	&save_rc_config($rc, "NETDEV$nnc", $fullname);
	&save_rc_config($rc, "IFCONFIG$nnc", $ifconfig);
	}
else {
	# Adding a new interface
	local @nc = split(/\s+/, $rc->{'NETCONFIG'}->{'value'});
	local $nnc = $nc[@nc-1] =~ /_(\d+)/ ? "_".($1+1) : "_0";
	&save_rc_config($rc, "NETCONFIG", join(" ", @nc, $nnc));
	&save_rc_config($rc, "IPADDR$nnc", $_[0]->{'address'});
	&save_rc_config($rc, "NETDEV$nnc", $fullname);
	&save_rc_config($rc, "IFCONFIG$nnc", $ifconfig);
	}
&unlock_file($rc_config);
}

# delete_interface(&details)
# Delete a boot-time interface
sub delete_interface
{
&lock_file($rc_config);
local $rc = &parse_rc_config();
local @boot = &boot_interfaces();
local $old;
foreach $old (@boot) {
	if ($old->{'name'} eq $_[0]->{'name'} &&
	    $old->{'virtual'} eq $_[0]->{'virtual'}) {
		# found it .. remove
		local $nnc = $old->{'nc'};
		local @nc = split(/\s+/, $rc->{'NETCONFIG'}->{'value'});
		@nc = grep { $_ ne $nnc } @nc;
		&save_rc_config($rc, "NETCONFIG", join(" ", @nc));
		&save_rc_config($rc, "IPADDR$nnc", "");
		&save_rc_config($rc, "NETDEV$nnc", "");
		&save_rc_config($rc, "IFCONFIG$nnc", "");
		}
	}
&unlock_file($rc_config);
}

# can_edit(what, &details)
# Can some boot-time interface parameter be edited?
sub can_edit
{
if ($gconfig{'os_version'} >= 7.1) {
	if ($_[1] && ($_[1]->{'bootp'} || $_[1]->{'dhcp'})) {
		return $_[0] ne "mtu" && $_[0] ne "netmask" &&
		       $_[0] ne "broadcast" && $_[0] ne "up";
		}
	return $_[0] ne "mtu" && $_[0] ne "up";
	}
else {
	if ($_[1] && $_[1]->{'bootp'}) {
		return $_[0] ne "mtu" && $_[0] ne "dhcp" &&
		       $_[0] ne "netmask" && $_[0] ne "broadcast" &&
		       $_[0] ne "up";
		}
	return $_[0] ne "mtu" && $_[0] ne "dhcp";
	}
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
local $rc = &parse_rc_config();
return $rc->{'FQHOSTNAME'}->{'value'};
}

# save_hostname(name)
sub save_hostname
{
&system_logged("hostname $_[0] >/dev/null 2>&1");
&lock_file($rc_config);
local $rc = &parse_rc_config();
&save_rc_config($rc, "FQHOSTNAME", $_[0]);
&unlock_file($rc_config);

# run SuSEconfig, as this function is called last
&system_logged("SuSEconfig -quick >/dev/null 2>&1");

undef(@main::get_system_hostname);      # clear cache
}

sub routing_config_files
{
return ( $route_conf, $rc_config );
}

sub routing_input
{
# read route.conf
local ($default, @sr, @lr);
&open_readfile(ROUTE, $route_conf);
while(<ROUTE>) {
	s/\r|\n//g;
	s/#.*$//g;
	local @r = split(/\s+/, $_);
	if ($r[0] eq 'default' || $r[0] eq '0.0.0.0') { $default = $r[1]; }
	elsif (@r == 4) { push(@lr, \@r); }
	elsif (@r == 3) { push(@sr, \@r); }
	}
close(ROUTE);

# input for routing
local $rc = &parse_rc_config();
local $ipf = $rc->{'IP_FORWARD'}->{'value'};
print "<tr> <td><b>$text{'routes_forward'}</b></td> <td>\n";
printf "<input type=radio name=forward value=yes %s> $text{'yes'}\n",
	$ipf eq "yes" ? "checked" : "";
printf "<input type=radio name=forward value=no %s> $text{'no'}</td> </tr>\n",
	$ipf eq "yes" ? "" : "checked";

# input for default route
print "<tr> <td><b>$text{'routes_default'}</b></td> <td>\n";
printf "<input type=radio name=default_def value=1 %s> $text{'routes_none'}\n",
	$default ? "" : "checked";
printf "<input type=radio name=default_def value=0 %s>\n",
	$default ? "checked" : "";
printf "<input name=default size=15 value=\"%s\"></td> </tr>\n",
	$default;

# table for local routes
print "<tr> <td valign=top><b>$text{'routes_local'}</b></td>\n";
print "<td><table border>\n";
print "<tr $tb> <td><b>$text{'routes_ifc'}</b></td> ",
      "<td><b>$text{'routes_net'}</b></td> ",
      "<td><b>$text{'routes_mask'}</b></td> </tr>\n";
for($i=0; $i<=@lr; $i++) {
	local $lr = $lr[$i];
	print "<tr $cb>\n";
	print "<td><input name=lr_dev_$i size=6 value='$lr->[3]'></td>\n";
	print "<td><input name=lr_net_$i size=15 value='$lr->[0]'></td>\n";
	print "<td><input name=lr_mask_$i size=15 value='$lr->[2]'></td>\n";
	print "</tr>\n";
	}
print "</table></td> </tr>\n";

# table for static routes
print "<tr> <td valign=top><b>$text{'routes_static'}</b></td>\n";
print "<td><table border>\n";
print "<tr $tb> <td><b>$text{'routes_net'}</b></td> ",
      "<td><b>$text{'routes_gateway'}</b></td> ",
      "<td><b>$text{'routes_mask'}</b></td> </tr>\n";
for($i=0; $i<=@sr; $i++) {
	local $sr = $sr[$i];
	print "<tr $cb>\n";
	print "<td><input name=sr_net_$i size=15 value='$sr->[0]'></td>\n";
	print "<td><input name=sr_gw_$i size=15 value='$sr->[1]'></td>\n";
	print "<td><input name=sr_mask_$i size=15 value='$sr->[2]'></td>\n";
	print "</tr>\n";
	}
print "</table></td> </tr>\n";

}

sub parse_routing
{
&lock_file($rc_config);
local $rc = &parse_rc_config();
&save_rc_config($rc, IP_FORWARD, $in{'forward'});
&unlock_file($rc_config);
&lock_file($route_conf);
local $route = "# Generated by Webmin\n";
for($i=0; defined($dev = $in{"lr_dev_$i"}); $i++) {
	$net = $in{"lr_net_$i"}; $mask = $in{"lr_mask_$i"};
	next if (!$dev && !$net && !$mask);
	gethostbyname($net) ||
		&error(&text('routes_enet', $net));
	&check_ipaddress($mask) ||
		&error(&text('routes_emask', $mask));
	$route .= "$net\t\t0.0.0.0\t\t$mask\t\t$dev\n";
	}
for($i=0; defined($gw = $in{"sr_gw_$i"}); $i++) {
	$net = $in{"sr_net_$i"}; $mask = $in{"sr_mask_$i"};
	next if (!$gw && !$net && !$mask);
	gethostbyname($gw) ||
		&error(&text('routes_egateway', $gw));
	gethostbyname($net) ||
		&error(&text('routes_enet', $net));
	&check_ipaddress($mask) ||
		&error(&text('routes_emask', $mask));
	$route .= "$net\t\t$gw\t\t$mask\n";
	}
if (!$in{'default_def'}) {
	gethostbyname($in{'default'}) ||
		&error(&text('routes_edefault', $in{'default'}));
	$route .= "default\t\t$in{'default'}\n";
	}
&open_tempfile(ROUTE, ">$route_conf");
&print_tempfile(ROUTE, $route);
&close_tempfile(ROUTE);
&unlock_file($route_conf);
}

# parse_rc_config()
sub parse_rc_config
{
local $rc;
local $lnum = 0;
&open_readfile(CONF, $rc_config);
while(<CONF>) {
	s/\r|\n//g;
	s/#.*$//g;
	if (/([^=\s]+)="(.*)"/) {
		$rc->{$1} = { 'value' => $2,
			      'line' => $lnum };
		}
	elsif (/([^=\s]+)=(\S+)/) {
		$rc->{$1} = { 'value' => $2,
			      'line' => $lnum };
		}
	$lnum++;
	}
close(CONF);
return $rc;
}

# save_rc_config(&config, directive, value)
sub save_rc_config
{
local $old = $_[0]->{$_[1]};
local $line = "$_[1]=\"$_[2]\"\n";
if ($old) {
	&replace_file_line($rc_config, $old->{'line'}, $line);
	}
else {
	&open_tempfile(RC, ">>$rc_config");
	&print_tempfile(RC, $line);
	&close_tempfile(RC);
	}
}

sub os_feedback_files
{
return ( $rc_config, $route_conf, "/etc/resolv.conf", "/etc/nsswitch.conf" );
}

1;

