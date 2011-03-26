# iptables-lib.pl
# Defines firewall functions for IPtables

@actions = ( 'accept', 'drop', 'reject', 'ignore' );
$save_file = "$module_config_directory/iptables.save";
$prerules = "$module_config_directory/prerules";
$postrules = "$module_config_directory/postrules";
$prenat = "$module_config_directory/prenat";
$postnat = "$module_config_directory/postnat";
$premangle = "$module_config_directory/premangle";
$postmangle = "$module_config_directory/postmangle";


use Time::Local;

# apply_rules()
# Turns the firewall configuration into an IPtables save file, and then
# applies it.
sub apply_rules
{
&deactivate_all_interfaces();	# will add those needed later

local @dayname = ( "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" );

# Create the groups
open(SAVE, ">$save_file");
print SAVE "*filter\n";
print SAVE ":INPUT ACCEPT [0:0]\n";
print SAVE ":OUTPUT ACCEPT [0:0]\n";
print SAVE ":FORWARD ACCEPT [0:0]\n";
print SAVE ":SYN-FLOOD -\n";

# Disable bandwith monitor
# Have a lots of issues. 
# AA 2006-02-21

 
#if ($config{'bandwidth'}) {
#	# Add rules for bandwidth logging
#	print SAVE "-A INPUT -i $config{'bandwidth'} -j LOG --log-prefix BANDWIDTH_IN: --log-level debug\n";
#	print SAVE "-A FORWARD -i $config{'bandwidth'} -j LOG --log-prefix BANDWIDTH_IN: --log-level debug\n";
#	print SAVE "-A FORWARD -o $config{'bandwidth'} -j LOG --log-prefix BANDWIDTH_OUT: --log-level debug\n";
#	print SAVE "-A OUTPUT -o $config{'bandwidth'} -j LOG --log-prefix BANDWIDTH_OUT: --log-level debug\n";
#	}

# Add rules for spoofing
local ($spoofiface, @nets) = &get_spoof();
if ($spoofiface) {
	local $n;
	foreach $n (@nets) {
		print SAVE "-A INPUT -i $spoofiface -s $n -j DROP\n";
		}
	}

# Always allow established connections
print SAVE "-A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT\n";
print SAVE "-A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT\n";

# Always allow localhost
print SAVE "-A INPUT -i lo -j ACCEPT\n";
print SAVE "-A OUTPUT -o lo -j ACCEPT\n";

if ($config{'frags'}) {
	# Drop fragments
	print SAVE "-A INPUT -p ip -f -j DROP\n";
	print SAVE "-A OUTPUT -p ip -f -j DROP\n";
	print SAVE "-A FORWARD -p ip -f -j DROP\n";
	}

# Add syn flood and spoofing rules
local ($flood, $spoof, $fin) = &get_syn();
if ($flood) {
	# Limit number of syns / second
	print SAVE "-A SYN-FLOOD -m limit --limit 1/s --limit-burst 4 -j RETURN\n";
	print SAVE "-A SYN-FLOOD -j DROP\n";
	print SAVE "-A INPUT -p tcp -m tcp --syn -j SYN-FLOOD\n";
	}
if ($spoof) {
	# Drop TCP connection starts without SYN set
	print SAVE "-A INPUT -p tcp -m tcp ! --syn -m state --state NEW -j DROP\n";
	}
if ($fin) {
	# Drop TCP packets with both SYN and FIN
	print SAVE "-A INPUT -p tcp -m tcp --tcp-flags SYN,FIN SYN,FIN -j DROP\n";
	}

# Load PRErules 
open(STATICS, $prerules);
while(<STATICS>) {
        print SAVE "$_";
        }
close(STATICS);

# Add primary rules
local $r;
local @rules = &list_rules();
local %services = map { $_->{'name'}, $_ } &list_services();
local %times = map { $_->{'name'}, $_ } &list_times();
local @groups = &list_groups();
foreach $r (@rules) {
	next if (!$r->{'enabled'});
	next if ($r->{'sep'});

	# Work out all source and destination hosts?
	local @sources = &expand_hosts($r->{'source'}, \@groups);
	local @dests = &expand_hosts($r->{'dest'}, \@groups);

	# Work out time args
	local $timearg;
	if ($r->{'time'} ne "*") {
		local $time = $times{$r->{'time'}};
		$timearg .= "-m time";
		if ($time->{'hours'} ne "*") {
			local ($from, $to) = split(/\-/, $time->{'hours'});
			$timearg .= " --timestart $from --timestop $to";
			}
		if ($time->{'days'} ne "*") {
			$timearg .= " --days ".
				join(",", map { $dayname[$_] }
					  split(/,/, $time->{'days'}));
			}
		}

	# Need to output a rule for every possible combination
	local ($source, $dest);
	local $aarg = "-j ".uc($r->{'action'});
	local $n = $r->{'num'};
	local $logpfx = "--log-prefix RULE_${n}:".uc($r->{'action'}).":";
	foreach $source (@sources) {
		$source =~ s/^!(\S.*)$/! $1/;
		local $sarg = $source eq '*' ? "" :
			      $source =~ /^%(.*)$/ ? "-o $1" :
			      			     "-s $source";
		local $me = &my_address_in($source);

		foreach $dest (@dests) {
			$dest =~ s/^!(\S.*)$/! $1/;
			local $darg = $dest eq '*' && !$config{'fw_any'} &&
				       $r->{'action'} eq 'accept' ? "! -d $me" :
				      $dest eq '*' ? "" :
				      $dest =~ /^%(.*)$/ ? "-i $1" :
							   "-d $dest";

			if ($r->{'service'} ne '*') {
				# Output one rule for each real service
				local ($protos, $ports) =
					&combine_services($r->{'service'},
							  \%services);
				for($i=0; $i<@$protos; $i++) {
					local $pr = lc($protos->[$i]);
					local $pt = $ports->[$i];
					local $marg = $pr eq 'tcp' ||
						$pr eq 'udp' || $pr eq 'icmp' ? "-m $pr" : "";
					local $prarg;
					if ($pr eq "gre") {
						# handle old GRE protocols
						$pr = "ip";
						$pr = "gre";
						}
					if ($pr eq "ip") {
						$prarg = "-p $pt";
						}
					else {
						$prarg = "-p $pr";
						}
					local $parg;
					if ($pr eq "ip") {
						# No need for port number
						}
					elsif ($pt =~ /^(\d+)$/ || $pt eq '*') {
						if ($pr eq 'icmp') {
							$parg = "--icmp-type $pt" if ($pt ne '*');
							}
						else {
							$parg = "--destination-port $pt";
							}
						}
					elsif ($pt =~ /^(\d+)\-(\d+)$/) {
						$parg = "--dport $1:$2";
						}
					else {
						$parg = "--dports ".
						  join(",", split(/\s+/, $pt));
						$marg .= " -m multiport";
						}
					if ($r->{'log'}) {
						if ($source !~ /^%(.*)$/) {
						#if ($dest !~ /^%(.*)$/) {
							print SAVE "-A INPUT $marg $prarg $timearg $sarg $darg $parg -j LOG $logpfx\n";
							}
						print SAVE "-A FORWARD $marg $prarg $timearg $sarg $darg $parg -j LOG $logpfx\n";
						}
					if ($source !~ /^%(.*)$/) {
					#if ($dest !~ /^%(.*)$/) {
						print SAVE "-A INPUT $marg $prarg $timearg $sarg $darg $parg $aarg\n";
						}
						print SAVE "-A FORWARD $marg $prarg $timearg $sarg $darg $parg $aarg\n";
					}
				}
			else {
				# Single service-independent rule
				if ($r->{'log'}) {
					if ($source !~ /^%(.*)$/) {
					#if ($dest !~ /^%(.*)$/) {
						print SAVE "-A INPUT $timearg $sarg $darg -j LOG $logpfx\n";
						}
					print SAVE "-A FORWARD $timearg $sarg $darg -j LOG $logpfx\n";
					}
				if ($source !~ /^%(.*)$/) {
				#if ($dest !~ /^%(.*)$/) {
					print SAVE "-A INPUT $timearg $sarg $darg $aarg\n";
					}
				print SAVE "-A FORWARD $timearg $sarg $darg $aarg\n";
				}
			}
		}
	}
# Load POSTrules 
open(STATICS, $postrules);
while(<STATICS>) {
        print SAVE "$_";
        }
close(STATICS);


print SAVE "COMMIT\n";

print SAVE "*nat\n";
print SAVE ":PREROUTING ACCEPT [0:0]\n";
print SAVE ":POSTROUTING ACCEPT [0:0]\n";
print SAVE ":OUTPUT ACCEPT [0:0]\n";



local ($natiface, @nets) = &get_nat();
local @maps;
if ($natiface) {
	# Add rules for NAT
	@maps = grep { ref($_) } @nets;
	@nets = grep { !ref($_) } @nets;

	# Add rules for NAT exclusions
	local ($e,$my_e);	
	foreach $e (grep { $_ =~ /^\!/ } @nets) {
		$my_e = $e;
		$my_e =~ s/^\!//;
		local @dests = &expand_hosts("\@$my_e", \@groups);
		local $dest;

		foreach $dest (@dests) {
			$dest =~ s/^!(\S.*)$/! $1/;
			#print SAVE "-A POSTROUTING -o $natiface -d $dest -j RETURN\n";
			#print SAVE "-A PREROUTING -i $natiface -d $dest -j RETURN\n";
			print SAVE "-A POSTROUTING -d $dest -j RETURN\n";
			print SAVE "-A PREROUTING -d $dest -j RETURN\n";
			}
		}
	#Clear the nets_copy
	
	# Load PREnat After Return
	open(STATICS, $prenat);
	while(<STATICS>) {
		print SAVE "$_";
		}
	close(STATICS);


	# Add rules for static NAT
	local $m;
	local ($intf_i,$intf_o,$option_i,$option_o);
	
	#		local @dests = &expand_hosts("\@$my_e", \@groups);
	local (@tmp,$internal,$external);

	
	foreach $m (@maps) {
		@tmp = &expand_hosts("\@$m->[1]", \@groups);
		$internal=$tmp[0];
		#@tmp = &expand_hosts("\@$m->[0]", \@groups);		
		$external="$m->[0]";
		if ($m->[2]) {
			$intf_i= " -i $m->[2] ";
			$intf_o= " -o $m->[2] ";	     
		} else {
			$intf_i= "";
			$intf_o= "";	     
		}
		if (&check_netaddress($external)) {
			$option_i=" -j NETMAP ";
			$option_o=" -j NETMAP ";
		} elsif (&check_netaddress($internal)) {
			$option_o=" -j SNAT ";
			if ($m->[2]) {
				&activate_interface($m->[2], $external);
			}					
		} else {
			$option_i=" -j DNAT ";
			$option_o=" -j SNAT ";
			if ($m->[2]) {
				&activate_interface($m->[2], $external);
			}
		}
		(! &check_netaddress($internal) ) && print SAVE "-A PREROUTING $intf_i -d $external $option_i --to $internal\n";
		print SAVE "-A POSTROUTING $intf_o -s $internal $option_o --to $external\n";
		}

	# Load POSTnat
	open(STATICS, $postnat);
	while(<STATICS>) {
		print SAVE "$_";
		}
	close(STATICS);

	# Add rules for dynamic NAT
	
	local $n;
	foreach $n (grep { $_ !~ /^\!/ } @nets) {
		local @sources = &expand_hosts("\@$n", \@groups);
		local $source;
		foreach $source (@sources) {
			$source =~ s/^!(\S.*)$/! $1/;
			print SAVE "-A POSTROUTING -o $natiface -s $source -j MASQUERADE\n";
			}
		}
	}

# Add rules for PAT
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
		print SAVE "-A PREROUTING -m $pr -p $pr --dport $pt -i $f->{'iface'} -j DNAT --to-destination $f->{'host'}:$pt\n";
		}
	}

