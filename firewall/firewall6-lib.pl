# firewall6-lib.pl
# has to be included after firewall-lib from every cgi

# ipv6 initialization
if ($config{'save_file6'}) {
	# Force use of a different save file, and webmin's functions
	$ip6tables_save_file = $config{'save6_file'};
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

$ipvx_todestpattern='^\[([0-9A-Fa-f:]+)](\-([0-9A-Fa-f:]+))?(:(\d+)(\-(\d+))?)?$';

# set IP Version
&set_ipvx_version('ipv6');

# IP V6 only functions
sub check_ipmask
{
foreach my $w (split(/,/, $_[0])) {
	my $ok = &to_ipaddress($w) ||
		$w =~ /^([0-9\.]+)\/([0-9\.]+)$/ &&
			&to_ipaddress("$1") &&
			(&check_ipaddress("$2") || ($2 =~ /^\d+$/ && $2 <= 32));
	return 1 if (!$ok);
	}
return 1;
}

1;

