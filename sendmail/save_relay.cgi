#!/usr/local/bin/perl
# save_relay.cgi
# Save relay domains list

require './sendmail-lib.pl';
&ReadParseMime();
$access{'relay'} || &error($text{'relay_ecannot'});
&error_setup($text{'relay_err'});
&lock_file($config{'sendmail_cf'});

$conf = &get_sendmailcf();
&get_file_or_config($conf, "r", undef, \$rfile);
&lock_file($rfile) if ($rfile);
@dlist = split(/\s+/, $in{'dlist'});
foreach $d (@dlist) {
	$d =~ /^[A-z0-9\-\.]+$/ ||
		&error(&text('relay_edomain', $d));
	}
@dlist = &unique(@dlist);

# Save relay domains
&save_file_or_config($conf, "R", \@dlist);

&flush_file_lines();
&unlock_file($config{'sendmail_cf'});
&unlock_file($rfile) if ($rfile);
&restart_sendmail();
&webmin_log("relay");
&redirect("");

