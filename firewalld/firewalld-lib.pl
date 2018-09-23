# Functions for managing firewalld

BEGIN { push(@INC, ".."); };
use strict;
use warnings;
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
		push(@rv, [ $s, $s ]);
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
my $out = &backquote_logged("$config{'firewall_cmd'} --reload 2>&1");
return $? ? $out : undef;
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
return $ok ? undef : $err;
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

1;
