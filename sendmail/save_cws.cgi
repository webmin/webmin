#!/usr/local/bin/perl
# save_cws.cgi
# Save sendmail.cw list

require './sendmail-lib.pl';
&ReadParseMime();
$access{'cws'} || &error($text{'cws_ecannot'});
&error_setup($text{'cws_err'});

&lock_file($config{'sendmail_cf'});
$conf = &get_sendmailcf();
&get_file_or_config($conf, "w", undef, \$cwfile);
&lock_file($cwfile) if ($cwfile);
@dlist = split(/\s+/, $in{'dlist'});
foreach $d (@dlist) {
	$d =~ /^[A-z0-9\-\.]+$/ ||
		&error(&text('cws_ehost', $d));
	}
@dlist = &unique(@dlist);

&save_file_or_config($conf, "w", \@dlist);
&flush_file_lines();
&unlock_file($cwfile) if ($cwfile);
&unlock_file($config{'sendmail_cf'});
&restart_sendmail();

&webmin_log("cws");
&redirect("");

