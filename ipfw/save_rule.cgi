#!/usr/local/bin/perl
# Create, update or delete a firewall rule

require './ipfw-lib.pl';
&ReadParse();
&error_setup($text{'save_err'});

$rules = &get_config();
if ($in{'new'}) {
	# Find the last editable rule
	if ($rules->[@$rules-1]->{'num'} == 65535 &&
	    @$rules > 1) {
		$lastidx = $rules->[@$rules-2]->{'index'};
		}
	else {
		$lastidx = $rules->[@$rules-1]->{'index'};
		}

	# Work out where to insert, and what number to use
	if ($in{'before'} ne '') {
		# Adding before some rule
		local $pn = $in{'before'} == 0 ? 0 :
			    $rules->[$in{'before'}-1]->{'num'};
		$rule = { 'num' => ($rules->[$in{'before'}]->{'num'}+$pn)/2 };
		splice(@$rules, $in{'before'}, 0, $rule);
		}
	elsif ($in{'after'} ne '') {
		# Adding after some rule
		local $nn = $in{'after'} == $lastidx ?
				$rules->[$in{'after'}]->{'num'}+200 :
				$rules->[$in{'after'}+1]->{'num'};
		$rule = { 'num' => ($rules->[$in{'after'}]->{'num'}+$nn)/2 };
		splice(@$rules, $in{'after'}+1, 0, $rule);
		}
	elsif (!$in{'num_def'}) {
		# At specified number
		$in{'num'} =~ /^\d+$/ && $in{'num'} >= 0 && $in{'num'} < 65536
			|| &error($text{'save_enum'});
		$rule = { 'num' => $in{'num'} };
		my $found = 0;
		for(my $i=0; $i<@$rules; $i++) {
			if ($rules->[$i]->{'num'} >= $in{'num'}) {
				splice(@$rules, $i, 0, $rule);
				$found++;
				last;
				}
			}
		push(@$rules, $rule) if (!$found);
		}
	elsif (!@$rules) {
		# First rule
		$rule = { 'num' => '00100' };
		push(@$rules, $rule);
		}
	else {
		# At end or before last deny-all rule
		$rule = { 'num' => $rules->[$lastidx]->{'num'}+100 };
		splice(@$rules, $lastidx+1, 0, $rule);
		}
	$rule->{'num'} = sprintf "%5.5d", $rule->{'num'};
	}
else {
	$rule = $rules->[$in{'idx'}];
	delete($rule->{'text'});
	}

if ($in{'delete'}) {
	# Just remove this rule
	splice(@$rules, $in{'idx'}, 1);
	}
