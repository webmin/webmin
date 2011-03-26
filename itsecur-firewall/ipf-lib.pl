# ipf-lib.pl
# Defines firewall functions for IPF

@actions = ( "allow", "deny", "reject" );
$script_file = "$module_config_directory/ipf.sh";
$nat_conf =    "$module_config_directory/nat.conf";
use Time::Local;

# apply_rules(&rules, &hosts, &services)
# Turns the firewall configuration into an IPF script
sub apply_rules
{
&deactivate_all_interfaces();	# will add those needed later
local $ipfw = &has_command("ipfw");

# Open scripts
open(SCRIPT, ">$script_file");
print SCRIPT "#!/bin/sh\n";
open(NATCONF, ">$nat_conf");

# Clear existing rules
print SCRIPT "$ipfw -f flush\n";

# Add rules for spoofing
local ($spoofiface, @nets) = &get_spoof();
local $num = 1;
if ($spoofiface) {
	local $n;
	foreach $n (@nets) {
		print_ipfw("drop ip from $n to any recv $spoofiface");
		}
	}

# Allow established connections
$num = 2;
print_ipfw("allow tcp from any to any established");

# Always allow localhost
$num = 3;
print_ipfw("allow ip from any to any recv lo");

if ($config{'frags'}) {
	# Drop fragments
	# XXX how?
	}

# Add primary rules
local $r;
local @rules = &list_rules();
local %services = map { $_->{'name'}, $_ } &list_services();
local @groups = &list_groups();
foreach $r (@rules) {
	next if (!$r->{'enabled'});
	next if ($r->{'sep'});
	$num = $r->{'num'}*10;

	# Work out all source and destination hosts?
	local @sources = &expand_hosts($r->{'source'}, \@groups);
	local @dests = &expand_hosts($r->{'dest'}, \@groups);

	# Need to output a rule for every possible combination
	local ($source, $dest);
	local $aarg = $r->{'action'};
	local $logarg = $r->{'log'} ? "log" : "";
	foreach $source (@sources) {
		$source =~ s/^!(\S.*)$/not $1/;
		local $sarg = $source eq '*' ? "from any" :
			      $source =~ /^%(.*)$/ ? "from any" :
			      			     "from $source";
		local $siarg = $source =~ /^%(.*)$/ ? "xmit $1" : "";

		foreach $dest (@dests) {
			$dest =~ s/^!(\S.*)$/! $1/;
			local $darg = $dest eq '*' && !$config{'fw_any'} &&
				       $r->{'action'} eq 'allow' ? "! -d me" :
				      $dest =~ /^%(.*)$/ ? "to any" :
							   "to $dest";
			local $diarg = $dest =~ /^%(.*)$/ ? "recv $1" : "";

			if ($r->{'service'} ne '*') {
				# Output one rule for each service
				local ($protos, $ports) =
					&combine_services($r->{'service'},
							  \%services);
				for($i=0; $i<@$protos; $i++) {
					local $pr = lc($protos->[$i]);
					local $pt = $ports->[$i];

					local $parg;
					local $opts;
					local $prarg;
					if ($pr eq "gre") {
						# handle old GRE protocols
						$pr = "ip";
						$pr = "gre";
						}
					if ($pr eq "ip") {
						$prarg = $pt;
						}
					else {
						$prarg = $pr;
						}
					if ($pr eq "ip") {
						# No port for IP
						}
					elsif ($pt =~ /^(\d+)$/ || $pt eq '*') {
						if ($pr eq 'icmp') {
							$opts = " icmptype $pt" if ($pt ne '*');
							}
						else {
							$parg = $pt;
							}
						}
					elsif ($pt =~ /^(\d+)\-(\d+)$/) {
						$parg = "$1-$2";
						}
					else {
						$parg = join(",", split(/\s+/, $pt));
						}
					print_ipfw("$aarg $logarg $prarg $sarg $darg $parg $opts $siarg $diarg");
					}
				}
			else {
				# Single service-independent rule
				print_ipfw("$aarg $logarg ip $sarg $darg $siarg $diarg");
				}
			}
		}
	}

# Add syn flood and spoofing rules
local ($flood, $spoof, $fin) = &get_syn();
if ($flood) {
	# Configure kernel to use syn cookies
	print SCRIPT "sysctl net.inet.tcp.syncookies=1\n";
	}
else {
	# Configure kernel to disable syn cookies
	print SCRIPT "sysctl net.inet.tcp.syncookies=0\n";
	}
if ($spoof) {
	# Drop TCP connection starts without SYN set
	$num = 60000;
	print_ipfw("allow tcp from any to any established");
	print_ipfw("deny tcp from any to any tcpflags !syn");
	}
if ($fin) {
	# Drop TCP packets with both SYN and FIN set
	$num = 61000;
	print_ipfw("deny tcp from any to any tcpflags syn,fin");
	}

local ($natiface, @nets) = &get_nat();
local @maps;
if ($natiface) {
	# Add rules for NAT
	@maps = grep { ref($_) } @nets;
	@nets = grep { !ref($_) } @nets;
	local $m;
	foreach $m (@maps) {
		# Add rule for static NAT (internal to external host mapping)
		print NATCONF "map $natiface $m->[1]/32 -> $m->[0]/32\n";
		print NATCONF "map $natiface $m->[0]/32 -> $m->[1]/32\n";
		if ($m->[2]) {
			&activate_interface($m->[2], $m->[0]);
			}
		}
	local $n;
	foreach $n (@nets) {
		# Add rule for dynamic NAT
		local @sources = &expand_hosts("\@$n", \@groups);
		local $source;
		foreach $source (@sources) {
			$source =~ s/^!(\S.*)$/! $1/;
			print NATCONF "map $natiface $source -> 0/32\n";
			}
		}
	}

# Add rules for PAT (external port to internal host mapping)
local @forwards = &get_pat();
local $f;
foreach $f (@forwards) {
	next if (!$f->{'iface'});
	local ($protos, $ports) = &combine_services($f->{'service'},
						    \%services);
	local $i;
	for($i=0; $i<@$protos; $i++) {
		local $pr = lc($protos->[$i]);
		local $pt = $ports->[$i];
		next if ($pr ne 'tcp' && $pr ne 'udp');
		print NATCONF "rdr $f->{'iface'} 0/32 port $pt -> $f->{'host'} port $pt $pr\n";
		}
	}

# Allow all by default
$num = 60001;
print_ipfw("allow ip from any to any");
close(SCRIPT);
chmod(0755, $script_file);
close(NATCONF);

# Run the script
#return "<pre>".`cat $script_file`."</pre>\n";
local $out = `cd /; $script_file 2>&1 </dev/null`;
if ($?) {
	return "IPF script output : <pre>$out</pre>";
	}

# Run the NAT config
$out = `cd /; ipnat -C >/dev/null ; ipnat -f $nat_conf 2>&1 </dev/null`;
if ($? || $out) {
	return "ipnat command output : <pre>$out</pre>";
	}

return undef;
}

