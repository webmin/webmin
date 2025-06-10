# debians-linux-lib.pl
# Deal with debian's iptables save file and startup script

&foreign_require("init");

if ($gconfig{'os_version'} >= 3.1 &&
    !-r "/etc/init.d/ip${ipvx}tables" &&
    !-r "/etc/init.d/webmin-ip${ipvx}tables" &&
    !$config{'force_init'} &&
    !-d "/etc/netplan" &&
    !-d "/etc/iptables") {
	# In newer Debians, IPtable is started by the network init script, 
	# unless netplan is in use
	$has_new_debian_iptables = 1;
	$ip6tables_save_file = "/etc/ip6tables.up.rules";
	$iptables_save_file = "/etc/iptables.up.rules";
	$debian_init_script = "ip${ipvx}tables";
	}
elsif (-d "/etc/iptables") {
	# Ubuntu 20 uses files in /etc/iptables if iptables-persistent is
	# installed. However, on Debian 10 there is no init script!
	$ip6tables_save_file = "/etc/iptables/rules.v6";
	$iptables_save_file = "/etc/iptables/rules.v4";
	$debian_init_script = $ipvx == 4 ? "iptables" : "ip6tables";
	}
else {
	# Older Debians use an init script
	$has_debian_iptables = -r "/etc/init.d/iptables";
	$debian_ip6tables_dir = "/var/lib/ip6tables";
	$debian_iptables_dir = "/var/lib/iptables";
	if ($has_debian_iptables) {
		$debian_init_script = "iptables";
		mkdir($debian_ip6tables_dir, 0755) if (!-d $debian_ip6tables_dir);
		mkdir($debian_iptables_dir, 0755) if (!-d $debian_iptables_dir);
		$iptables_save_file = "$debian_iptables_dir/active";
		$ip6tables_save_file = "$debian_ip6tables_dir/active";
		}
	}

if (!&init::action_status($debian_init_script)) {
	# Expected script doesn't exist!
	$debian_init_script = undef;
	}

# apply_iptables()
# Applies the current iptables configuration from the save file
sub apply_iptables
{
if ($debian_init_script && &init::action_status($debian_init_script)) {
	my ($ok, $err) = &init::restart_action($debian_init_script);
	return $ok ? undef : &html_escape($err);
	}
else {
	return &iptables_restore();
	}
}

# unapply_iptables()
# Writes the current iptables configuration to the save file
sub unapply_iptables
{
if ($has_debian_iptables) {
	# On some debian versions the init script can do this
	$out = &backquote_logged("cd / ; /etc/init.d/ip${ipvx}tables save active 2>&1 </dev/null");
	return $? ? "<pre>$out</pre>" : undef;
	}
else {
	return &iptables_save();
	}
}

# started_at_boot()
sub started_at_boot
{
if ($debian_init_script) {
	# Check Debian init script
	return &init::action_status($debian_init_script) == 2;
	}
elsif ($has_new_debian_iptables) {
	# Check network interface config
	local $pri = &get_primary_network_interface();
	local ($debpri) = grep { $_->[0] eq $pri->{'fullname'} }
			       &net::get_interface_defs();
	foreach my $o (@{$debpri->[3]}) {
		if (($o->[0] eq "pre-up" || $o->[0] eq "post-up") &&
		    $o->[1] =~ /\S*ip${ipvx}tables-restore\s+<\s+(\S+)/ &&
		    $1 eq $ipvx_save) {
			return 1;
			}
		}
	}
else {
	# Check Webmin init script
	return &init::action_status("webmin-ip${ipvx}tables") == 2;
	}
}

sub enable_at_boot
{
if ($debian_init_script) {
	# Enable the init script (assumes it exists)
	&init::action_status($debian_init_script) > 0 ||
		&error("Bootup action $debian_init_script does not exist");
	&init::enable_at_boot($debian_init_script);
	}
elsif ($has_new_debian_iptables) {
	# Add to network interface config
	local $pri = &get_primary_network_interface();
	local ($debpri) = grep { $_->[0] eq $pri->{'fullname'} }
			       &net::get_interface_defs();
	if ($debpri && !&started_at_boot()) {
		my ($name, $addrfam, $method, $options, $file,$line) = @$debpri;
		push(@$options,
		     [ "post-up", "ip${ipvx}tables-restore < $ipvx_save" ]);
		&net::modify_interface_def($name, $addrfam, $method, $options,
					   0, $file);
		}
	}
else {
	&create_webmin_init();
	}
}

sub disable_at_boot
{
if ($debian_init_script) {
	# Turn off the init script
	&init::disable_at_boot($debian_init_script);
	}
elsif ($has_new_debian_iptables) {
	# Remove from network interface config
	local $pri = &get_primary_network_interface();
	local ($debpri) = grep { $_->[0] eq $pri->{'fullname'} }
			       &net::get_interface_defs();
	@{$debpri->[3]} = grep {
			($_->[0] ne "pre-up" && $_->[0] ne "post-up") ||
			 $_->[1] !~ /^\S*ip${ipvx}tables/ } @{$debpri->[3]};
	&net::modify_interface_def(@$debpri);
	}
else {
	&init::disable_at_boot("webmin-ip${ipvx}tables");
	}
}

sub get_primary_network_interface
{
&foreign_require("net");
local @boot = sort { $a->{'fullname'} cmp $b->{'fullname'} }
		   &net::boot_interfaces();
local $pri;
if ($config{'iface'}) {
	($pri) = grep { $_->{'fullname'} eq $config{'iface'} } @boot;
	}
local ($eth) = grep { $_->{'fullname'} =~ /^eth\d+$/ } @boot;
local ($ppp) = grep { $_->{'fullname'} =~ /^ppp\d+$/ } @boot;
local ($venetn) = grep { $_->{'fullname'} =~ /^venet\d+:\d+$/ } @boot;
local ($venet) = grep { $_->{'fullname'} =~ /^venet\d+$/ } @boot;
return $pri || $eth || $ppp || $venetn || $venet || $boot[0];
}

1;