else {
	# Validate inputs and contruct the rule object
	$in{'cmt'} =~ s/\r//g;
	$rule->{'cmt'} = $in{'cmt'};

	# Parse rule action and arg
	$rule->{'action'} = $in{'action'};
	if ($in{'action'} eq "skipto") {
		$in{'action_skipto'} =~ /^\d+$/ ||
			&error($text{'save_eskipto'});
		$rule->{'aarg'} = $in{'action_skipto'};
		}
	elsif ($in{'action'} eq "fwd") {
		&check_ipaddress($in{'action_fwdip'}) ||
			&error($text{'save_efwdip'});
		if ($in{'action_fwdport'} eq "") {
			$rule->{'aarg'} = $in{'action_fwdip'};
			}
		else {
			$in{'action_fwdport'} =~ /^\d+$/ ||
				&error($text{'save_efwdport'});
			$rule->{'aarg'} = $in{'action_fwdip'}.",".
					  $in{'action_fwdport'};
			}
		}
	elsif ($in{'action'} eq "divert" || $in{'action'} eq "pipe" ||
	       $in{'action'} eq "queue" || $in{'action'} eq "tee") {
		$in{'action_port'} =~ /^\d+$/ ||
			&error($text{'save_eteeport'});
		$rule->{'aarg'} = $in{'action_port'};
		}
	elsif ($in{'action'} eq "unreach") {
		$rule->{'aarg'} = $in{'action_unreach'};
		}
	else {
		delete($rule->{'aarg'});
		}

	# Parse protocol
	if ($in{'proto_orblock'}) {
		$rule->{'proto'} = &parse_orblock("proto");
		}
	else {
		$rule->{'proto'} = $in{'proto'};
		}

	# Parse in/out option
	delete($rule->{'in'});
	delete($rule->{'out'});
	delete($rule->{'in_not'});
	delete($rule->{'out_not'});
	if ($in{'inout'} == 1) {
		$rule->{'in'} = 1;
		}
	elsif ($in{'inout'} == 2) {
		$rule->{'out'} = 1;
		}

	# Parse via interface
	$rule->{'via'} = &parse_interface("via");

	# Parse logging level
	if ($in{'log'}) {
		$rule->{'log'} = 1;
		if ($in{'logamount'} ne "") {
			$in{'logamount'} =~ /^\d+$/ ||
				&error($text{'save_elogamount'});
			$rule->{'logamount'} = $in{'logamount'};
			}
		else {
			delete($rule->{'logamount'});
			}
		}
	else {
		$rule->{'log'} = 0;
		}

	# Parse source and destination
	foreach $s ("from", "to") {
		# IP address
		if ($in{$s."_orblock"}) {
			$rule->{$s} = &parse_orblock($s);
			}
		elsif ($in{$s."_mode"} == 0) {
			$rule->{$s} = "any";
			}
		elsif ($in{$s."_mode"} == 1) {
			$rule->{$s} = "me";
			}
		else {
			&to_ipaddress($in{$s}) ||
			    ($in{$s} =~ /^([0-9\.]+)\/(\d+)$/ &&
			     &check_ipaddress("$1")) ||
			    ($in{$s} =~ /^([0-9\.]+)\/(\d+)\{([0-9,]+)\}$/ &&
			     &check_ipaddress("$1") &&
			     $ipfw_version >= 2) ||
				&error($text{'save_e'.$s});
			$rule->{$s} = $in{$s};
			}

		# Port numbers
		if ($in{$s."_ports_orblock"}) {
			# XXX could be optional?
			$rule->{$s."_ports"} = &parse_orblock($s."_ports");
			}
		elsif ($in{$s."_ports_mode"} == 0) {
			delete($rule->{$s."_ports"});
			}
		else {
			local $p = $rule->{'proto'};
			$p eq "tcp" || $p eq "udp" || $p eq "ip" ||
			    $ipfw_version >= 2 ||
				&error($text{'save_eportsproto'.$s});
			$in{$s."_ports"} =~ /^\d+$/ ||
			  getservbyname($in{$s."_ports"}, $p) ||
			  $in{$s."_ports"} =~ /^\d+\-\d+$/ ||
			  ($in{$s."_ports"} =~ /^([a-z0-9]+)\-([a-z0-9]+)$/i &&
			   getservbyname($1, $p) && getservbyname($2, $p)) ||
			  $in{$s."_ports"} =~ /^([a-z0-9]+)(,[a-z0-9]+)*$/ ||
			  ($in{$s."_ports"} =~ /^([a-z0-9]+|([a-z0-9]+)\-([a-z0-9]+))(,[a-z0-9]+|,([a-z0-9]+)\-([a-z0-9]+))*$/ &&
			   $ipfw_version >= 2) ||
				&error($text{'save_eports'.$s});
			$rule->{$s."_ports"} = $in{$s."_ports"};
			$rule->{$s."_ports_not"} = $in{$s."_ports_not"}
				if ($ipfw_version >= 2);
			}
		}
	$rule->{'xmit'} = &parse_interface("xmit");
	$rule->{'recv'} = &parse_interface("recv");

	# XXX multiple options

	# Parse various options
	&parse_yes_no_ignored("established");
	&parse_yes_no_ignored("keep-state");
	&parse_yes_no_ignored("bridged");
	&parse_yes_no_ignored("frag");
	&parse_yes_no_ignored("setup");

	# Parse MAC address
	if ($ipfw_version >= 2) {
		if ($in{'mac1_def'} && $in{'mac2_def'}) {
			delete($rule->{'mac'});
			}
		else {
			local @mac;
			if ($in{'mac2_def'}) {
				push(@mac, "any");
				}
			else {
				$in{'mac2'} =~ /^[0-9a-f]{2}(:[0-9a-f]{2}){5}(\/\d+)?$/ || &error($text{'save_emac2'});
				push(@mac, $in{'mac2'});
				}
			if ($in{'mac1_def'}) {
				push(@mac, "any");
				}
			else {
				$in{'mac1'} =~ /^[0-9a-f]{2}(:[0-9a-f]{2}){5}(\/\d+)?$/ || &error($text{'save_emac1'});
				push(@mac, $in{'mac1'});
				}
			$rule->{'mac'} = \@mac;
			}
		}

	# Parse UID and GID
	if ($in{'uid_def'}) {
		delete($rule->{'uid'});
		}
	elsif ($in{'uid'} =~ /^#(\d+)$/) {
		$rule->{'uid'} = $1;
		}
	else {
		defined($rule->{'uid'} = getpwnam($in{'uid'})) ||
			&error($text{'save_euid'});
		}
	if ($in{'gid_def'}) {
		delete($rule->{'gid'});
		}
	elsif ($in{'gid'} =~ /^#(\d+)$/) {
		$rule->{'gid'} = $1;
		}
	else {
		defined($rule->{'gid'} = getgrnam($in{'gid'})) ||
			&error($text{'save_egid'});
		}

	# Parse ICMP types
	if ($in{'icmptypes'}) {
		$rule->{'proto'} eq 'icmp' || &error($text{'save_eicmptypes'});
		$rule->{'icmptypes'} = join(",", split(/\0/, $in{'icmptypes'}));
		}
	else {
		delete($rule->{'icmptypes'});
		}

	# Parse tcp flags
	if ($in{'tcpflags'}) {
		$rule->{'proto'} eq 'tcp' || &error($text{'save_etcpflags'});
		$rule->{'tcpflags'} = join(",", split(/\0/, $in{'tcpflags'}));
		}
	else {
		delete($rule->{'tcpflags'});
		}

	# Parse limit directive
	if ($in{'limit'}) {
		$in{'limit2'} =~ /^\d+$/ || &error($text{'save_elimit'});
		$rule->{'limit'} = [ $in{'limit'}, $in{'limit2'} ];
		}
	else {
		delete($rule->{'limit'});
		}

	# Parse dst-port and src-port directive
	foreach $ds ('dst', 'src') {
		if (!$in{$ds.'port_def'}) {
			local @dstports = split(/[ ,]+/, $in{$ds.'port'});
			foreach $p (@dstports) {
				&valid_port($p, $rule->{'proto'}) ||
					&error($text{'save_e'.$ds.'port'});
				}
			$rule->{$ds.'-port'} = \@dstports;
			}
		else {
			delete($rule->{$ds.'-port'});
			}
		}
	}

