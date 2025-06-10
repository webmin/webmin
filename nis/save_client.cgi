#!/usr/local/bin/perl
# save_client.cgi
# Save and apply NIS client options

require './nis-lib.pl';
&ReadParse();
&error_setup($text{'client_err'});

# Parse and validate inputs
if (!$in{'domain_def'}) {
	$in{'domain'} =~ /^[A-Za-z0-9\.\-]+$/ ||
		&error($text{'client_edomain'});
	$nis->{'domain'} = $in{'domain'};
	}
if ($in{'broadcast'}) {
	$nis->{'broadcast'} = 1;
	}
else {
	@servers = split(/\s+/, $in{'servers'});
	foreach $s (@servers) {
		&to_ipaddress($s) || &to_ip6address($s) ||
			&error(&text('client_eserver', $s));
		}
	$nis->{'servers'} = \@servers;
	}

# Save and apply
$err = &save_client_config($nis);
if ($err) { &error($err); }
&redirect("");

