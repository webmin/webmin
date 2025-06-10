#!/usr/local/bin/perl
# save_mem.cgi
# Save memory usage options

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%text, %in, %access, $squid_version, %config);
require './squid-lib.pl';
$access{'musage'} || &error($text{'emem_ecannot'});
&ReadParse();
&lock_file($config{'squid_conf'});
my $conf = &get_config();
&error_setup($text{'smem_ftsmo'});

if ($squid_version < 2) {
	&save_opt("cache_mem", \&check_size, $conf);
	&save_opt("cache_swap", \&check_size, $conf);
	}
else {
	&save_opt_bytes("cache_mem", $conf);
	&save_opt("fqdncache_size", \&check_size, $conf);
	}
if ($squid_version < 2.5) {
	&save_opt("cache_mem_high", \&check_high, $conf);
	&save_opt("cache_mem_low", \&check_low, $conf);
	}
&save_opt("cache_swap_high", \&check_high, $conf);
&save_opt("cache_swap_low", \&check_low, $conf);
if ($squid_version < 2) {
	&save_opt("maximum_object_size", \&check_obj_size, $conf);
	}
else {
	&save_opt_bytes("maximum_object_size", $conf);
	}
&save_opt("ipcache_size", \&check_size, $conf);
&save_opt("ipcache_high", \&check_high, $conf);
&save_opt("ipcache_low", \&check_low, $conf);
if ($squid_version >= 2.4) {
	&save_choice("cache_replacement_policy", '', $conf);
	&save_choice("memory_replacement_policy", '', $conf);
	}
&flush_file_lines();
&unlock_file($config{'squid_conf'});
&webmin_log("mem", undef, undef, \%in);
&redirect("");

sub check_size
{
return $_[0] =~ /^\d+$/ ? undef : &text('smem_emsg1',$_[0]);
}

sub check_high
{
return $_[0] =~ /^\d+$/ && $_[0] > 0 && $_[0] <= 100
		? undef : &text('smem_emsg2',$_[0]);
}

sub check_low
{
return $_[0] =~ /^\d+$/ && $_[0] > 0 && $_[0] <= 100
		? undef : &text('smem_emsg3',$_[0]);
}

sub check_obj_size
{
return $_[0] =~ /^\d+$/ ? undef : &text('smem_emsg4',$_[0]);
}

