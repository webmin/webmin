#!/usr/local/bin/perl
# save_ifaces.cgi
# Save network interfaces on which the DHCP server is started

require './dhcpd-lib.pl';
%access = &get_module_acl();
$access{'noconfig'} && &error($text{'iface_ecannot'});
&ReadParse();

# Save in config file
@iface = split(/\s+|\0/, $in{'iface'});
@iface || &error($text{'iface_enone'});
$iface = join(" ", @iface);
$config{'interfaces'} = join(" ", @iface);
&write_file("$module_config_directory/config", \%config);

if ($config{'interfaces_type'} eq 'mandrake') {
	if (-r "/etc/conf.linuxconf") {
		# Write to Mandrake linuxconf file
		local $lref = &read_file_lines("/etc/conf.linuxconf");
		for($i=0; $i<@$lref; $i++) {
			$secline = $i if ($lref->[$i] =~ /\[dhcpd\]/);
			$ifaceline = $i if ($lref->[$i] =~ /DHCP.interface/);
			}
		$line = "DHCP.interface $iface";
		if (defined($ifaceline)) {
			$lref->[$ifaceline] = $line;
			}
		elsif (defined($secline)) {
			splice(@$lref, $secline+1, 0, $line);
			}
		else {
			push(@$lref, "[dhcpd]", $line);
			}
		&flush_file_lines();
		}
	else {
		# Write to sysconfig file
		&read_env_file("/etc/sysconfig/dhcpd", \%dhcpd);
		$dhcpd{'INTERFACES'} = $iface;
		&write_env_file("/etc/sysconfig/dhcpd", \%dhcpd);
		}
	}
elsif ($config{'interfaces_type'} eq 'redhat') {
	# Write to the Redhat environment file
	&read_env_file("/etc/sysconfig/dhcpd", \%dhcpd);
	$dhcpd{'DHCPDARGS'} = $iface;
	&write_env_file("/etc/sysconfig/dhcpd", \%dhcpd);
	}
elsif ($config{'interfaces_type'} eq 'suse') {
	# Write to the SuSE/United environment file
	&read_env_file("/etc/sysconfig/dhcpd", \%dhcpd);
	$dhcpd{'DHCPD_INTERFACE'} = $iface;
	&write_env_file("/etc/sysconfig/dhcpd", \%dhcpd);
	}
elsif ($config{'interfaces_type'} eq 'debian') {
	if (-r "/etc/default/isc-dhcp-server") {
		# Write to Debian 6.0 environment file
		&read_env_file("/etc/default/isc-dhcp-server", \%dhcpd);
		$dhcpd{'INTERFACES'} = $iface;
		&write_env_file("/etc/default/isc-dhcp-server", \%dhcpd);
		}
	elsif (-r "/etc/default/dhcp") {
		# Write to Debian environment file
		&read_env_file("/etc/default/dhcp", \%dhcpd);
		$dhcpd{'INTERFACES'} = $iface;
		&write_env_file("/etc/default/dhcp", \%dhcpd);
		}
	elsif (-r "/etc/default/dhcp3-server") {
		# Write to Debian DHCPd 3 environment file
		&read_env_file("/etc/default/dhcp3-server", \%dhcpd);
		$dhcpd{'INTERFACES'} = $iface;
		&write_env_file("/etc/default/dhcp3-server", \%dhcpd);
		}
	else {
		# Write to the debian init script
		$lref = &read_file_lines("/etc/init.d/dhcp");
		for($i=0; $i<@$lref; $i++) {
			if ($lref->[$i] =~ /INTERFACES\s*=\s*'([^']+)'/ ||
			    $lref->[$i] =~ /INTERFACES\s*=\s*"([^"]+)"/ ||
			    $lref->[$i] =~ /INTERFACES\s*=\s*(\S+)/) {
				$lref->[$i] = "INTERFACES=\"$iface\"";
				}
			}
		&flush_file_lines("/etc/init.d/dhcp");
		}
	}
elsif ($config{'interfaces_type'} eq 'caldera') {
	# Interfaces are set in the Caldera daemons directory file
	&read_env_file("/etc/sysconfig/daemons/dhcpd", \%dhcpd);
	@other = grep { !/^(lo|[a-z]+\d+)$/ } split(/\s+/, $dhcpd{'OPTIONS'});
	$dhcpd{'OPTIONS'} = join(" ", @other).($iface ? " $iface" : "");
	&write_env_file("/etc/sysconfig/daemons/dhcpd", \%dhcpd);
	}
elsif ($config{'interfaces_type'} eq 'gentoo') {
	# Interfaces are set in a file on Gentoo
	&read_env_file("/etc/conf.d/dhcp", \%dhcp);
	$dhcp{'IFACE'} = $iface;
	&write_env_file("/etc/conf.d/dhcp", \%dhcp);
	}
elsif ($config{'interfaces_type'} eq 'freebsd') {
	# Update FreeBSD rc.conf file
	&foreign_require("init");
	&init::save_rc_conf('dhcpd_ifaces', $iface);
	}

&redirect("");

