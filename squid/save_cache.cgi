#!/usr/local/bin/perl
# save_cache.cgi
# Save cache and request options

use strict;
use warnings;
our (%text, %in, %access, $squid_version, %config);
require './squid-lib.pl';
$access{'copts'} || &error($text{'ec_ecannot'});
&ReadParse();
&lock_file($config{'squid_conf'});
my $conf = &get_config();
&error_setup($text{'scache_ftsco'});

if ($in{'cache_dir_def'}) {
	&save_directive($conf, "cache_dir", [ ]);
	}
else {
	my @chd;
	for(my $i=0; defined(my $dir = $in{"cache_dir_$i"}); $i++) {
		if ($squid_version >= 2.4) {
			my $lv1 = $in{"cache_lv1_$i"};
			my $lv2 = $in{"cache_lv2_$i"};
			my $size = $in{"cache_size_$i"};
			my $type = $in{"cache_type_$i"};
			my $opts = $in{"cache_opts_$i"};
			next if (!$dir && !$lv1 && !$lv2 && !$size);
			if ($type ne "coss") {
				&check_error(\&check_dir, $dir);
				}
			&check_error(\&check_dirsize, $size);
			&check_error(\&check_dircount, $lv1);
			&check_error(\&check_dircount, $lv2);
			push(@chd, { 'name' => 'cache_dir',
				     'values' => [ $type, $dir, $size,
						   $lv1, $lv2, $opts ] });
			}
		elsif ($squid_version >= 2.3) {
			my $lv1 = $in{"cache_lv1_$i"};
			my $lv2 = $in{"cache_lv2_$i"};
			my $size = $in{"cache_size_$i"};
			my $type = $in{"cache_type_$i"};
			next if (!$dir && !$lv1 && !$lv2 && !$size);
			&check_error(\&check_dir, $dir);
			&check_error(\&check_dirsize, $size);
			&check_error(\&check_dircount, $lv1);
			&check_error(\&check_dircount, $lv2);
			push(@chd, { 'name' => 'cache_dir',
				     'values' => [ $type, $dir, $size,
						   $lv1, $lv2 ] });
			}
		elsif ($squid_version >= 2) {
			my $lv1 = $in{"cache_lv1_$i"};
			my $lv2 = $in{"cache_lv2_$i"};
			my $size = $in{"cache_size_$i"};
			next if (!$dir && !$lv1 && !$lv2 && !$size);
			&check_error(\&check_dir, $dir);
			&check_error(\&check_dirsize, $size);
			&check_error(\&check_dircount, $lv1);
			&check_error(\&check_dircount, $lv2);
			push(@chd, { 'name' => 'cache_dir',
				     'values' => [ $dir, $size, $lv1, $lv2 ] });
			}
		else {
			next if (!$dir);
			&check_error(\&check_dir, $dir);
			push(@chd, { 'name' => 'cache_dir',
				     'values' => [ $dir ] });
			}
		}
	if (!@chd) {
		&error($text{'scache_emsg0'});
		}
	&save_directive($conf, "cache_dir", \@chd);
	}
if ($squid_version < 2) {
	&save_opt("swap_level1_dirs", \&check_dircount, $conf);
	&save_opt("swap_level2_dirs", \&check_dircount, $conf);
	&save_opt("store_avg_object_size", \&check_objsize, $conf);
	}
else {
	&save_opt_bytes("store_avg_object_size", $conf);
	}
&save_opt("store_objects_per_bucket", \&check_bucket, $conf);
if ($squid_version < 2) {
	&save_list("cache_stoplist", undef, $conf);
	&save_list("cache_stoplist_pattern", undef, $conf);
	}
my @noch = split(/\0/, $in{'no_cache'});
my $nochname = $squid_version >= 2.6 ? 'cache' : 'no_cache';
my @nc;
if (@noch) {
	$nc[0] = { 'name' => $nochname,
		   'values' => [ "deny", @noch ] };
	}
&save_directive($conf, $nochname, \@nc, "acl");
&save_opt_time("reference_age", $conf);
if ($squid_version < 2) {
	&save_opt("request_size", \&check_size, $conf);
	&save_opt("negative_ttl", \&check_ttl, $conf);
	&save_opt("positive_dns_ttl", \&check_dns_ttl, $conf);
	&save_opt("negative_dns_ttl", \&check_dns_ttl, $conf);
	}