sub print_ipfw
{
print SCRIPT "$ipfw add $num $_[0]\n";
}

# stop_rules()
# Allow all traffic
sub stop_rules
{
&deactivate_all_interfaces();
system("cd /; ipfw -f flush; ipfw add allow ip from any to any");
system("cd /; ipnat -C");
}

# enable_routing()
# Enable routing under BSD
sub enable_routing
{
system("sysctl net.inet.ip.forwarding=1 >/dev/null 2>&1");
}

# disable_routing()
# Disable routing under BSD
sub disable_routing
{
system("sysctl net.inet.ip.forwarding=0 >/dev/null 2>&1");
}

sub get_log_file
{
return "/var/log/security";
}

sub get_authlog_file
{
return "/var/log/security";
}

sub is_log_line
{
return $_[0] =~ /\sipfw:\s/;
}

$time_now = time();
@time_now = localtime($time_now);
%mmap = ( 'jan' => 0, 'feb' => 1, 'mar' => 2, 'apr' => 3,
	  'may' => 4, 'jun' => 5, 'jul' => 6, 'aug' => 7,
	  'sep' => 8, 'oct' => 9, 'nov' =>10, 'dec' =>11 );

# parse_log_line(line)
# Parses a line into a log info structure, or returns undef
sub parse_log_line
{
if (&is_log_line($_[0])) {
	local $info = { };
	if ($_[0] =~ /^(\S+)\s+(\d+)\s+(\d+):(\d+):(\d+)/) {
		local $tm = timelocal($5, $4, $3, $2, $mmap{lc($1)}, $time_now[5]);
		if ($tm > $time_now + 24*60*60) {
			# Was really last year
			$tm = timelocal($5, $4, $3, $2, $mmap{lc($1)}, $time_now[5]-1);
			}
		$info->{'time'} = $tm;
		}
	if ($_[0] =~ /ipfw:\s+(\d+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(in|out)\s+\S+\s+(\S+)/) {
		if ($1 >= 10 && $1 < 60000) {
			$info->{'rule'} = int($1/10);
			}
		$info->{'action'} = lc($2);
		$info->{'action'} = "allow" if ($info->{'action'} eq "accept");
		$info->{'proto'} = uc($3);
		if ($6 eq "in") {
			$info->{'dst_iface'} = $7;
			}
		else {
			$info->{'src_iface'} = $7;
			}
		local ($src, $dst) = ($4, $5);
		if ($src =~ /^(\S+):(\d+)$/) {
			$info->{'src'} = $1;
			$info->{'src_port'} = $2;
			}
		else {
			$info->{'src'} = $src;
			}
		if ($dst =~ /^(\S+):(\d+)$/) {
			$info->{'dst'} = $1;
			$info->{'dst_port'} = $2;
			}
		else {
			$info->{'dst'} = $dst;
			}
		if ($info->{'proto'} =~ /^(ICMP):(\d+)/) {
			$info->{'proto'} = $1;
			$info->{'dst_port'} = $2;
			}
		}
	return $info;
	}
else {
	return undef;
	}
}

sub allow_action
{
return $_[0]->{'action'} eq 'allow';
}

sub deny_action
{
return $_[0]->{'action'} eq 'deny';
}

sub default_action
{
return "deny";
}

sub supports_time
{
return 0;
}

sub supports_bandwidth
{
return 0;
}

1;

