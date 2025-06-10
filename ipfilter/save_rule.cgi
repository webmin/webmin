#!/usr/local/bin/perl
# Update one firewall rule

require './ipfilter-lib.pl';
&ReadParse();
$rules = &get_config();
if (!$in{'new'}) {
	# Get the rule
	$rule = $rules->[$in{'idx'}];
	}
else {
	$rule = { 'file' => $config{'ipf_conf'},
		  'type' => 'ipf' };
	}

if ($in{'delete'}) {
	# Just deleting
	&lock_file($rule->{'file'});
	&delete_rule($rule);
	&flush_file_lines();
	&unlock_file($rule->{'file'});
	&webmin_log("delete", "rule", undef, $rule);
	&redirect("");
	exit;
	}

# Validate and store inputs, starting with action
$rule->{'cmt'} = $in{'cmt'};
$rule->{'active'} = $in{'active'};
$rule->{'action'} = $in{'action'};
if ($rule->{'action'} eq "block") {
	# Parse ICMP block options
	if ($in{'block_return'}) {
		$rule->{'block-return'} = $in{'block_return'};
		$rule->{'block-return-dest'} = $in{'block_return_dest'};
		}
	else {
		$rule->{'block-return'} = undef;
		}
	}
elsif ($rule->{'action'} eq "log") {
	# Parse logging options
	&parse_logging_options("log");
	}
elsif ($rule->{'action'} eq "skip") {
	# Save rule to skip to
	$in{'skip'} =~ /^\d+$/ || &error($text{'save_eskip'});
	$rule->{'skip'} = $in{'skip'};
	}
elsif ($rule->{'action'} eq "call") {
	# Save function to call
	$in{'call'} =~ /^\S+$/ || &error($text{'save_ecall'});
	$rule->{'call'} = $in{'call'};
	$rule->{'call-now'} = $in{'call_now'};
	}

# Parse source and destination
$rule->{'all'} = $in{'all'};
if (!$in{'all'}) {
	&parse_object_input($rule, "from");
	&parse_object_input($rule, "to");
	}

# Parse other conditions
$rule->{'dir'} = $in{'dir'};
$rule->{'proto'} = $in{'proto'};
if ($in{'tos_def'}) {
	delete($rule->{'tos'});
	}
else {
	&valid_hexdec($in{'tos'}) || &error($text{'save_etos'});
	$rule->{'tos'} = $in{'tos'};
	}
if ($in{'ttl_def'}) {
	delete($rule->{'ttl'});
	}
else {
	&valid_hexdec($in{'ttl'}) || &error($text{'save_ettl'});
	$rule->{'ttl'} = $in{'ttl'};
	}
if ($in{'on'} eq "") {
	delete($rule->{'on'});
	}
else {
	$rule->{'on'} = &parse_interface_choice("on", $text{'save_eon'});
	}
if ($in{'flags1_def'}) {
	delete($rule->{'flags1'});
	delete($rule->{'flags2'});
	}
else {
	$in{'flags1'} =~ /^[FSRPAU]+$/ || &error($text{'save_eflags1'});
	$in{'flags2'} =~ /^[FSRPAU]*$/ || &error($text{'save_eflags2'});
	$rule->{'flags1'} = $in{'flags1'};
	$rule->{'flags2'} = $in{'flags2'};
	}
if (!$in{'icmptype'}) {
	delete($rule->{'icmp-type'});
	}
else {
	lc($rule->{'proto'}) eq "icmp" || &error($text{'save_eicmp'});
	$rule->{'icmp-type'} = $in{'icmptype'};
	$rule->{'icmp-type-code'} = $in{'icmpcode'};
	}

# Parse action options
$rule->{'quick'} = $in{'quick'};
$rule->{'olog'} = $in{'olog'};
if ($in{'olog'}) {
	&parse_logging_options("olog");
	}
if ($in{'tag'}) {
	&valid_hexdec($in{'tagid'}) || &error($text{'save_etag'});
	$rule->{'tag'} = $in{'tagid'};
	}
else {
	delete($rule->{'tag'});
	}
if ($in{'dup_to'}) {
	$rule->{'dup-to'} = &parse_interface_choice("dup_toiface",
						    $text{'save_edupto'});
	if ($in{'dup_toip'}) {
		&check_ipaddress($in{'dup_toip'}) ||
			&error($text{'save_eduptoip'});
		$rule->{'dup-to'} .= ":".$in{'dup_toip'};
		}
	}
else {
	delete($rule->{'dup-to'});
	}
if ($in{'fastroute'}) {
	$rule->{'fastroute'} = &parse_interface_choice("fastrouteiface",
						       $text{'save_eto'});
	if ($in{'fastrouteip'}) {
		&check_ipaddress($in{'fastrouteip'}) ||
			&error($text{'save_etoip'});
		}
	$rule->{'fastroute-ip'} = $in{'fastrouteip'};
	}
else {
	delete($rule->{'fastroute'});
	}
if ($in{'reply_to'}) {
	$rule->{'reply-to'} = &parse_interface_choice("reply_toiface",
					   $text{'save_ereplyto'});
	$rule->{'reply-to'} =~ /^[a-z]+\d*/ || &error($text{'save_ereply_to'});
	if ($in{'reply_toip'}) {
		&check_ipaddress($in{'reply_toip'}) ||
			&error($text{'save_ereplytoip'});
		}
	$rule->{'reply-to-ip'} = $in{'reply_toip'};
	}
else {
	delete($rule->{'reply-to'});
	}
if ($in{'keep'}) {
	$rule->{'keep'} = $in{'keepmode'};
	}
else {
	delete($rule->{'keep'});
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
&webmin_log($in{'new'} ? "create" : "modify", "rule", undef, $rule);

&redirect("");

# parse_logging_options(prefix)
sub parse_logging_options
{
local $pfx = $_[0];
if ($in{$pfx."_pri"}) {
	if ($in{$pfx."_fac"}) {
		$rule->{$pfx."-level"} = $in{$pfx."_fac"}.".".$in{$pfx."_pri"};
		}
	else {
		$rule->{$pfx."-level"} = $in{$pfx."_pri"};
		}
	}
else {
	delete($rule->{$pfx."-level"});
	}
$rule->{$pfx."-body"} = $in{$pfx."_body"};
$rule->{$pfx."-first"} = $in{$pfx."_first"};
$rule->{$pfx."-or-block"} = $in{$pfx."_orblock"};
}


