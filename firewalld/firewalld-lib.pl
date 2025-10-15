# Functions for managing firewalld

BEGIN { push(@INC, ".."); };
use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
use WebminCore;
&init_config();
do 'md5-lib.pl';
our ($module_root_directory, %text, %config, %gconfig);
our %access = &get_module_acl();

# check_firewalld()
# Returns an error message if firewalld is not installed, undef if all is OK
sub check_firewalld
{
&has_command($config{'firewall_cmd'}) ||
	return &text('check_ecmd', "<tt>".$config{'firewall_cmd'}."</tt>");
return undef;
}

# get_config_files()
# Returns a list of all firewalld config files
sub get_config_files
{
my $conf_dir = $config{'config_dir'} || '/etc/firewalld';
return (glob("$conf_dir/*.xml"), glob("$conf_dir/*/*.xml"));
}

# check_ip_family()
# Determines which IP families are enabled and functional on the system
#
# Returns:
#   Hash with 'ipv4' and 'ipv6' keys set to 1 if enabled, 0 if disabled, -1 if unknown
sub check_ip_family
{
my %result = ( ipv4 => 0, ipv6 => 0 );

# Attempt to load IO::Socket::IP at runtime
eval {
	require IO::Socket::IP;
		IO::Socket::IP->import();
		1;
	};

# Return on error (must never happen on contemporary systems)
if ($@) {
	$result{ipv4} = -1; # unknown
	$result{ipv6} = -1; # unknown
	return %result;
	}

# Check IPv4
eval {
	my $sock4 = IO::Socket::IP->new(
		LocalHost => '127.0.0.1',
		LocalPort => 0,  # ephemeral port
		Proto     => 'tcp');
	$result{ipv4} = 1 if $sock4;
	};

# Check IPv6
eval {
	my $sock6 = IO::Socket::IP->new(
		LocalHost => '::1',
		LocalPort => 0,  # ephemeral port
		Proto     => 'tcp' );
	$result{ipv6} = 1 if $sock6;
	};

return %result;
}

# is_firewalld_running()
# Returns 1 if the server is running, 0 if not
sub is_firewalld_running
{
my $ex = system("$config{'firewall_cmd'} --state >/dev/null 2>&1 </dev/null");
return $ex ? 0 : 1;
}

# list_firewalld_zones([active-only])
# Returns an array of firewalld zones, each of which is a hash ref with fields
# like services and ports
sub list_firewalld_zones
{
my ($active) = @_;
my @rv;
my $out = &backquote_command("$config{'firewall_cmd'} --list-all-zones ".
			     ($active ? "" : "--permanent ")."</dev/null 2>&1");
if ($?) {
	&error("Failed to list zones : $out");
	}
my $default_zone = backquote_command(
	"$config{'firewall_cmd'} --get-default-zone </dev/null 2>&1");
chomp($default_zone);
my $zone;
my $lo;
foreach my $l (split(/\r?\n/, $out)) {
	if ($l =~ /^(\S+)(\s+\(.*\))?/) {
		# New zone
		$zone = { 'name' => $1,
			  'default' => $default_zone eq $1 ? 1 : 0 };
		$lo = undef;
		push(@rv, $zone);
		}
	elsif ($l =~ /^  (\S+):\s*(.*)/ && $zone) {
		# Option in some zone
		$lo = $1;
		$zone->{$1} = [ split(/\s+/, $2) ];
		}
	elsif ($l =~ /^\t(\S.*)/ && $zone && $lo) {
		# Continued option
		push(@{$zone->{$lo}}, split(/\s+/, $1));
		}
	}
return @rv;
}

# list_firewalld_services()
# Returns an array of known service names
sub list_firewalld_services
{
my $out = &backquote_command("$config{'firewall_cmd'} --get-services </dev/null 2>&1");
if ($?) {
	&error("Failed to list services : $out");
	}
$out =~ s/\r|\n//g;
return split(/\s+/, $out);
}

