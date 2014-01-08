#!/usr/local/bin/perl
# save_misc.cgi
# Save miscellaneous options

use strict;
use warnings;
our (%text, %in, %access, $squid_version, %config);
require './squid-lib.pl';
$access{'miscopt'} || &error($text{'emisc_ecannot'});
&ReadParse();
&lock_file($config{'squid_conf'});
my $conf = &get_config();
&error_setup($text{'smisc_ftso'});

&save_opt("dns_testnames", undef, $conf);
&save_opt("logfile_rotate", \&check_rotate, $conf);
&save_opt("append_domain", \&check_domain, $conf);
if ($squid_version < 2) {
	&save_opt("ssl_proxy", \&check_proxy, $conf);
	&save_opt("passthrough_proxy", \&check_proxy, $conf);
	}
&save_opt("err_html_text", undef, $conf);
&save_choice("client_db", "on", $conf);
&save_choice("forwarded_for", "on", $conf);
&save_choice("log_icp_queries", "on", $conf);
&save_opt("minimum_direct_hops", \&check_hops, $conf);
if ($squid_version >= 2.2 && $squid_version < 2.5) {
	my $m = $in{'anon_mode'};
	if ($m == 0) {
		&save_directive($conf, "anonymize_headers", [ ]);
		}
	else {
		&save_directive($conf, "anonymize_headers",
			[ { 'name' => 'anonymize_headers',
			    'values' => [ $m == 1 ? "allow" : "deny",
					  $m == 1 ? $in{'anon_allow'}
						  : $in{'anon_deny'} ] } ]);
		}
	}
elsif ($squid_version < 2.2) {
	&save_choice("http_anonymizer", "off", $conf);
	}
&save_opt("fake_user_agent", undef, $conf);
&save_choice("memory_pools", "on", $conf);
if ($squid_version < 2.6) {
	if ($in{'accel'} == 0) {
		&save_directive($conf, "httpd_accel_host", [ ]);
		}
	else {
		my $v = $in{'accel'} == 1 ? "virtual" : $in{"httpd_accel_host"};
		&save_directive($conf, "httpd_accel_host",
				[ { 'name' => "httpd_accel_host",
				    'values' => [$v] } ]);
		}
	&save_opt("httpd_accel_port", undef, $conf);
	&save_choice("httpd_accel_with_proxy", undef, $conf);
	&save_choice("httpd_accel_uses_host_header", undef, $conf);
	if ($squid_version >= 2.5) {
		&save_choice("httpd_accel_single_host", undef, $conf);
		}
	}
if ($squid_version >= 2) {
	&save_opt_bytes("memory_pools_limit", $conf);
	}
if ($squid_version >= 2.3) {
        &save_opt("wccp_router", undef, $conf);
        &save_opt("wccp_incoming_address", undef, $conf);
        &save_opt("wccp_outgoing_address", undef, $conf);
	}
&flush_file_lines();
&unlock_file($config{'squid_conf'});
&webmin_log("misc", undef, undef, \%in);
&redirect("");

sub check_rotate
{
return $_[0] =~ /^\d+$/ ? undef : &text('smisc_emsg1',$_[0]);
}

sub check_domain
{
return $_[0] =~ /^[A-z0-9\.\-]+$/ ? undef : &text('smisc_emsg2',$_[0]); 
}

sub check_proxy
{
return $_[0] =~ /^\S+$/ ? undef : &text('smisc_emsg3',$_[0]); 
}

sub check_hops
{
return $_[0] =~ /^\d+$/ ? undef : &text('smisc_emsg4',$_[0]); 
}

