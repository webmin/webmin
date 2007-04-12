#!/usr/local/bin/perl
# save_conf.cgi
# Save PPTP server settings

require './pptp-server-lib.pl';
$access{'conf'} || &error($text{'conf_ecannot'});
&ReadParse();
&error_setup($text{'conf_err'});

# Validate and store inputs
&lock_file($config{'file'});
$conf = &get_config();
if ($in{'speed_def'}) {
	&save_directive($conf, "speed");
	}
else {
	$in{'speed'} =~ /^\d+$/ || &error($text{'conf_espeed'});
	&save_directive($conf, "speed", $in{'speed'});
	}

if ($in{'listen_def'}) {
	&save_directive($conf, "listen");
	}
else {
	&check_ipaddress($in{'listen'}) || &error($text{'conf_elisten'});
	&save_directive($conf, "listen", $in{'listen'});
	}

if ($in{'mode'} == 0) {
	&save_directive($conf, "option");
	}
elsif ($in{'mode'} == 1) {
	&save_directive($conf, "option", $options_pptp);
	}
else {
	$in{'option'} =~ /^\/\S+$/ || &error($text{'conf_eoption'});
	&save_directive($conf, "option", $in{'option'});
	}

&save_ip_table("localip");

&save_ip_table("remoteip");

if ($in{'ipxnets_def'}) {
	&save_directive($conf, "ipxnets");
	}
else {
	$in{'from'} =~ /^[A-F0-9]+$/ || &error($text{'conf_efrom'});
	$in{'to'} =~ /^[A-F0-9]+$/ || &error($text{'conf_eto'});
	&save_directive($conf, "ipxnets", $in{'from'}."-".$in{'to'});
	}

&flush_file_lines();
&unlock_file($config{'file'});
&webmin_log("conf");
&redirect("");

# save_ip_table(name)
sub save_ip_table
{
local @ips = split(/\s+/, $in{$_[0]});
foreach $i (@ips) {
	&check_ipaddress($i) || $i =~ /^(\d+)\.(\d+)\.(\d+)\.(\d+)-(\d+)$/ ||
		&error(&text('conf_e'.$_[0], $i));
	}
&save_directive($conf, $_[0], @ips ? join(",", @ips) : undef);
}

