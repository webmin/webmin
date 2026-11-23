# firewall6-lib.pl
# has to be included after firewall-lib from every cgi

# ipv6 initialization
if ($config{'save_file6'}) {
	# Force use of a different save file, and webmin's functions
	$ip6tables_save_file = $config{'save_file6'};
	}
else {
	if (-r "$module_root_directory/$gconfig{'os_type'}-lib.pl") {
		# Use the operating system's save file and functions
		do "$gconfig{'os_type'}-lib.pl";
		}

	if (!$ip6tables_save_file) {
		# Use webmin's own save file
		$ip6tables_save_file = "$module_config_directory/ip6tables.save";
		}
	}

%access = &get_module_acl();

@known_tables = ( "filter", "mangle", "nat" );
@known_args =   ('-p', '-m', '-s', '-d', '-i', '-o', '-f',
		 '--dport', '--sport', '--tcp-flags', '--tcp-option',
		 '--icmpv6-type', '--mac-source', '--limit', '--limit-burst',
		 '--ports', '--uid-owner', '--gid-owner',
		 '--pid-owner', '--sid-owner', '--state', '--ctstate', '--tos',
		 '-j', '--to-ports', '--to-destination', '--to-source',
		 '--reject-with', '--dports', '--sports',
		 '--comment',
		 '--physdev-is-bridged',
		 '--physdev-is-in',
		 '--physdev-is-out',
		 '--physdev-in',
		 '--physdev-out');

@ipvx_rtypes = ( "icmp6-no-route", "icmp6-adm-prohibited",
		  "icmp6-addr-unreachable", "icmp6-port-unreachable",
		  "echo-reply", "tcp-reset" );

$ipvx_todestpattern='^\[([0-9A-Fa-f:]+)\](\-([0-9A-Fa-f:]+))?(:(\d+)(\-(\d+))?)?$';

# set IP Version
&set_ipvx_version('ipv6');

# check_ipmask(addresses)
# Returns 1 if every address in the list is an IPv6 address or hostname,
# optionally followed by a prefix length or mask, or 0 if not.
sub check_ipmask
{
foreach my $w (split(/[ \t\r\n,]+/, $_[0])) {
	my ($addr, $mask) = split(/\//, $w, 2);
	return 0 if (!&to_ip6address($addr));
	return 0 if (defined($mask) &&
		     !($mask =~ /^\d+\z/ && $mask <= 128) &&
		     !($mask =~ /^[0-9a-f]*:[0-9a-f:]*\z/i && &check_ip6address($mask)));
	}
return 1;
}

# check_ipvx_ipaddress(ipv6)
# Validates an IPv6 address
sub check_ipvx_ipaddress
{
return &check_ip6address(@_);
}

1;

