#!/usr/local/bin/perl
# save_opts.cgi
# Save global PPTP PPP options

require './pptp-client-lib.pl';
&ReadParse();
&error_setup($text{'opts_err'});

&lock_file($config{'pptp_options'});
@opts = &parse_ppp_options($config{'pptp_options'});
if ($in{'mtu_def'}) {
	&save_ppp_option(\@opts, $config{'pptp_options'}, "mtu", undef);
	}
else {
	$in{'mtu'} =~ /^\d+$/ || &error($text{'opts_emtu'});
	&save_ppp_option(\@opts, $config{'pptp_options'}, "mtu",
			 { 'name' => 'mtu', 'value' => $in{'mtu'} });
	}
if ($in{'mru_def'}) {
	&save_ppp_option(\@opts, $config{'pptp_options'}, "mru", undef);
	}
else {
	$in{'mru'} =~ /^\d+$/ || &error($text{'opts_emru'});
	&save_ppp_option(\@opts, $config{'pptp_options'}, "mru",
			 { 'name' => 'mru', 'value' => $in{'mru'} });
	}
&parse_mppe_options(\@opts, $config{'pptp_options'});
&flush_file_lines();
&unlock_file($config{'pptp_options'});
&webmin_log("opts");

&redirect("");

