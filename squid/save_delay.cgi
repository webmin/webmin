#!/usr/local/bin/perl
# save_delay.cgi
# Save global delay pool options

require './squid-lib.pl';
$access{'delay'} || &error($text{'delay_ecannot'});
&ReadParse();
&lock_file($config{'squid_conf'});
$conf = &get_config();
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

