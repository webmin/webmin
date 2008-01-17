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
		&dhcpd::save_directive($host->{'parent'}, [ $host ], [ ], $indent);
		}
	($fn, $recs) = &get_dns_zone();
	($old) = grep { lc($_->{'name'}) eq lc($d).'.' } @$recs;
	if ($old) {
		&bind8::delete_record($fn, $old);
		&bind8::bump_soa_record($fn, $recs);
		}
	}

# Apply config
&flush_file_lines();
&redirect("");
