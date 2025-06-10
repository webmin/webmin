#!/usr/local/bin/perl
# save_cgs.cgi
# Save sendmail.cg list

require './sendmail-lib.pl';
&ReadParseMime();
$access{'cgs'} || &error($text{'cgs_ecannot'});
&error_setup($text{'cgs_err'});
&lock_file($config{'sendmail_cf'});
$conf = &get_sendmailcf();
@dlist = split(/\s+/, $in{'dlist'});
foreach $d (@dlist) {
	$d =~ /^[A-z0-9\-\.]+$/ ||
		&error(&text('cgs_ehost', $d));
	&check_ipaddress($d) &&
		&error(&text('cgs_eip', $d));
	}
@dlist = &unique(@dlist);

# Update outgoing domains
&save_file_or_config($conf, "G", \@dlist);
&flush_file_lines();

&unlock_file($config{'sendmail_cf'});
&restart_sendmail();
&webmin_log("cgs");
&redirect("");

