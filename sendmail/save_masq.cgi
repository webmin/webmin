#!/usr/local/bin/perl
# save_masq.cgi
# Save domain masquerading

require './sendmail-lib.pl';
&ReadParseMime();
$access{'masq'} || &error($text{'masq_ecannot'});
&error_setup($text{'masq_err'});
&lock_file($config{'sendmail_cf'});
$conf = &get_sendmailcf();
$in{'masq'} =~ /^[A-z0-9\-\.]*$/ ||
	&error(&text('masq_edomain', $in{'masq'}));
@mlist = split(/\s+/, $in{'mlist'});
foreach $m (@mlist) {
	$m =~ /^[A-z0-9\-\.]+$/ ||
		&error(&text('masq_ehost', $m));
	&check_ipaddress($m) &&
		&error(&text('masq_eip', $m));
	}
@mlist = &unique(@mlist);
@nlist = split(/\s+/, $in{'nlist'});
foreach $n (@nlist) {
	$n =~ /^[A-z0-9\-\.]+$/ ||
		&error(&text('masq_ehost', $n));
	&check_ipaddress($n) &&
		&error(&text('masq_eip', $n));
	}
@nlist = &unique(@nlist);

# Update the DM directive (if there is one)
foreach $d (&find_type("D", $conf)) {
	if ($d->{'value'} =~ /^M/) { push(@dmconf, $d); }
	}
&save_directives($conf, \@dmconf,
		 [ { 'type' => 'D', 'values' => [ "M$in{'masq'}" ] } ]);

# Update domains to masquerade, and not to
&save_file_or_config($conf, "M", \@mlist);
&save_file_or_config($conf, "N", \@nlist);
&flush_file_lines();
&unlock_file($config{'sendmail_cf'});

&restart_sendmail();
&webmin_log("masq");
&redirect("");

