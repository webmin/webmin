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
my $services_dir = "/usr/lib/firewalld/services/";
my $service_file = "$services_dir/$service.xml";
my @ports;
my @protos;
if (-r $service_file) {
	my $lref = &read_file_lines($service_file, 1);
	foreach my $l (@{$lref}) {
		$l =~ /<port\s+protocol=["'](?<proto>\S+)["']\s+port=["'](?<port>[\d-]+)["']\/>/;
		my $port = "$+{port}";
		my $proto = "$+{proto}";
		push(@ports, $port) if ($port);
		push(@protos, $proto) if ($port && $proto);
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
my %w = map { split(/=/, $_) } split(/:/, $str);
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

# add_ip_ban(ip, [zone])
# Ban given IP address in given or default zone
sub add_ip_ban
{
my ($ip, $zone) = @_;
return create_rich_rule('add', $ip, $zone);
}

# remove_ip_ban(ip, [zone])
# Un-ban given IP address in given or default zone 
sub remove_ip_ban
{
my ($ip, $zone) = @_;
return create_rich_rule('remove', $ip, $zone);
}

# create_rich_rule(action, ip, [\zone], [opts])
# Add or remove rich rule for given IP in given or default zone 
sub create_rich_rule
{
my ($action, $ip, $zone, $opts) = @_;
my $ip_validate = sub {
	return &check_ipaddress($_[0]) || &check_ip6address($_[0]);
	};

# Default action for permanent ban is 'drop'
my $action_type = "drop";

# Override defaults
if (ref($opts)) {
	
	# Override default action
	$action_type = lc($opts->{'action'})
		if ($opts->{'action'} &&
		    $opts->{'action'} =~ /^accept|reject|drop|mark$/);
}

# Zone name
if (!$zone) {
	($zone) = get_default_zone();
	}
$zone = $zone->{'name'};

# Validate action
$action eq 'add' || $action eq 'remove' || &error($text{'list_rule_actionerr'});

# Validate IP
&$ip_validate($ip) || &error($text{'list_rule_iperr'});

# Set family
my $family = $ip =~ /:/ ? 'ipv6' : 'ipv4';

# Add/remove rich rule
my $get_cmd = sub {
	my ($rtype) = @_;
	my $type;
	$type = " --permanent" if ($rtype eq 'permanent');
	return "$config{'firewall_cmd'} --zone=".quotemeta($zone)."$type --".quotemeta($action)."-rich-rule=\"rule family=".quotemeta($family)." source address=".quotemeta($ip)." ".quotemeta($action_type)."\"";
	};
my $out = &backquote_logged(&$get_cmd()." 2>&1 </dev/null");
return $out if ($?);
$out = &backquote_logged(&$get_cmd('permanent')." 2>&1 </dev/null");
return $? ? $out : undef;
}

# remove_rich_rule(rule, [\zone])
# Remove rich rule in given or default zone 
sub remove_rich_rule
{
my ($rule, $zone) = @_;

# Zone name
if (!$zone) {
	($zone) = get_default_zone();
	}
$zone = $zone->{'name'};

# Remove rule command
my $get_cmd = sub {
	my ($rtype) = @_;
	my $type;
	$type = " --permanent" if ($rtype eq 'permanent');
	return "$config{'firewall_cmd'} --zone=".quotemeta($zone)."$type --remove-rich-rule ".quotemeta(&trim($rule))."";
	};

my $out = &backquote_logged(&$get_cmd()." 2>&1 </dev/null");
return $out if ($?);
$out = &backquote_logged(&$get_cmd('permanent')." 2>&1 </dev/null");
return $? ? $out : undef;
}

# remove_direct_rule(rule)
# Remove given direct rule
sub remove_direct_rule
{
my ($rule) = @_;

# Sanitize rule manually (couldn't make it work with quotemeta)
$rule =~ tr/A-Za-z0-9\-\_\=\"\:\.\,\/ //cd;

# Remove rule command
my $get_cmd = sub {
	my ($rtype) = @_;
	my $type;
	$type = " --permanent" if ($rtype eq 'permanent');
	return "$config{'firewall_cmd'}${type} --direct --remove-rule ".&trim($rule)."";
	};

my $out = &backquote_logged(&$get_cmd()." 2>&1 </dev/null");
return $out if ($?);
$out = &backquote_logged(&$get_cmd('permanent')." 2>&1 </dev/null");
return $? ? $out : undef;
}

sub get_config_files
{
my $conf_dir = $config{'config_dir'} || '/etc/firewalld';
my @conf_files;
my @dirpath = ($conf_dir);
eval "use File::Find;";
if (!$@) {
	find(sub {
		my $file = $File::Find::name;
		push(@conf_files, $file)
			if (-f $file && $file =~ /\.(conf|xml)$/);
		}, @dirpath);
	}
push(@conf_files, "$conf_dir/direct.xml");
return @conf_files;
}

1;
