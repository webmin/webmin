#!/usr/local/bin/perl
# Update one NAT rule

require './ipfilter-lib.pl';
&ReadParse();
$rules = &get_ipnat_config();
if (!$in{'new'}) {
	# Get the rule
	$rule = $rules->[$in{'idx'}];
	}
else {
	$rule = { 'file' => $config{'ipnat_conf'},
		  'type' => 'ipnat' };
	}

if ($in{'delete'}) {
	# Just deleting
	&lock_file($rule->{'file'});
	&delete_rule($rule);
	&flush_file_lines();
	&unlock_file($rule->{'file'});
	&webmin_log("delete", "nat", undef, $rule);
	&redirect("");
	exit;
	}

# Validate and store inputs, starting with action
&error_setup($text{'nat_err'});
$rule->{'cmt'} = $in{'cmt'};
$rule->{'active'} = $in{'active'};
$rule->{'action'} = $in{'action'};

if ($rule->{'action'} ne 'rdr') {
	# Parse source options
	$rule->{'iface'} = &parse_interface_choice("iface", $text{'nat_eiface'});
	if ($in{'frommode'} == 0) {
		delete($rule->{'from'});
		&parse_ipmask_input("from");
		}
	else {
		$in{'action'} eq 'map-block' && &error($text{'nat_emapblock1'});
		$rule->{'from'} = 1;
		&parse_object_input($rule, "from");
		&parse_object_input($rule, "fromto");
		}

	# Parse destination
	delete($rule->{'tostart'});
	if ($in{'tomode'} == 0) {
		&parse_ipmask_input("to");
		}
	elsif ($in{'tomode'} == 2) {
		$rule->{'toip'} = '0.0.0.0';
		$rule->{'tomask'} = 32;
		}
	else {
		$in{'action'} eq 'map-block' && &error($text{'nat_emapblock2'});
		&check_ipaddress($in{'tostart'}) ||
			&error($text{'nat_etostart'});
		&check_ipaddress($in{'toend'}) ||
			&error($text{'nat_etoend'});
		$rule->{'tostart'} = $in{'tostart'};
		$rule->{'toend'} = $in{'toend'};
		}

	# Parse port mapping
	if ($in{'portmapmode'} == 0) {
		delete($rule->{'portmap'});
		}
	else {
		$rule->{'portmap'} = $in{'portmap'};
		if ($in{'portmapnoauto'}) {
			$rule->{'portauto'} = 0;
			&valid_port($in{'portmapfrom'}) ||
				&error($text{'nat_eportmapfrom'});
			&valid_port($in{'portmapto'}) ||
				&error($text{'nat_eportmapto'});
			$rule->{'portmapfrom'} = $in{'portmapfrom'};
			$rule->{'portmapto'} = $in{'portmapto'};
			}
		else {
			$rule->{'portauto'} = 1;
			}
		}

	# Parse application proxy
	if ($in{'proxymode'} == 0) {
		delete($rule->{'proxyport'});
		}
	else {
		&parse_proxy_input("proxy");
		}

	# Parse other options
	if ($in{'proto'}) {
		$rule->{'proto'} = $in{'protoproto'};
		}
	else {
		delete($rule->{'proto'});
		}
	$rule->{'frag'} = $in{'frag'};
	if ($in{'mssclamp'}) {
		$in{'mss'} =~ /^\d+$/ || &error($text{'nat_emss'});
		$rule->{'mssclamp'} = $in{'mss'};
		}
	else {
		delete($rule->{'mssclamp'});
		}
	if ($in{'oproxy'}) {
		&parse_proxy_input("oproxy");
		}
	else {
		delete($rule->{'oproxyport'});
		}
	}
else {
	# Validate and store redirect inputs
	$rule->{'iface'} = &parse_interface_choice("iface", $text{'nat_eiface'});

	# Save redirect address
	&parse_ipmask_input("from");

	# Save destination ports
	if ($in{'dportsmode'} == 0) {
		&valid_port($in{'dport'}) || &error($text{'nat_edport'});
		$rule->{'dport1'} = $in{'dport'};
		delete($rule->{'dport2'});
		}
	else {
		&valid_port($in{'dport1'}) || &error($text{'nat_edport1'});
		&valid_port($in{'dport2'}) || &error($text{'nat_edport2'});
		$rule->{'dport1'} = $in{'dport1'};
		$rule->{'dport2'} = $in{'dport2'};
		}

	# Save protocol
	$rule->{'rdrproto'} = $in{'rdrproto'};

	# Save redirect IPs
	@ips = split(/\s+/, $in{'rdrip'});
	foreach $ip (@ips) {
		&check_ipaddress($ip) || &error(&text('net_erdrip', $ip));
		}
	@ips || &error($text{'nat_erdrips'});
	$rule->{'rdrip'} = \@ips;

	# Save redirect port
	&valid_port($in{'rdrport'}) || &error($text{'nat_erdrport'});
	$rule->{'rdrport'} = $in{'rdrport'};

	# Save options
	$rule->{'round-robin'} = $in{'round-robin'};
	$rule->{'frag'} = $in{'frag'};
	if ($in{'mssclamp'}) {
		$in{'mss'} =~ /^\d+$/ || &error($text{'nat_emss'});
		$rule->{'mssclamp'} = $in{'mss'};
		}
	else {
		delete($rule->{'mssclamp'});
		}
	}

&lock_file($rule->{'file'});
if ($in{'new'}) {
	if ($in{'before'} ne '') {
		# Insert before some rule
		$before = $rules->[$in{'before'}];
		&insert_rule($rule, $before);
		}
	elsif ($in{'after'} ne '') {
		if ($in{'after'} == @$rules - 1) {
			&create_rule($rule);	# at end anyway
			}
		else {
			# Insert after some rule
			$before = $rules->[$in{'after'}+1];
			&insert_rule($rule, $before);
			}
		}
	else {
		# Append to end
		&create_rule($rule);
		}
	}
else {
	&modify_rule($rule);
	}
&flush_file_lines();
&unlock_file($rule->{'file'});
&copy_to_cluster();
&webmin_log($in{'new'} ? "create" : "modify", "nat", undef, $rule);

&redirect("");

# parse_ipmask_input(prefix)
sub parse_ipmask_input
{
local ($pfx) = @_;
&check_ipaddress($in{$pfx."ip"}) || &error($text{'nat_e'.$pfx.'ip'});
&check_ipaddress($in{$pfx."mask"}) ||
    $in{$pfx."mask"} =~ /^\d+$/ &&
    $in{$pfx."mask"} >= 0 && $in{$pfx."mask"} <= 32 ||
	&error($text{'nat_e'.$pfx.'ip'});
$rule->{$pfx."ip"} = $in{$pfx."ip"};
$rule->{$pfx."mask"} = $in{$pfx."mask"};
}

sub parse_proxy_input
{
local ($pfx) = @_;
&valid_port($in{$pfx."port"}) || &error($text{'nat_e'.$pfx.'port'});
&valid_port($in{$pfx."name"}) || &error($text{'nat_e'.$pfx.'name'});
$rule->{$pfx."port"} = $in{$pfx."port"};
$rule->{$pfx."name"} = $in{$pfx."name"};
$rule->{$pfx."proto"} = $in{$pfx."proto"};
}