print SAVE "COMMIT\n";

print SAVE "*mangle\n";
print SAVE ":PREROUTING ACCEPT [0:0]\n";
print SAVE ":OUTPUT ACCEPT [0:0]\n";
# Load PREmangle
open(STATICS, $premangle);
while(<STATICS>) {
        print SAVE "$_";
        }
close(STATICS);
# Add rules

# Load POSTmangle
open(STATICS, $postmangle);
while(<STATICS>) {
        print SAVE "$_";
        }
close(STATICS);
print SAVE "COMMIT\n";
close(SAVE);

# Apply the save file
local $out = `iptables-restore <$save_file 2>&1`;
if ($?) {
	return "iptables-restore output : <pre>$out</pre>";
	}
return undef;
}

# stop_rules()
# Cancel all firewall rules and return to the default settings (allow all)
sub stop_rules
{
&deactivate_all_interfaces();
local $table;
foreach $table ([ "filter", "INPUT", "OUTPUT", "FORWARD" ],
		[ "nat", "PREROUTING", "POSTROUTING", "OUTPUT" ],
		[ "mangle", "PREROUTING", "OUTPUT" ]) {
	local ($name, @chains) = @$table;
	local $cmd;
	foreach $cmd ((map { "iptables -t $name -P $_ ACCEPT" } @chains),
		      "iptables -t $name -F",
		      "iptables -t $name -X",
		      "iptables -t $name -Z") {
		local $out = `$cmd 2>&1`;
		if ($?) {
			return "$cmd output : $out";
			}
		}
	}
return undef;
}

