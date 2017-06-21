# firewall6-lib.pl
# Functions for parsing ip6tables-save format files
# - help pages

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();

# include common functions for ipv4 and ipv6
require './firewall-lib.pl';

# ipv6 initialization
$config{'perpage'} ||= 50;	# a value of 0 can cause problems
if ($config{'save_file'}) {
	# Force use of a different save file, and webmin's functions
	$ip6tables_save_file = $config{'save_file'};
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
		 '--pid-owner', '--sid-owner', '--state', '--tos', '-j',
		 '--to-ports', '--to-destination', '--to-source',
		 '--reject-with', '--dports', '--sports',
		 '--comment',
		 '--physdev-is-bridged',
		 '--physdev-is-in',
		 '--physdev-is-out',
		 '--physdev-in',
		 '--physdev-out');

# set IP Version
&set_ipvx_version('ipv6');

# IP V6 only functions
# none :-)

# renamed functions
# pass current args to original
sub get_ip6tables_save
{
&get_iptables_save;
}

sub by_string_for_ip6tables
{
&by_string_for_iptables;
}

1;