# Save all rules
&lock_file($ipfw_file);
&save_config($rules);
&unlock_file($ipfw_file);
&copy_to_cluster();
&webmin_log($in{'delete'} ? "delete" : $in{'new'} ? "create" : "modify",
	    "rule", $rule->{'action'}, $rule);
&redirect("");

# parse_interface(name)
sub parse_interface
{
local $iface = $in{$_[0]} eq "other" ? $in{$_[0]."_other"} : $in{$_[0]};
return undef if (!$iface);
$iface =~ /^\S+$/ || &error($text{'save_e'.$_[0]});
return $iface;
}

# parse_orblock(name)
sub parse_orblock
{
$in{$_[0]} =~ /\S/ || &error(&text('save_eorblock'.$_[0])); 
return [ split(/\s+/, $in{$_[0]}) ];
}

# parse_yes_no_ignored(name)
sub parse_yes_no_ignored
{
if ($in{$_[0]} == 0) {
	delete($rule->{$_[0]});
	}
elsif ($in{$_[0]} == 1) {
	$rule->{$_[0]} = 1;
	$rule->{$_[0]."_not"} = 0;
	}
elsif ($in{$_[0]} == 2) {
	$rule->{$_[0]} = 1;
	$rule->{$_[0]."_not"} = 1;
	}
}

