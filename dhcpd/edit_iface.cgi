#!/usr/local/bin/perl
# edit_ifaces.cgi
# Display network interfaces on which the DHCP server is started

require './dhcpd-lib.pl';
%access = &get_module_acl();
$access{'noconfig'} && &error($text{'iface_ecannot'});

# Get the interface
if ($config{'interfaces_type'} eq 'mandrake') {
	if (-r "/etc/conf.linuxconf") {
		# Older mandrake's init script uses a linuxconf setting
		open(FILE, "/etc/conf.linuxconf");
		while(<FILE>) {
			if (/DHCP.interface\s+(.*)/) {
				$iface = $1;
				}
			}
		close(FILE);
		}
	else {
		# Newer use Redhat-style sysconfig file
		&read_env_file("/etc/sysconfig/dhcpd", \%dhcpd);
		$iface = $dhcpd{'INTERFACES'};
		}
	}
elsif ($config{'interfaces_type'} eq 'redhat') {
	# Redhat's init script uses an environment file
	&read_env_file("/etc/sysconfig/dhcpd", \%dhcpd);
	$iface = $dhcpd{'DHCPDARGS'};
	}
elsif ($config{'interfaces_type'} eq 'suse') {
	# SuSE and United use an environment file too
	&read_env_file("/etc/sysconfig/dhcpd", \%dhcpd);
	$iface = $dhcpd{'DHCPD_INTERFACE'};
	}
elsif ($config{'interfaces_type'} eq 'debian') {
	if (-r "/etc/default/isc-dhcp-server") {
		# Debian 6+ uses a new environment file
		&read_env_file("/etc/default/isc-dhcp-server", \%dhcpd);
		$iface = $dhcpd{'INTERFACES'};
		}
	elsif (-r "/etc/default/dhcp") {
		# New debian uses an environment file
		&read_env_file("/etc/default/dhcp", \%dhcpd);
		$iface = $dhcpd{'INTERFACES'};
		}
	elsif (-r "/etc/default/dhcp3-server") {
		# DHCPd 3 uses a different environment file
		&read_env_file("/etc/default/dhcp3-server", \%dhcpd);
		$iface = $dhcpd{'INTERFACES'};
		}
	else {
		# Old debian has the interface set in the init script!
		$lref = &read_file_lines("/etc/init.d/dhcp");
		for($i=0; $i<@$lref; $i++) {
			if ($lref->[$i] =~ /INTERFACES\s*=\s*'([^']+)'/ ||
			    $lref->[$i] =~ /INTERFACES\s*=\s*"([^"]+)"/ ||
			    $lref->[$i] =~ /INTERFACES\s*=\s*(\S+)/) {
				$iface = $1;
				}
			}
		}
	}
elsif ($config{'interfaces_type'} eq 'caldera') {
	# Interfaces are set in the Caldera daemons directory file
	&read_env_file("/etc/sysconfig/daemons/dhcpd", \%dhcpd);
	@iface = grep { /^(lo|[a-z]+\d+)$/ } split(/\s+/, $dhcpd{'OPTIONS'});
	$iface = join(" ", @iface);
	}
elsif ($config{'interfaces_type'} eq 'gentoo') {
	# Interfaces are set in a file on Gentoo
	&read_env_file("/etc/conf.d/dhcp", \%dhcp);
	$iface = $dhcp{'IFACE'};
	}
elsif ($config{'interfaces_type'} eq 'freebsd') {
	# From FreeBSD rc.conf file
	&foreign_require("init");
	my $rcconf = &init::get_rc_conf();
	my ($c) = grep { $_->{'name'} eq 'dhcpd_ifaces' } @$rcconf;
	if ($c) {
		$iface = $c->{'value'};
		}
	}
else {
	# Just use the configuration
	$iface = $config{'interfaces'};
	}

&ui_print_header(undef, $text{'iface_title'}, "");
print "$text{'iface_desc'}<p>\n";
print &ui_form_start("save_iface.cgi", "post");
print &ui_table_start(undef, undef, 2);
my $val;
if (&foreign_check("net")) {
	%got = map { $_, 1 } split(/\s+/, $iface);
	&foreign_require("net", "net-lib.pl");
	@ifaces = grep { $_->{'virtual'} eq '' } &net::active_interfaces();
	$sz = scalar(@ifaces);
    my @iface_sel;
	foreach $i (@ifaces) {
		$n = $i->{'fullname'};
        push(@iface_sel,[$n,$n." (".&net::iface_type($n).")", ($got{$n} ? 'selected' : '') ]);
		}
    $val = &ui_select("iface",undef,\@iface_sel,$sz,1);
	}
else {
    $val = &ui_textbox("iface",$iface,30);
	}
print &ui_table_row($text{'iface_listen'}, $val);
print &ui_table_end();
print &ui_submit($text{'save'});
print &ui_form_end(undef,undef,1);

&ui_print_footer("", $text{'listl_return'});

