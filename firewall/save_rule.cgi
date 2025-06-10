#!/usr/local/bin/perl
# save_rule.cgi
# Save, create or delete a rule in a chain

require './firewall-lib.pl';
&ReadParse();
if (&get_ipvx_version() == 6) {
	require './firewall6-lib.pl';
	}
else {
	require './firewall4-lib.pl';
	}
&error_setup($text{'save_err'});
@tables = &get_iptables_save();
$table = $tables[$in{'table'}];
&can_edit_table($table->{'name'}) || &error($text{'etable'});
if ($in{'new'}) {
	$rule = { 'chain' => $in{'chain'} };
	}
else {
	$rule = $table->{'rules'}->[$in{'idx'}];
	&can_jump($rule) || &error($text{'ejump'});
	}
if ($in{'clone'}) {
	# Go back to the editing page
	&redirect("edit_rule.cgi?version=${ipvx_arg}&new=1&clone=$in{'idx'}&".
		  "table=".&urlize($in{'table'})."&".
		  "after=$in{'idx'}&".
		  "chain=".&urlize($rule->{'chain'}));
	}

&lock_file($ipvx_save);
if ($in{'delete'}) {
	# Just delete this rule
	splice(@{$table->{'rules'}}, $in{'idx'}, 1);
	}
else {
	# Validate and store inputs
	if ($config{'comment_mod'}) {
		$in{'cmt'} =~ s/^\s+//;
		$in{'cmt'} =~ s/\s+$//;
		if ($in{'cmt'}) {
			$rule->{'comment'} = [ "", $in{'cmt'} ];
			push(@mods, "comment");
			}
		else {
			delete($rule->{'comment'});
			}
		}
	else {
		$rule->{'cmt'} = $in{'cmt'};
		delete($rule->{'comment'});
		@mods = grep { $_ ne "comment" } @mods;
		}
	if ($in{'jump'} eq '*') {
		$in{'other'} =~ /^\S+$/ || &error($text{'save_echain'});
		$rule->{'j'} = [ "", $in{'other'} ];
		}
	elsif ($in{'jump'}) {
		$rule->{'j'} = [ "", $in{'jump'} ];
		}
	else {
		delete($rule->{'j'});
		}
	&can_jump($rule) || &error($text{'save_ecanjump'});
	if (defined($in{'rwithtype'})) {
		if ($rule->{'j'}->[1] eq 'REJECT' && !$in{'rwithdef'}) {
			$rule->{'reject-with'} = [ "", $in{'rwithtype'} ];
			}
		else {
			delete($rule->{'reject-with'});
			}
		}

	# Parse redirect or masquerade input
	if ($table->{'name'} eq 'nat') {
		if ($rule->{'j'}->[1] eq 'REDIRECT' && !$in{'rtodef'}) {
			$in{'rtofrom'} =~ /^\d+$/ ||
				&error($text{'save_ertoports'});
			$in{'rtoto'} =~ /^\d*$/ ||
				&error($text{'save_ertoports'});
			$rule->{'to-ports'} = [ "", $in{'rtoto'} eq '' ?
			    $in{'rtofrom'} : $in{'rtofrom'}."-".$in{'rtoto'} ];
			}
		elsif ($rule->{'j'}->[1] eq 'MASQUERADE' && !$in{'mtodef'}) {
			$in{'mtofrom'} =~ /^\d+$/ ||
				&error($text{'save_emtoports'});
			$in{'mtoto'} =~ /^\d*$/ ||
				&error($text{'save_emtoports'});
			$rule->{'to-ports'} = [ "", $in{'mtoto'} eq '' ?
			    $in{'mtofrom'} : $in{'mtofrom'}."-".$in{'mtoto'} ];
			}
		else {
			delete($rule->{'to-ports'});
			}
		}
	if ($table->{'name'} eq 'nat' && $rule->{'chain'} ne 'POSTROUTING') {
		if ($rule->{'j'}->[1] eq 'DNAT' && !$in{'dnatdef'}) {
			!$in{'dipfrom'} || &check_ipvx_ipaddress($in{'dipfrom'})||
				&error($text{'save_edipfrom'});
			!$in{'dipto'} || &check_ipvx_ipaddress($in{'dipto'}) ||
				&error($text{'save_edipto'});
			local $v = $in{'dipfrom'};
			$v .= "-".$in{'dipto'} if ($in{'dipto'});
			if ($in{'dpfrom'} ne '') {
				$in{'dpfrom'} =~ /^\d+$/ ||
					&error($text{'save_edpfrom'});
				$in{'dpto'} =~ /^\d*$/ ||
					&error($text{'save_edpto'});
				if ($in{'dpto'} eq '') {
					$v .= ":".$in{'dpfrom'};
					}
				else {
					$v .= ":".$in{'dpfrom'}."-".$in{'dpto'};
					}
				}
			$rule->{'to-destination'} = [ "", $v ];
			}
		else {
			delete($rule->{'to-destination'});
			}
		}
	if ($table->{'name'} eq 'nat' && $rule->{'chain'} ne 'PREROUTING' &&
	    $rule->{'chain'} ne 'OUTPUT') {
		if ($rule->{'j'}->[1] eq 'SNAT' && !$in{'snatdef'}) {
			(!$in{'sipfrom'} && !$in{'sipto'}) ||
			    &check_ipvx_ipaddress($in{'sipfrom'}) ||
				&error($text{'save_esipfrom'});
			!$in{'sipto'} || &check_ipvx_ipaddress($in{'sipto'}) ||
				&error($text{'save_esipto'});
			local $v = $in{'sipfrom'};
			$v .= "-".$in{'sipto'} if ($in{'sipto'});
			if ($in{'spfrom'} ne '') {
				$in{'spfrom'} =~ /^\d+$/ ||
					&error($text{'save_espfrom'});
				$in{'spto'} =~ /^\d*$/ ||
					&error($text{'save_espto'});
				if ($in{'spto'} eq '') {
					$v .= ":".$in{'spfrom'};
					}
				else {
					$v .= ":".$in{'spfrom'}."-".$in{'spto'};
					}
				}
			$rule->{'to-source'} = [ "", $v ];
			}
		else {
			delete($rule->{'to-source'});
			}
		}
	if (&parse_mode("source", $rule, "s")) {
		&check_ipmask($in{'source'}) || &error($text{'save_esource'});
		$rule->{'s'}->[1] = join(",", split(/[ \t\r\n,]+/, $in{'source'}));
		}
	if (&parse_mode("dest", $rule, "d")) {
		&check_ipmask($in{'dest'}) || &error($text{'save_edest'});
		$rule->{'d'}->[1] = join(",", split(/[ \t\r\n,]+/, $in{'dest'}));
		}
	if (&parse_mode("in", $rule, "i")) {
		$in{'in'} ne '' || $in{'in_other'} =~ /^\S+$/ ||
			&error($text{'save_ein'});
		$rule->{'i'}->[1] = $in{'in'} eq '' || $in{'in'} eq 'other' ?
					$in{'in_other'} : $in{'in'};
		}
	if (&parse_mode("out", $rule, "o")) {
		$in{'out'} ne '' || $in{'out_other'} =~ /^\S+$/ ||
			&error($text{'save_eout'});
		$rule->{'o'}->[1] = $in{'out'} eq '' || $in{'out'} eq 'other' ?
					$in{'out_other'} : $in{'out'};
		}
	if ($in{'frag'} == 0) { delete($rule->{'f'}); }
	elsif ($in{'frag'} == 1) { $rule->{'f'} = [ "" ]; }
	else { $rule->{'f'} = [ "!" ]; }
	if (&parse_mode("proto", $rule, "p")) {
		$in{'proto'} || $in{'proto_other'} =~ /^\d+$/ ||
			&error($text{'save_eproto'});
		$rule->{'p'}->[1] = $in{'proto'} || $in{'proto_other'};
		if (!$rule->{'p'}->[0]) {
			$proto = $in{'proto'};
			push(@mods, $in{'proto'})
				if ($proto eq 'tcp' || $proto eq 'udp' ||
				    $proto eq "icmp${ipvx_icmp}" && $in{'icmptype_mode'});
			}
		}

	if (&parse_mode("sport", $rule, "sport")) {
		$proto eq "tcp" || $proto eq "udp" || $proto eq "sctp" ||
			&error($text{'save_etcpudp'});
		if ($in{"sport_type"} == 0) {
			$in{"sport"} =~ /^\S+$/ ||
				&error($text{'save_esport'});
			if ($in{"sport"} =~ /,/) {
				$rule->{'sports'}->[1] = $in{"sport"};
				$rule->{'sports'}->[0] = $rule->{'sport'}->[0];
				push(@mods, "multiport");
				delete($rule->{'sport'});
				}
			else {
				$rule->{'sport'}->[1] = $in{"sport"};
				delete($rule->{'sports'});
				}
			}
		else {
			$in{"sport_from"} =~ /^\d*$/ ||
				&error($text{'save_esportfrom'});
			$in{"sport_to"} =~ /^\d*$/ ||
				&error($text{'save_esportto'});
			$rule->{'sport'}->[1] = $in{"sport_from"}.":".
						$in{"sport_to"};
			$rule->{'sport'}->[1] eq ":" &&
				&error($text{'save_esportrange'});
			delete($rule->{'sports'});
			}
		}
	else {
		delete($rule->{'sports'});
		}
	if (&parse_mode("dport", $rule, "dport")) {
		$proto eq "tcp" || $proto eq "udp" || $proto eq "sctp" ||
			&error($text{'save_etcpudp'});
		if ($in{"dport_type"} == 0) {
			$in{"dport"} =~ /^\S+$/ ||
				&error($text{'save_edport'});
			if ($in{"dport"} =~ /,/) {
				$rule->{'dports'}->[1] = $in{"dport"};
				$rule->{'dports'}->[0] = $rule->{'dport'}->[0];
				push(@mods, "multiport");
				delete($rule->{'dport'});
				}
			else {
				$rule->{'dport'}->[1] = $in{"dport"};
				delete($rule->{'dports'});
				}
			}
		else {
			$in{"dport_from"} =~ /^\d*$/ ||
				&error($text{'save_edportfrom'});
			$in{"dport_to"} =~ /^\d*$/ ||
				&error($text{'save_edportto'});
			$rule->{'dport'}->[1] = $in{"dport_from"}.":".
						$in{"dport_to"};
			$rule->{'dport'}->[1] eq ":" &&
				&error($text{'save_edportrange'});
			delete($rule->{'dports'});
			}
		}
	else {
		delete($rule->{'dports'});
		}
	if (&parse_mode("ports", $rule, "ports")) {
		$proto eq "tcp" || $proto eq "udp" || $proto eq "sctp" ||
			&error($text{'save_etcpudp'});
		$in{"ports"} =~ /^\S+$/ || &error($text{'save_eports'});
		$rule->{'ports'}->[1] = $in{'ports'};
		push(@mods, "multiport");
		}
	if (&parse_mode("tcpflags", $rule, "tcp-flags")) {
		$proto eq "tcp" || &error($text{'save_etcp1'});
		local $tcp0 = join(",", split(/\0/, $in{"tcpflags0"}));
		local $tcp1 = join(",", split(/\0/, $in{"tcpflags1"}));
		#$tcp0 && $tcp1 || &error($text{'save_etcpflags'});
		$tcp0 || &error($text{'save_etcpflags2'});
		$rule->{'tcp-flags'}->[1] = $tcp0;
		$rule->{'tcp-flags'}->[2] = $tcp1 || "NONE";
		}
	if (&parse_mode("tcpoption", $rule, "tcp-option")) {
		$proto eq "tcp" || &error($text{'save_etcp2'});
		$in{"tcpoption"} =~ /^\d+$/ ||
			&error($text{'save_etcpoption'});
		$rule->{'tcp-option'}->[1] = $in{"tcpoption"};
		}
	if (&parse_mode("icmptype", $rule, "icmp${ipvx_icmp}-type")) {
		$proto eq "icmp${ipvx_icmp}" || &error($text{'save_eicmp'});
		$rule->{"icmp${ipvx_icmp}-type"}->[1] = $in{'icmptype'};
		}
	if (&parse_mode("macsource", $rule, "mac-source")) {
		$in{"macsource"} =~ /^([0-9a-z]{2}:){5}[[0-9a-z]{2}$/i ||
			&error($text{'save_emac'});
		$rule->{'mac-source'}->[1] = $in{'macsource'};
		push(@mods, "mac");
		}
	if (&parse_mode("limit", $rule, "limit")) {
		$in{'limit0'} =~ /^\d+$/ || &error($text{'save_elimit'});
		$rule->{'limit'}->[1] = $in{'limit0'}."/".$in{'limit1'};
		push(@mods, "limit");
		}
	if (&parse_mode("limitburst", $rule, "limit-burst")) {
		$in{'limitburst'} =~ /^\d+$/ ||
			&error($text{'save_elimitburst'});
		$rule->{'limit-burst'}->[1] = $in{'limitburst'};
		push(@mods, "limit");
		}

	if ($rule->{'chain'} eq 'OUTPUT') {
		if (&parse_mode("uidowner", $rule, "uid-owner")) {
			defined(getpwnam($in{"uidowner"})) ||
				&error($text{'save_euidowner'});
			$rule->{'uid-owner'}->[1] = $in{"uidowner"};
			push(@mods, "owner");
			}
		if (&parse_mode("gidowner", $rule, "gid-owner")) {
			defined(getgrnam($in{"gidowner"})) ||
				&error($text{'save_egidowner'});
			$rule->{'gid-owner'}->[1] = $in{"gidowner"};
			push(@mods, "owner");
			}
		if (&parse_mode("pidowner", $rule, "pid-owner")) {
			$in{"pidowner"} =~ /^\d+$/ ||
				&error($text{'save_epidowner'});
			$rule->{'pid-owner'}->[1] = $in{"pidowner"};
			push(@mods, "owner");
			}
		if (&parse_mode("sidowner", $rule, "sid-owner")) {
			$in{"sidowner"} =~ /^\d+$/ ||
				&error($text{'save_esidowner'});
			$rule->{'sid-owner'}->[1] = $in{"sidowner"};
			push(@mods, "owner");
			}
		}

	# Save connection states and TOS
	my $sd = &supports_conntrack() ? "ctstate" : "state";
	my $nonsd = $sd eq "ctstate" ? "state" : "ctstate";
	if (&parse_mode($sd, $rule, $sd)) {
		@states = split(/\0/, $in{$sd});
		@states || &error($text{'save_estates'});
		$rule->{$sd}->[1] = join(",", @states);
		push(@mods, $sd eq "state" ? "state" : "conntrack");
		delete($rule->{$nonsd});
		}
	if (&parse_mode("tos", $rule, "tos")) {
		$rule->{'tos'}->[1] = $in{'tos'};
		push(@mods, "tos");
		}

	# Parse physical input and output interfaces
	if (&parse_mode("physdevin", $rule, "physdev-in")) {
		$in{'physdevin'} ne '' || $in{'physdevin_other'} =~ /^\S+$/ ||
			&error($text{'save_ephysdevin'});
		$rule->{'physdev-in'}->[1] =
		  $in{'physdevin'} eq '' || $in{'physdevin'} eq 'other' ?
			$in{'physdevin_other'} : $in{'physdevin'};
		push(@mods, "physdev");
		}
	if (&parse_mode("physdevout", $rule, "physdev-out")) {
		$in{'physdevout'} ne '' || $in{'physdevout_other'} =~ /^\S+$/ ||
			&error($text{'save_ephysdevout'});
		$rule->{'physdev-out'}->[1] =
		  $in{'physdevout'} eq '' || $in{'physdevout'} eq 'other' ?
			$in{'physdevout_other'} : $in{'physdevout'};
		push(@mods, "physdev");
		}

	# Parse physdev match modes
	if (&parse_mode("physdevisin", $rule, "physdev-is-in")) {
		push(@mods, "physdev");
		}
	if (&parse_mode("physdevisout", $rule, "physdev-is-out")) {
		push(@mods, "physdev");
		}
	if (&parse_mode("physdevisbridged", $rule, "physdev-is-bridged")) {
		push(@mods, "physdev");
		}

	# Parse IPset
	if (&parse_mode("matchset", $rule, "match-set")) {
		$rule->{'match-set'}->[1] = $in{'matchset'};
		$rule->{'match-set'}->[2] = $in{'matchset2'};
		push(@mods, "set");
		}

	# Add custom parameters and modules
	$rule->{'args'} = $in{'args'};
	push(@mods, split(/\s+/, $in{'mods'}));

	# Save the rule
	if (@mods) {
		$rule->{'m'} = [ map { [ "", $_ ] } &unique(@mods) ];
		}
	else {
		delete($rule->{'m'});
		}
	delete($rule->{'j'}) if (!$in{'jump'});
	if ($in{'new'}) {
		if ($in{'before'} ne '') {
			splice(@{$table->{'rules'}}, $in{'before'}, 0, $rule);
			}
		elsif ($in{'after'} ne '') {
			splice(@{$table->{'rules'}}, $in{'after'}+1, 0, $rule);
			}
		else {
			push(@{$table->{'rules'}}, $rule);
			}
		}
	}

# Write out the new save file
&run_before_command();
&save_table($table);
&run_after_command();
&copy_to_cluster();
&unlock_file($ipvx_save);
&webmin_log($in{'delete'} ? "delete" : $in{'new'} ? "create" : "modify",
	    "rule", undef, { 'chain' => $rule->{'chain'},
			     'table' => $table->{'name'} });
&redirect("index.cgi?version=${ipvx_arg}&table=$in{'table'}");

# parse_mode(name, &rule, option)
sub parse_mode
{
if ($in{"$_[0]_mode"} == 0) {
	delete($_[1]->{$_[2]});
	return 0;
	}
elsif ($in{"$_[0]_mode"} == 1) {
	$_[1]->{$_[2]} = [ "" ];
	return 1;
	}
else {
	$_[1]->{$_[2]} = [ "!" ];
	return 1;
	}
}