# enable_routing()
# Enable routing under Linux
sub enable_routing
{
system("sysctl -w net.ipv4.ip_forward=1 >/dev/null 2>&1");
}

# disable_routing()
# Disable routing under Linux
sub disable_routing
{
system("sysctl -w net.ipv4.ip_forward=0 >/dev/null 2>&1");
}

sub get_log_file
{
return "/var/log/messages";
}

sub get_authlog_file
{
return -r "/var/log/secure" ? "/var/log/secure" :
       -r "/var/log/security" ? "/var/log/security" :
       -r "/var/log/authlog" ? "/var/log/authlog" :
			       "/var/log/auth";
}

sub is_log_line
{
return $_[0] =~ /IN=.*OUT=/;
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
	if ($_[0] =~ /RULE_(\d+):([^\s:]+)/) {
		$info->{'rule'} = $1;
		$info->{'action'} = lc($2);
		}
	if ($_[0] =~ /^(\S+)\s+(\d+)\s+(\d+):(\d+):(\d+)/) {
		local $tm = timelocal($5, $4, $3, $2, $mmap{lc($1)}, $time_now[5]);
		if ($tm > $time_now + 24*60*60) {
			# Was really last year
			$tm = timelocal($5, $4, $3, $2, $mmap{lc($1)}, $time_now[5]-1);
			}
		$info->{'time'} = $tm;
		}
	$info->{'src_iface'} = $1 if ($_[0] =~ /OUT=(\S*)/);
	$info->{'dst_iface'} = $1 if ($_[0] =~ /IN=(\S*)/);
	$info->{'src'} = $1 if ($_[0] =~ /SRC=(\S*)/);
	$info->{'dst'} = $1 if ($_[0] =~ /DST=(\S*)/);
	$info->{'size'} = $1 if ($_[0] =~ /LEN=(\S*)/);
	$info->{'proto'} = $1 if ($_[0] =~ /PROTO=(\S*)/);
	$info->{'src_port'} = $1 if ($_[0] =~ /SPT=(\S*)/);
	$info->{'dst_port'} = $1 if ($_[0] =~ /DPT=(\S*)/);
	$info->{'dst_port'} = $1 if ($_[0] =~ /TYPE=(\S*)/ &&
				     $info->{'proto'} eq 'ICMP');
	return $info;
	}
else {
	return undef;
	}
}

sub allow_action
{
return $_[0]->{'action'} eq 'accept';
}

sub deny_action
{
return $_[0]->{'action'} eq 'drop';
}

sub default_action
{
return "drop";
}

sub supports_time
{
return 1;
}

sub supports_bandwidth
{
return &foreign_check("bandwidth");
}

1;

