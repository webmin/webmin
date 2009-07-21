#!/usr/local/bin/perl
# Delete multiple hosts

require './dhcp-dns-lib.pl';
&ReadParse();
&error_setup($text{'delete_err'});
@d = split(/\0/, $in{'d'});
@d || &error($text{'delete_enone'});

# Do each host
@hosts = &list_dhcp_hosts();
foreach $d (@d) {
	($host) = grep { $_->{'values'}->[0] eq $d } @hosts;
	if ($host) {
		$fixed = &dhcpd::find("fixed-address", $host->{'members'});
		&dhcpd::save_directive($host->{'parent'}, [ $host ], [ ], $indent);
		}
	else {
		$fixed = undef;
		}
	($fn, $recs) = &get_dns_zone();
	($old) = grep { lc($_->{'name'}) eq lc($d).'.' } @$recs;
	if (!$old) {
		# Search by hostname only
		($old) = grep { lc($_->{'name'}) eq
				lc($d).'.'.lc($config{'domain'}).'.' } @$recs;
		}
	if ($old) {
		&bind8::delete_record($fn, $old);
		&bind8::bump_soa_record($fn, $recs);
		}
	if ($fixed) {
		($rfn, $rrecs, $arpa, $rzone) = &get_reverse_dns_zone(
							$fixed->{'values'}->[0]);
		if ($rfn) {
			($old) = grep { $_->{'name'} eq $arpa."." } @$rrecs;
			if ($old) {
				&bind8::delete_record($rfn, $old);
				&bind8::bump_soa_record($rfn, $rrecs);
				}
			}
		}
	}

# Apply config
&flush_file_lines();
&redirect("");
