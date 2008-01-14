#!/usr/local/bin/perl
# Update, delete or create a host (in both DHCP and DNS)

require './dhcp-dns-lib.pl';
&ReadParse();
&error_setup($text{'save_err'});
@hosts = &list_dhcp_hosts();
($fn, $recs) = &get_dns_zone();
if (!$in{'new'}) {
	($host) = grep { $_->{'values'}->[0] eq $in{'old'} } @hosts;
	$host || &error($text{'edit_egone'});
	$par = $host->{'parent'};
	}
else {
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
	($old) = grep { $_->{'name'} eq $in{'old'}.'.' } @$recs;
	if ($old) {
		&bind8::delete_record($fn, $old);
		&bind8::bump_soa_record($fn, $recs);
		}
	}
else {
	# Validate inputs
	$in{'host'} =~ /^[a-z0-9\.\-]+$/ || &error($text{'save_ehost'});
	if ($in{'indom'}) {
		$in{'host'} .= '.'.$config{'domain'};
		}
	if ($in{'new'} || $in{'host'} ne $in{'old'}) {
		# Check for hostname clash
		($clash) = grep { $_->{'values'}->[0] eq $in{'host'} } @hosts;
		$clash && &error($text{'save_eclash'});
		}
	$host->{'values'} = [ $in{'host'} ];

	&check_ipaddress($in{'ip'}) || &error($text{'save_eip'});
	if ($in{'new'} || $in{'ip'} ne $in{'oldip'}) {
		# Check for IP clash
		($clash) = grep { my $f = &dhcpd::find("fixed-address", $_->{'members'}); $f->{'values'}->[0] eq $in{'ip'} } @hosts;
		$clash && &error($text{'save_eclaship'});
		}
	&dhcpd::save_directive($host, 'fixed-address',
			[ { 'name' => 'fixed-address',
			    'values' => [ $in{'ip'} ] } ]);

	$in{'mac'} =~ /^[a-f0-9:]+$/i || &error($text{'save_emac'});
	if ($in{'new'} || $in{'mac'} ne $in{'oldmac'}) {
		# Check for MAC clash
		($clash) = grep { my $h = &dhcpd::find("hardware", $_->{'members'}); $h->{'values'}->[1] eq $in{'mac'} } @hosts;
		$clash && &error($text{'save_eclaship'});
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
		($old) = grep { $_->{'name'} eq $in{'old'}.'.' } @$recs;
		if ($old) {
			&bind8::modify_record($fn, $old, $in{'host'}.'.',
					      $old->{'ttl'}, $old->{'class'},
					      $old->{'type'}, $in{'ip'});
			}
		}
	&bind8::bump_soa_record($fn, $recs);

	# Save DHCP host
	&dhcpd::save_directive($par, $in{'new'} ? [ ] : [ $host ],
				[ $host ], $indent);
	}
&flush_file_lines();
&apply_configuration();
&redirect("");

