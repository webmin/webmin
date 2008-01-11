#!/usr/local/bin/perl
# Update, delete or create a host (in both DHCP and DNS)

require './dhcp-dns-lib.pl';
&ReadParse();
&error_setup($text{'save_err'});
@hosts = &list_dhcp_hosts();
if (!$in{'new'}) {
	($host) = grep { $_->{'values'}->[0] eq $in{'old'} } @hosts;
	$host || &error($text{'edit_egone'});
	$par = $host->{'parent'};
	}
else {
	$host = { 'name' => 'host',
		  'type' => 1,
		  'members' => [ ] };
	$par = @hosts ? $hosts[0]->{'parent'}
		      : &dhcpd::get_config_parent();
	}

if ($in{'delete'}) {
	# Remove the DHCP and DNS hosts
	# XXX
	}
else {
	# Validate inputs
	$in{'host'} =~ /^[a-z0-9\.\-]+$/ || &error($text{'save_ehost'});
	if ($in{'indom'}) {
		$in{'host'} .= '.'.$config{'domain'};
		}
	if ($in{'new'} || $in{'host'} ne $in{'old'}) {
		# Check for clash
		($clash) = grep { $_->{'values'}->[0] eq $in{'host'} } @hosts;
		$clash && &error($text{'save_eclash'});
		}
	$host->{'values'} = [ $in{'host'} ];
	&check_ipaddress($in{'ip'}) || &error($text{'save_eip'});
	&dhcpd::save_directive($host, 'fixed-address',
			[ { 'name' => 'fixed-address',
			    'values' => [ $in{'ip'} ] } ]);
	$in{'mac'} =~ /^[a-f0-9:]+$/i || &error($text{'save_emac'});
	&dhcpd::save_directive($host, 'hardware',
			[ { 'name' => 'hardware',
			    'values' => [ $in{'media'}, $in{'mac'} ] } ]);

	if ($in{'new'}) {
		# Add to DNS
		# XXX
		}
	else {
		# Update in DNS
		# XXX
		}

	# Save DHCP host
	&dhcpd::save_directive($par, $in{'new'} ? [ ] : [ $host ],
				[ $host ], $indent);
	&flush_file_lines();
	}
&apply_configuration();
&redirect("");