# list_firewalld_service_desc(service)
# Returns a hashref of ports and protocols 
# for in-built FirewallD service
sub list_firewalld_service_desc
{
my ($service) = @_;
$service =~ s/[^A-Za-z0-9\-]//g;
# This is native way but too slow
# my $out = &backquote_command("$config{'firewall_cmd'} --service=".quotemeta($service)." --get-ports --permanent </dev/null 2>&1");

# Check for file in directory containing all services as xml files
my @ports;
my @protos;
foreach my $services_dir ("/etc/firewalld/services",
			  "/usr/lib/firewalld/services") {
	my $service_file = "$services_dir/$service.xml";
	if (-r $service_file) {
		my $lref = &read_file_lines($service_file, 1);
		foreach my $l (@{$lref}) {
			if ($l =~ /<port\s+protocol=["'](?<proto>\S+)["']\s+port=["'](?<port>[\d-]+)["']\/>/) {
				my $port = "$+{port}";
				my $proto = "$+{proto}";
				push(@ports, $port) if ($port);
				push(@protos, $proto) if ($port && $proto);
				}
			}
		last if (@ports);
		}
	}
@ports = &unique(@ports);
@protos = &unique(@protos);
return {'ports' => join(", ", @ports), 'protocols' => uc(join('/', @protos))};
}

# list_firewalld_services_with_ports()
# Returns an array of service names and descriptions
sub list_firewalld_services_with_ports
{
my @rv;
foreach my $s (&list_firewalld_services()) {
	my @n = getservbyname($s, "tcp");
	if (!@n) {
		@n = getservbyname($s, "udp");
		}
	if (@n) {
		push(@rv, [ $s, $s." (".$n[2]." ".uc($n[3]).")" ]);
		}
	else {
		my $sportsprotos = &list_firewalld_service_desc($s);
		my $sports = $sportsprotos->{'ports'};
		my $sprotocols = $sportsprotos->{'protocols'};
		my $sdesc;
		$sdesc = " ($sports $sprotocols)" if ($sports);
		push(@rv, [ $s, "$s$sdesc" ]);
		}
	}
return @rv;
}

# create_firewalld_port(&zone, port|range, proto)
# Adds a new allowed port to a zone. Returns undef on success or an error
# message on failure
sub create_firewalld_port
{
my ($zone, $port, $proto) = @_;
my $out = &backquote_logged("$config{'firewall_cmd'} ".
			    "--zone ".quotemeta($zone->{'name'})." ".
			    "--permanent --add-port ".
			    quotemeta($port)."/".quotemeta($proto)." 2>&1");
return $? ? $out : undef;
}

# delete_firewalld_port(&zone, port|range, proto)
# Delete one existing port from a zone. Returns undef on success or an error
# message on failure
sub delete_firewalld_port
{
my ($zone, $port, $proto) = @_;
my $out = &backquote_logged("$config{'firewall_cmd'} ".
			    "--zone ".quotemeta($zone->{'name'})." ".
			    "--permanent --remove-port ".
			    quotemeta($port)."/".quotemeta($proto)." 2>&1");
return $? ? $out : undef;
}

# create_firewalld_service(&zone, service)
# Adds a new allowed service to a zone. Returns undef on success or an error
# message on failure
sub create_firewalld_service
{
my ($zone, $service) = @_;
my $out = &backquote_logged("$config{'firewall_cmd'} ".
			    "--zone ".quotemeta($zone->{'name'})." ".
			    "--permanent --add-service ".
			    quotemeta($service)." 2>&1");
return $? ? $out : undef;
}

# delete_firewalld_service(&zone, service)
# Delete one existing service from a zone. Returns undef on success or an error
# message on failure
sub delete_firewalld_service
{
my ($zone, $service) = @_;
my $out = &backquote_logged("$config{'firewall_cmd'} ".
			    "--zone ".quotemeta($zone->{'name'})." ".
			    "--permanent --remove-service ".
			    quotemeta($service)." 2>&1");
return $? ? $out : undef;
}

# create_firewalld_forward(&zone, src-port, src-proto, dst-port, dst-addr)
# Create a new forwarding rule in some zone. Returns undef on success or an
# error message on failure
sub create_firewalld_forward
{
my ($zone, $srcport, $srcproto, $dstport, $dstaddr) = @_;
my $out = &backquote_logged(
	$config{'firewall_cmd'}." ".
	"--zone ".quotemeta($zone->{'name'})." ".
	"--permanent ".
	"--add-forward-port=port=$srcport:proto=$srcproto".
	($dstport ? ":toport=$dstport" : "").
	($dstaddr ? ":toaddr=$dstaddr" : "").
	" 2>&1");
return $? ? $out : undef;
}

# delete_firewalld_forward(&zone, src-port, src-proto, dst-port, dst-addr)
# Deletes a forwarding rule in some zone. Returns undef on success or an
# error message on failure
sub delete_firewalld_forward
{
my ($zone, $srcport, $srcproto, $dstport, $dstaddr) = @_;
my $out = &backquote_logged(
	$config{'firewall_cmd'}." ".
	"--zone ".quotemeta($zone->{'name'})." ".
	"--permanent ".
	"--remove-forward-port=port=$srcport:proto=$srcproto".
	($dstport ? ":toport=$dstport" : "").
	($dstaddr ? ":toaddr=$dstaddr" : "").
	" 2>&1");
return $? ? $out : undef;
}

# parse_firewalld_forward(str)
# Parses a forward string into port, proto, dstport and dstaddr
sub parse_firewalld_forward
{
my ($str) = @_;
my %w = map { split(/=/, $_, 2) } split(/:/, $str);
return ($w{'port'}, $w{'proto'}, $w{'toport'}, $w{'toaddr'});
}

# apply_firewalld()
# Make the current saved config active
sub apply_firewalld
{
&foreign_require("init");
my ($ok, $err) = &init::restart_action($config{'init_name'});
&restart_firewalld_dependent();
return $ok ? undef : $err;
}

# stop_firewalld()
# Shut down the firewalld service
sub stop_firewalld
{
&foreign_require("init");
my ($ok, $err) = &init::stop_action($config{'init_name'});
return $ok ? undef : $err;
}

# start_firewalld()
# Shut down the firewalld service
sub start_firewalld
{
&foreign_require("init");
my ($ok, $err) = &init::start_action($config{'init_name'});
&restart_firewalld_dependent();
return $ok ? undef : $err;
}

# restart_firewalld_dependent()
# Restarts dependent services
sub restart_firewalld_dependent
{
if (&foreign_exists("fail2ban")) {
	&foreign_require("fail2ban");
	if (&fail2ban::is_fail2ban_running()) {
		my $err = &fail2ban::restart_fail2ban_server(1);
		&error(&text('index_dependent', 'fail2ban'))
			if ($err);
		}
	}
}

# list_system_interfaces()
# Returns the list of all interfaces on the system
sub list_system_interfaces
{
&foreign_require("net");
my @rv = map { $_->{'name'} } &net::active_interfaces();
push(@rv, map { $_->{'name'} } &net::boot_interfaces());
return &unique(@rv);
}

# update_zone_interfaces(&zone, &interface-list)
# Update the interfaces a zone applies to
sub update_zone_interfaces
{
my ($zone, $newifaces) = @_;
my $oldifaces = $zone->{'interfaces'};
foreach my $i (&list_system_interfaces()) {
	my $inold = &indexof($i, @$oldifaces) >= 0;
	my $innew = &indexof($i, @$newifaces) >= 0;
	my $args;
	if ($inold && !$innew) {
		# Remove from this zone
		$args = "--remove-interface ".quotemeta($i);
		}
	elsif (!$inold && $innew) {
		# Add to from this zone
		$args = "--add-interface ".quotemeta($i);
		}
	else {
		next;
		}
	my $cmd = "$config{'firewall_cmd'} ".
		  "--zone ".quotemeta($zone->{'name'})." ".
		  "--permanent ".$args;
	my $out = &backquote_logged($cmd." 2>&1 </dev/null");
	return $out if ($?);
	}
return undef;
}

# create_firewalld_zone(name)
# Add a new zone with the given name
sub create_firewalld_zone
{
my ($name) = @_;
my $cmd = "$config{'firewall_cmd'} --permanent --new-zone ".quotemeta($name);
my $out = &backquote_logged($cmd." 2>&1 </dev/null");
return $? ? $out : undef;
}

# delete_firewalld_zone(&zone)
# Removes the specified zone
sub delete_firewalld_zone
{
my ($zone) = @_;
my $cmd = "$config{'firewall_cmd'} --permanent --delete-zone ".
	  quotemeta($zone->{'name'});
my $out = &backquote_logged($cmd." 2>&1 </dev/null");
return $? ? $out : undef;
}

# default_firewalld_zone(&zone)
# Makes the specified zone the default
sub default_firewalld_zone
{
my ($zone) = @_;
my $cmd = "$config{'firewall_cmd'} --set-default-zone ".
	  quotemeta($zone->{'name'});
my $out = &backquote_logged($cmd." 2>&1 </dev/null");
return $? ? $out : undef;
}

# parse_port_field(&in, name)
# Either returns a port expression, or calls error
sub parse_port_field
{
my ($in, $pfx) = @_;
if ($in->{$pfx.'mode'} == 0) {
	$in->{$pfx.'port'} =~ /^\d+$/ &&
	  $in->{$pfx.'port'} > 0 && $in->{$pfx.'port'} < 65536 ||
	  getservbyname($in->{$pfx.'port'}, $in->{'proto'}) ||
	     &error($text{'port_eport'});
	return $in->{$pfx.'port'};
	}
elsif ($in->{$pfx.'mode'} == 1) {
	$in->{$pfx.'portlow'} =~ /^\d+$/ &&
	  $in->{$pfx.'portlow'} > 0 && $in->{$pfx.'portlow'} < 65536 ||
	     &error($text{'port_eportlow'});
	$in->{$pfx.'porthigh'} =~ /^\d+$/ &&
	  $in->{$pfx.'porthigh'} > 0 && $in->{$pfx.'porthigh'} < 65536 ||
	     &error($text{'port_eporthigh'});
	$in->{$pfx.'portlow'} < $in->{$pfx.'porthigh'} ||
	     &error($text{'port_eportrange'});
	return $in->{$pfx.'portlow'}."-".$in->{$pfx.'porthigh'};
	}
else {
	# No port chosen
	return undef;
	}
}

# get_default_zone
# Returns default zone
sub get_default_zone
{
my @zones = &list_firewalld_zones();
my ($zone) = grep { $_->{'default'} } @zones;
return $zone;
}

# construct_rich_rule([@opts])
# Constructs rich firewalld rule and returns it as string
#
# Parameters:
#   @opts - Array of key-value pairs defining the rule properties
# 
# Example:
#   &construct_rich_rule(
#       'source address' => '0.0.0.0/0',
#       'log prefix' => 'BANDWIDTH_IN ',
#       'level' => 'info',
#       'action' => 'accept',
#   );
# 
# Returns:
#   A string representing the rich rule
sub construct_rich_rule
{
my (@opts) = @_;
my %opts = @opts;

# Action type
my $action_type = $config{'packet_handling'} eq '1' ? 'reject' : 'drop';
my $opts_action = delete($opts{'action'});
if ($opts_action) {
	$action_type = lc($opts_action)
		if ($opts_action &&
		    $opts_action =~ /^accept|reject|drop|mark$/);
	}

# Set family
my $family = delete($opts{'family'}) || 'ipv4';

# Validate IP addresses, and update family if needed
foreach my $ip_key ('source address', 'destination address') {
	if (my $full_ip = $opts{$ip_key}) {
		# Split IP and CIDR, if present
		my ($ip_only, $cidr) = split(/\//, $full_ip);

		# Validate the IP portion
		&check_ipaddress($ip_only) || &check_ip6address($ip_only) ||
			&error("$text{'list_rule_iperr'} : $ip_only");

		# Decide family based on presence of ':' in IP portion
		$family = $ip_only =~ /:/ ? 'ipv6' : 'ipv4';

		# If you still want to test or store the CIDR, do it here
		if (defined($cidr)) {
			# Make sure CIDR is numeric and within range
			$cidr =~ /^\d+$/ && $cidr <= ($family eq 'ipv6' ? 128 : 32) ||
				&error("$text{'save_rule_cidrerr'} : /$cidr");
			}
		}
	}

# Construct rule from given options
my $rule = "rule family=\"".quotemeta($family)."\"";

# Extended options handling for dynamic rules
foreach my $key (@opts) { # Iterate over all keys in given order
	next if (!defined($opts{$key}));
	# Keys cannot be quotemeta'd
	$key =~ tr/A-Za-z0-9\-\_\/ //cd;
	# Values can be quotemeta'd
	my $val = $opts{$key};
	$val =~ tr/A-Za-z0-9\-\_\=\'\:\.\,\/ //cd;
	$rule .= " $key=\"$val\"";
	}
$rule .= " ".quotemeta($action_type);
return $rule;
}

# rich_rule(action, [@opts])
# Adds or removes a rich firewalld rule with specified options and rich rule
# passed as string
#
# Parameters:
#   action - Required. Must be either 'add' or 'remove'
#   @opts  - Array of key-value pairs defining the rule properties
# 
# Example:
#   &rich_rule('add', {
#       'zone' => 'public',
#       'rule' => &construct_rich_rule('source address' => '0.0.0.0/0'),
#       'permanent' => 1,
#   });
# 
# Returns:
#   undef on success, or (error_message, error_code) on failure in list context
sub rich_rule
{
my ($action, $opts) = @_;

# Validate action
$action eq 'add' || $action eq 'remove' || &error($text{'list_rule_actionerr'});

# Zone name
my $zone = $opts->{'zone'};
if (!$zone) {
	($zone) = get_default_zone();
	$zone = $zone->{'name'};
	}

# Timeout
my $timeout = $opts->{'timeout'};
if ($timeout) {
	# Validate timeout format
	&error(&text('config_timeout_err', $timeout))
		if ($timeout !~ /^(\d+)([smhd]?)$/);
	}

# Permanent rule
my $permanent = $opts->{'permanent'};

# Add/remove rich rule
my $get_cmd = sub {
	my ($rtype) = @_;
	my $type = $rtype ? " --permanent" : "";
	return "$config{'firewall_cmd'} --zone=\"".quotemeta($zone)."\"".
	       "$type --".quotemeta($action)."-rich-rule='$opts->{'rule'}'".
	       ($timeout ? " --timeout=".quotemeta($timeout) : "");
	};

for my $type (0..1) {
	next if ($type == 1 && !$permanent);
	my $cmd = &$get_cmd($type);
	my $out = &backquote_logged($cmd." 2>&1 </dev/null");
	return wantarray ? ($out, $?) : $out if ($?);
	}
return undef;
}

# check_rich_rule(rule, [&zone])
# Check if a rich rule exists in the given or default zone
sub check_rich_rule
{
my ($rule, $zone) = @_;

# Zone name
if (!$zone) {
	($zone) = get_default_zone();
	$zone = $zone->{'name'};
	}

# Command to query rules
my $cmd = "$config{'firewall_cmd'} --zone=".quotemeta($zone)." --list-rich-rules";
my $out = &backquote_logged($cmd." 2>&1 </dev/null");

# Check for rule existence
return ($out =~ /\Q$rule\E/);
}

# add_rich_rule(rule, [&zone])
# Add rich rule in given or default zone using raw rule string
sub add_rich_rule
{
my ($rule, $zone) = @_;
return &rich_rule('add',
	{ 'zone' => $zone->{'name'}, 'permanent' => 1, 'rule' => $rule });
}

# remove_rich_rule(rule, [&zone])
# Remove rich rule in given or default zone using raw rule string
sub remove_rich_rule
{
my ($rule, $zone) = @_;
return &rich_rule('remove',
	{ 'zone' => $zone->{'name'}, 'permanent' => 1, 'rule' => $rule });
}

# construct_direct_rule(&opts)
# Constructs a direct Firewalld rule string
#
# Opts can include:
#   'family'   => 'ipv4' | 'ipv6' | 'eb'  (default = 'ipv4')
#   'table'    => 'filter' | 'nat' | 'mangle' | 'raw' |
#                 'security' (default = 'filter')
#   'chain'    => 'INPUT' | 'OUTPUT' | 'FORWARD' |
#                 'PREROUTING' | 'POSTROUTING' (default = 'INPUT')
#   'priority' => integer priority (default = 0)
#   'rule'     => string containing iptables-like match/target
#
# Returns:
#   A string representing the direct rule is returned
#
sub construct_direct_rule
{
my ($opts) = @_;

# Defaults
my $family   = $opts->{'family'}   || 'ipv4';
my $table    = $opts->{'table'}    || 'filter';
my $chain    = $opts->{'chain'}    || 'INPUT';
my $priority = $opts->{'priority'} // 0;
my $rule     = $opts->{'rule'}     || '';

# Basic validation
$family =~ /^(ipv4|ipv6|eb)$/ ||
	&error(&text('save_rule_efamily', $family));

$table =~ /^(filter|nat|mangle|raw|security)$/ ||
	&error(&text('save_rule_etable', $table));

$chain =~ /^(INPUT|OUTPUT|FORWARD|PREROUTING|POSTROUTING)$/ ||
	&error(&text('save_rule_echain', $chain));

# Priority must be integer
$priority =~ /^\d+$/ || &error(&text('save_rule_epriority', $priority));

# If still empty after parsing, throw an error
$rule !~ /^\s*$/ || &error(&text('save_rule_erule'));

# Sanitize rule string by splitting into components and validating each
my @parts = split(/\s+/, $rule);
my $sanitized_rule = '';
for (my $i = 0; $i < @parts; $i++) {
	my $part = $parts[$i];
	next if (!defined($part) || $part eq '');

	if ($family =~ /^ipv[46]$/ &&
	    $part =~ /^(?:--source|--destination)$/) {
		# Get the IP value (next part)
		my $ip = $parts[++$i];
		if (defined($ip)) {
			# Split IP and CIDR if present
			my ($ip_only, $cidr) = split(/\//, $ip);

			# Validate the IP portion
			&check_ipaddress($ip_only) ||
			&check_ip6address($ip_only) ||
				&error("$text{'list_rule_iperr'} : $ip_only");

			# Verify IP family matches the rule family
			my $ip_family = $ip_only =~ /:/ ? 'ipv6' : 'ipv4';
			$ip_family eq $family ||
				&error(&text('save_rule_eruleipmismatch'));

			# Validate CIDR if present
			if (defined($cidr)) {
				# Make sure CIDR is numeric and within range
				my $cidr_valid = $family eq 'ipv6' ? 128 : 32;
				$cidr =~ /^\d+$/ && $cidr <= ($cidr_valid) ||
					&error("$text{'save_rule_cidrerr'} : /$cidr");
				}
			$sanitized_rule .= ' ' . $part . ' ' . $ip;
			}
		}
	elsif ($family eq 'eb' && $part =~ /^(?:--src-mac|--dst-mac)$/) {
		# Get the MAC value (next part)
		my $mac = $parts[++$i];
		if (defined($mac)) {
			# MAC validation could be added here
			$sanitized_rule .= ' ' . $part . ' ' . $mac;
			}
		}
	else {
		if ($part =~ /^-/) {
			# Options/flags can only contain certain characters
			$part =~ tr/A-Za-z0-9\-\_//cd;
			}
		else {
			# Values can contain more characters
			$part =~ tr/A-Za-z0-9\-\_\=\.\:\,\/\"\'//cd;
			}
		$sanitized_rule .= ' ' . $part;
		}
	}

# Remove extra possible spaces
$sanitized_rule =~ s/\s+/ /g;

# Return the constructed rule
return "$family $table $chain $priority $sanitized_rule";
}

# direct_rule(action, &opts)
# Add or remove a direct rule
#
# Returns:
#   undef on success, or (error_message, error_code) on failure in list context
sub direct_rule
{
my ($action, $opts) = @_;

# Validate action
$action eq 'add' || $action eq 'remove' || &error($text{'list_rule_actionerr'});

# Extract permanent flag and construct rule
my $permanent = delete($opts->{'permanent'});

# Get rule
my $rule = $opts->{'rule'};
$rule =~ s/\s+/ /g;

# Add/remove direct rule
my $get_cmd = sub {
	my ($perm) = @_;
	my $type = $perm ? " --permanent" : "";
	return "$config{'firewall_cmd'}$type --direct --$action-rule $rule";
	};

for my $type (0..1) {
	next if ($type == 1 && !$permanent);
	my $cmd = &$get_cmd($type);
	my $out = &backquote_logged($cmd." 2>&1 </dev/null");
	return wantarray ? ($out, $?) : $out if ($?);
	}
return undef;
}

# check_direct_rule(rule)
# Check if a direct rule exists
#
# Returns:
#   1 if rule exists, 0 if not
sub check_direct_rule
{
my ($rule) = @_;

# Construct rule for matching
my ($family, $table, $chain) = split(/\s+/, $rule);
my $rrule = $rule;
$rrule =~ s/^\Q$family\E\s+\Q$table\E\s+\Q$chain\E\s+//;
$rrule =~ s/\s+/ /g;

# Get existing rules
my $cmd = "$config{'firewall_cmd'} --direct --get-rules $family $table $chain";
my $out = &backquote_logged($cmd." 2>&1 </dev/null");
return $? ? 0 : ($out =~ /\Q$rrule\E/);
}

# remove_direct_rule(rule)
# Remove given direct rule passed as string
sub remove_direct_rule
{
my ($rule) = @_;
my ($out, $rs) = &direct_rule('remove', { 'rule' => $rule, 'permanent' => 1 });
return wantarray ? ($out, $?) : $out if ($?);
}

1;