else {
	if ($squid_version >= 2.3) {
		&save_opt_bytes("request_body_max_size", $conf);
		&save_opt_bytes("request_header_max_size", $conf);
		if ($squid_version < 2.5) {
			&save_opt_bytes("reply_body_max_size", $conf);
			}
		else {
			&save_opt_bytes("read_ahead_gap", $conf);
			}
		}
	else {
		&save_opt_bytes("request_size", $conf);
		}
	&save_opt_time("negative_ttl", $conf);
	&save_opt_time("positive_dns_ttl", $conf);
	&save_opt_time("negative_dns_ttl", $conf);
	}
if ($squid_version >= 2.5) {
	# Parse list of max reply body sizes
	my @rbms;
	for(my $i=0; defined(my $s = $in{"reply_body_max_size_$i"}); $i++) {
		next if ($s eq "");
		&error(&text('scache_emaxrs', $i+1)) if ($s !~ /^\d+$/);
		my @a = split(/\s+/, $in{"reply_body_max_acls_$i"});
		push(@rbms, { 'name' => 'reply_body_max_size',
			      'values' => [ $s, @a ] });
		}
	&save_directive($conf, "reply_body_max_size", \@rbms);
	}
if ($squid_version < 2) {
	&save_opt("connect_timeout", \&check_timeout, $conf);
	&save_opt("read_timeout", \&check_timeout, $conf);
	&save_opt("client_lifetime", \&check_lifetime, $conf);
	&save_opt("shutdown_lifetime", \&check_lifetime, $conf);
	}
else {
	&save_opt_time("connect_timeout", $conf);
	&save_opt_time("read_timeout", $conf);
	&save_opt_time("siteselect_timeout", $conf);
	&save_opt_time("request_timeout", $conf);
	&save_opt_time("client_lifetime", $conf);
	&save_opt_time("shutdown_lifetime", $conf);
	&save_choice("half_closed_clients", "on", $conf);
	&save_opt_time("pconn_timeout", $conf);
	}
if ($squid_version >= 2) {
	&save_opt("wais_relay_host", \&check_host, $conf);
	&save_opt("wais_relay_port", \&check_port, $conf);
	}

&flush_file_lines();
&unlock_file($config{'squid_conf'});
&webmin_log("cache", undef, undef, \%in);
&redirect("");

sub check_dir
{
return (-d $_[0]) ? undef : &text('scache_emsg1',$_[0]);
}

sub check_size
{
return $_[0] =~ /^\d+$/ ? undef : &text('scache_emsg2',$_[0]);
}

sub check_ttl
{
return $_[0] =~ /^\d+$/ ? undef
			: &text('scache_emsg3',$_[0]);
}

sub check_dns_ttl
{
return $_[0] =~ /^\d+$/ ? undef : &text('scache_emsg4',$_[0]);
}

sub check_timeout
{
return $_[0] =~ /^\d+$/ ? undef : &text('scache_emsg5',$_[0]);
}

sub check_lifetime
{
return $_[0] =~ /^\d+$/ ? undef : &text('scache_emsg6',$_[0]);
}

sub check_dircount
{
return $_[0] !~ /^\d+$/ ? &text('scache_emsg7',$_[0]) : 
       $_[0] < 1 ? $text{'scache_emsg8'} :
       $_[0] > 256 ? $text{'scache_emsg9'} : undef;
    
}

sub check_objsize
{
return $_[0] =~ /^\d+/ ? undef : &text('scache_emsg10',$_[0]);
}

sub check_bucket
{
return $_[0] =~ /^\d+$/ ? undef : &text('scache_emsg11',$_[0]);
}

sub check_dirsize
{
return $_[0] =~ /^\d+$/ ? undef : &text('scache_emsg12',$_[0]);
}

sub check_host
{
return &to_ipaddress($_[0]) || &to_ip6address($_[0]) ? undef
		: &text('scache_emsg13',$_[0]);
}

sub check_port
{
return $_[0] =~ /^\d+$/ ? undef : &text('scache_emsg14',$_[0]);
}

