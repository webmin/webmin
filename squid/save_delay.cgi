#!/usr/local/bin/perl
# save_delay.cgi
# Save global delay pool options

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%text, %in, %access, $squid_version, %config);
require './squid-lib.pl';
$access{'delay'} || &error($text{'delay_ecannot'});
&ReadParse();
&lock_file($config{'squid_conf'});
my $conf = &get_config();
&error_setup($text{'delay_err'});

&save_opt("delay_initial_bucket_level", \&check_initial, $conf);
&flush_file_lines();
&unlock_file($config{'squid_conf'});
&webmin_log("delay", undef, undef, \%in);
&redirect("");

sub check_initial
{
return $_[0] =~ /^\d+$/ ? undef : &text('delay_epercent', $_[0]);
}

