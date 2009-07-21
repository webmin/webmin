#!/usr/local/bin/perl
# Update, delete or create a host (in both DHCP and DNS)

require './dhcp-dns-lib.pl';
&ReadParse();
&error_setup($text{'save_err'});
@hosts = &list_dhcp_hosts();
($fn, $recs) = &get_dns_zone();
if (!$in{'new'}) {
	# Get existing host object and DNS record
	($host) = grep { $_->{'values'}->[0] eq $in{'old'} } @hosts;
	$host || &error($text{'edit_egone'});
	$oldpar = $host->{'parent'};
	($old) = grep { lc($_->{'name'}) eq lc($in{'old'}).'.' } @$recs;
	if (!$old) {
		($old) = grep { lc($_->{'name'}) eq
			lc($in{'old'}).'.'.lc($config{'domain'}).'.' } @$recs;
		}
	if ($in{'subnet'} eq $in{'oldsubnet'}) {
		$par = $oldpar;
		}
	else {
		# Moving subnet
		($par) = grep { $_->{'values'}->[0] eq $in{'subnet'} }
			      &list_dhcp_subnets();
		}
	}
else {
	# Create new, and work out parent
	$host = { 'name' => 'host',
		  'type' => 1,
		  'members' => [ ] };
	if ($in{'subnet'}) {
		# Add to subnet selected
		($par) = grep { $_->{'values'}->[0] eq $in{'subnet'} }
			      &list_dhcp_subnets();
		}
	else {
		if (@hosts && $hosts[0]->{'parent'}->{'name'} ne 'subnet') {
			# Where other hosts are
			$par = $hosts[0]->{'parent'};
			}
		else {
			# Top level
			$par = &dhcpd::get_config_parent();
			}
		}
	}

if ($in{'delete'}) {
	# Remove the DHCP and DNS hosts
	&dhcpd::save_directive($par, [ $host ], [ ], $indent);
	if ($old) {
		&bind8::delete_record($fn, $old);
		&bind8::bump_soa_record($fn, $recs);
		}
	($rfn, $rrecs, $arpa, $rzone) = &get_reverse_dns_zone($in{'oldip'});
	if ($rfn) {
		($old) = grep { $_->{'name'} eq $arpa."." } @$rrecs;
		if ($old) {
			&bind8::delete_record($rfn, $old);
			&bind8::bump_soa_record($rfn, $rrecs);
			}
		}
	}
else {
	# Validate inputs
	$host->{'comment'} = $in{'comment'};
	$in{'host'} =~ /^[a-zA-Z0-9\.\-]+$/ || &error($text{'save_ehost'});
	if ($in{'indom'}) {
		$in{'host'} .= '.'.$config{'domain'};
		}
	if ($in{'new'} || lc($in{'host'}) ne lc($in{'old'})) {
		# Check for hostname clash
		($clash) = grep { lc($_->{'values'}->[0]) eq lc($in{'host'}) }
				@hosts;
		$clash && &error($text{'save_eclash'});
		}
	$host->{'values'} = [ $in{'host'} ];

	&check_ipaddress($in{'ip'}) || &error($text{'save_eip'});
	if ($in{'new'} || $in{'ip'} ne $in{'oldip'}) {
		# Check for IP clash
		($clash) = grep { my $f = &dhcpd::find("fixed-address", $_->{'members'}); $f->{'values'}->[0] eq $in{'ip'} } @hosts;
		$clash && &error(&text('save_eclaship',
				       $clash->{'values'}->[0]));
		}
	&dhcpd::save_directive($host, 'fixed-address',
			[ { 'name' => 'fixed-address',
			    'values' => [ $in{'ip'} ] } ]);

	$in{'mac'} =~ /^[a-fA-F0-9:]+$/i || &error($text{'save_emac'});
	if ($in{'new'} || lc($in{'mac'}) ne lc($in{'oldmac'})) {
		# Check for MAC clash
		($clash) = grep { my $h = &dhcpd::find("hardware", $_->{'members'}); lc($h->{'values'}->[1]) eq lc($in{'mac'}) } @hosts;
		$clash && &error(&text('save_eclashmac',
				       $clash->{'values'}->[0]));
		}
	&dhcpd::save_directive($host, 'hardware',
			[ { 'name' => 'hardware',
			    'values' => [ $in{'media'}, $in{'mac'} ] } ]);

	if ($in{'new'}) {
		# Add to DNS
		&bind8::create_record($fn, $in{'host'}.'.', undef, "IN",
				      "A", $in{'ip'});
		}
	else {
		# Update in DNS
		if ($old) {
			&bind8::modify_record($fn, $old, $in{'host'}.'.',
					      $old->{'ttl'}, $old->{'class'},
					      $old->{'type'}, $in{'ip'});
			}
		}
	&bind8::bump_soa_record($fn, $recs);

	if ($in{'new'}) {
		# Add reverse record to DNS
		($rfn, $rrecs, $arpa, $rzone) = &get_reverse_dns_zone($in{'ip'});
		if ($rfn) {
			&bind8::create_record($rfn, $arpa.".", undef, "IN",
					      "PTR", $in{'host'}.'.');
			}
		}
	elsif ($in{'ip'} ne $in{'oldip'} ||
	       $in{'host'} ne $in{'old'}) {
		($orfn, $orrecs, $oarpa, $orzone) = &get_reverse_dns_zone(
			$in{'oldip'});
		($rfn, $rrecs, $arpa, $rzone) = &get_reverse_dns_zone(
			$in{'ip'});
		if ($orfn) {
			($old) = grep { $_->{'name'} eq $oarpa."." } @$orrecs;
			}
		else {
			$old = undef;
			}
		if ($orzone && !$rzone && $old) {
			# No longer exists
			&bind8::delete_record($orfn, $old);
			}
		elsif (!$orzone && $rzone) {
			# Create in new reverse zone
			&bind8::create_record($rfn, $arpa.".", undef, "IN",
					      "PTR", $in{'host'}.'.');
			}
		elsif ($orzone ne $rzone && $old) {
			# Move to new reverse zone
			&bind8::delete_record($orfn, $old);
			&bind8::create_record($rfn, $arpa.".", undef, "IN",
					      "PTR", $in{'host'}.'.');
			}
		elsif ($old) {
			# Update in this one
			&bind8::modify_record($rfn, $old, $arpa.".",
				$old->{'ttl'}, $old->{'class'}, $old->{'type'},
				$in{'host'}.'.');
			}
		}
	&bind8::bump_soa_record($rfn, $rrecs) if ($rfn);
	&bind8::bump_soa_record($orfn, $orrecs) if ($orfn);

	# Save DHCP host
	if (!$in{'new'} && $oldpar ne $par) {
		# Move to new parent
		&dhcpd::save_directive($oldpar, [ $host ], [ ], 0);
		&dhcpd::save_directive($par, [ ], [ $host ], $indent);
		}
	else {
		# Just save
		&dhcpd::save_directive($par, $in{'new'} ? [ ] : [ $host ],
					[ $host ], $indent);
		}
	}
&flush_file_lines();
&redirect("");

