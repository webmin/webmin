#!/usr/local/bin/perl
# save_trusts.cgi
# Save trusted users list

require './sendmail-lib.pl';
&ReadParseMime();
$access{'trusts'} || &error($text{'trusts_ecannot'});
&error_setup($text{'trusts_err'});
&lock_file($config{'sendmail_cf'});
$conf = &get_sendmailcf();
@tlist = split(/\s+/, $in{'tlist'});
foreach $u (@tlist) {
	@uinfo = getpwnam($u);
	@uinfo || &error(&text('trusts_euser', $u));
	}
@tlist = &unique(@tlist);

# Update trusted users
&save_file_or_config($conf, "t", \@tlist, "T");

&unlock_file($config{'sendmail_cf'});
&restart_sendmail();
&webmin_log("trusts");
&redirect("");

