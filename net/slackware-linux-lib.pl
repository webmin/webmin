# slackware-linux-lib.pl
# Networking functions for slackware linux
# To support boot-time interfaces, ifconfig commands are added to rc.local so
# that additional virtual interfaces can be created

do 'linux-lib.pl';
%iconfig = &foreign_config("init");
$interfaces_file = $iconfig{'local_script'} || $iconfig{'extra_init'};
$rc_init = "/etc/rc.d/rc.inet1";
$dhcp_init = "/etc/rc.d/rc.dhcpd";

# boot_interfaces()
# Returns a list of interfaces brought up at boot time
sub boot_interfaces
{
local @rv;

# Look in rc.init1 file for master interface
local $iface = { 'up' => 1,
		 'edit' => 1,
		 'index' => 0,
		 'init' => 1,
		 'name' => 'eth0',
		 'fullname' => 'eth0',
		 'file' => $rc_init };
local $gotdevice;
&open_readfile(INIT, $rc_init);
while(<INIT>) {
	s/\r|\n//g;
	s/#.*$//;
	if (/^\s*IPADDR\s*=\s*["']?([0-9\.]+)/) {
		$iface->{'address'} = $1;
		}
	elsif (/^\s*DEVICE\s*=\s*["']?([0-9\.]+)/) {
		$iface->{'name'} = $iface->{'fullname'} = $1;
		$gotdevice++;
		}
	elsif (/^\s*NETMASK\s*=\s*["']?([0-9\.]+)/) {
		$iface->{'netmask'} = $1;
		}
	elsif (/^\s*BROADCAST\s*=\s*["']?([0-9\.]+)/) {
		$iface->{'broadcast'} = $1;
		}
	elsif (/^\s*DHCP\s*=\s*["']?([0-9\.]+)/) {
		$iface->{'dhcp'} = ($1 eq "yes");
		}
	elsif (/^\s*ifconfig\s+(\S+)\s+.*IPADDR.*/ && !$gotdevice) {
		$iface->{'name'} = $iface->{'fullname'} = $1;
		}
	}
close(INIT);
local @st1 = stat($rc_init);
local @st2 = stat($dhcp_init);
if ($st1[7] == $st2[7]) {
	# Looks like rc.dhcpd script has been copied to rc.inet1 - assume DHCP
	$iface->{'dhcp'} = 1;
	}
push(@rv, $iface) if ($iface->{'address'} || $iface->{'dhcp'});

# Read extra init script for virtual interfaces
local $lnum = 0;
&open_readfile(IFACES, $interfaces_file);
while(<IFACES>) {
	s/\r|\n//g;
	if (/^(#*)\s*(\S*ifconfig)\s+(\S+)\s+(\S+)(\s+netmask\s+(\S+))?(\s+broadcast\s+(\S+))?(\s+mtu\s+(\d+))?\s+up$/) {
		# Found a usable interface line
		local $b = { 'fullname' => $3,
			     'up' => !$1,
			     'address' => $4,
			     'netmask' => $6,
			     'broadcast' => $8,
			     'mtu' => $10,
			     'edit' => 1,
			     'line' => $lnum,
			     'file' => $interfaces_file,
			     'index' => scalar(@rv) };
		if ($b->{'fullname'} =~ /(\S+):(\d+)/) {
			$b->{'name'} = $1;
			$b->{'virtual'} = $2;
			}
		else {
			$b->{'name'} = $b->{'fullname'};
			}
		push(@rv, $b);
		}
	$lnum++;
	}
close(IFACES);
return @rv;
}

# save_interface(&details)
# Create or update a boot-time interface's ifconfig command
sub save_interface
{
if ($_[0]->{'index'} == 0 && $_[0]->{'fullname'} eq 'eth0') {
	# Modifying the primary interface
	&lock_file($rc_init);
	if ($_[0]->{'dhcp'} && -r $dhcp_init) {
		# Just copy rc.dhcpd to rc.inet1
		&system_logged("cp $dhcp_init $rc_init");
		}
	else {
		# Is the current file rc.dhcpd?
		if (!$_[0]->{'dhcp'}) {
			local @st1 = stat($rc_init);
			local @st2 = stat($dhcp_init);
			if ($st1[7] == $st2[7]) {
				# Yes! Use built-in static IP version
				&system_logged("cp $module_root_directory/rc.inet1 $rc_init");
				}
			}

		# Update init script with new settings
		local $lref = &read_file_lines($rc_init);
		foreach $l (@$lref) {
			if ($l =~ /^(\s*)IPADDR\s*=\s*(\S+)(.*)/) {
				$l = $1."IPADDR=\"".$_[0]->{'address'}."\"".$3;
				}
			elsif ($l =~ /^(\s*)NETMASK\s*=\s*(\S+)(.*)/) {
				$l = $1."NETMASK=\"".$_[0]->{'netmask'}."\"".$3;
				}
			elsif ($l =~ /^(\s*)BROADCAST\s*=\s*(\S+)(.*)/) {
				$l = $1."BROADCAST=\"".$_[0]->{'broadcast'}."\"".$3;
				}
			if ($l =~ /^(\s*)DHCP\s*=\s*(\S+)(.*)/) {
				$l = $1."DHCP=\"".($_[0]->{'dhcp'} ? "yes" : "no")."\"".$3;
				}
			}
		&flush_file_lines();
		}
	&unlock_file($rc_init);
	}
else {
	# Modifying or adding some other interface
	$_[0]->{'dhcp'} && &error($text{'bifc_edhcpmain'});
	&lock_file($interfaces_file);
	local $lref = &read_file_lines($interfaces_file);
	local $lnum = defined($_[0]->{'line'}) ? $_[0]->{'line'}
					       : &interface_lnum($_[0]);
	if (defined($lnum)) {
		$lref->[$lnum] = &interface_line($_[0]);
		}
	else {
		push(@$lref, &interface_line($_[0]));
		}
	&flush_file_lines();
	&unlock_file($interfaces_file);
	}
}

# delete_interface(&details)
# Delete a boot-time interface's ifconfig command
sub delete_interface
{
if ($_[0]->{'init'}) {
	&error("The primary network interface cannot be deleted");
	}
else {
	&lock_file($interfaces_file);
	local $lref = &read_file_lines($interfaces_file);
	local $lnum = defined($_[0]->{'line'}) ? $_[0]->{'line'}
					       : &interface_lnum($_[0]);
	if (defined($lnum)) {
		splice(@$lref, $lnum, 1);
		}
	&flush_file_lines();
	&unlock_file($interfaces_file);
	}
}

sub interface_lnum
{
local @boot = &boot_interfaces();
local ($found) = grep { $_->{'fullname'} eq $_[0]->{'fullname'} } @boot;
return $found ? $found->{'line'} : undef;
}

sub interface_line
{
local $str;
$str .= "# " if (!$_[0]->{'up'});
$str .= &has_command("ifconfig");
if (!$_[0]->{'fullname'}) {
	$_[0]->{'fullname'} = $_[0]->{'virtual'} ne "" ?
		$_[0]->{'name'}.":".$_[0]->{'virtual'} : $_[0]->{'name'};
	}
$str .= " $_[0]->{'fullname'} $_[0]->{'address'}";
if ($_[0]->{'netmask'}) {
	$str .= " netmask $_[0]->{'netmask'}";
	}
if ($_[0]->{'broadcast'}) {
	$str .= " broadcast $_[0]->{'broadcast'}";
	}
if ($_[0]->{'mtu'}) {
	$str .= " mtu $_[0]->{'mtu'}";
	}
$str .= " up";
return $str;
}

# can_edit(what)
# Can some boot-time interface parameter be edited?
sub can_edit
{
return $_[0] ne "bootp";
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
local $hn = &read_file_contents("/etc/HOSTNAME");
$hn =~ s/\r|\n//g;
if ($hn) {
	return $hn;
	}
return &get_system_hostname(1);
}

# save_hostname(name)
sub save_hostname
{
&system_logged("hostname $_[0] >/dev/null 2>&1");
&open_lock_tempfile(HOST, ">/etc/HOSTNAME");
&print_tempfile(HOST, $_[0],"\n");
&close_tempfile(HOST);
undef(@main::get_system_hostname);      # clear cache
}

sub routing_config_files
{
return ( $rc_init );
}

sub routing_input
{
&open_readfile(INIT, $rc_init);
while(<INIT>) {
	s/\r|\n//g;
        s/#.*$//;
	if (/^\s*GATEWAY\s*=\s*["']?([0-9\.]+)/) {
		$gw = $1;
		}
	}
close(INIT);
print &ui_table_row($text{'routes_default'},
	&ui_opt_textbox("gw", $gw, 20, $text{'routes_none'},
			$text{'routes_gateway'}));
}

sub parse_routing
{
local $gw = "";
if (!$in{'gw_def'}) {
	&check_ipaddress($in{'gw'}) ||
		&error(&text('routes_edefault', $in{'gw'}));
	$gw = $in{'gw'};
	}
&lock_file($rc_init);
local $lref = &read_file_lines($rc_init);
foreach $l (@$lref) {
	if ($l =~ /^(\s*)GATEWAY\s*=\s*(\S+)(.*)/) {
		$l = $1."GATEWAY=\"".$gw."\"".$3;
		}
	}
&flush_file_lines();
&unlock_file($rc_init);
}


# supports_address6([&iface])
# Returns 1 if managing IPv6 interfaces is supported
sub supports_address6
{
local ($iface) = @_;
return 0;
}


1;

