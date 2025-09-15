#!/usr/local/bin/perl
# save dnssec-tools related options
use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%access, %text, %in, %config);
our $module_config_file;

require './bind8-lib.pl';

&ReadParse();
&error_setup($text{'dt_conf_err'});
$access{'defaults'} || &error($text{'dt_conf_ecannot'});

my $conf = get_dnssectools_config();
my %nv;

$in{'dt_email'} =~ /(\b[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+\.[A-Za-z0-9-.]*\b)/ || 
	&error($text{'dt_conf_eemail'});
$nv{'admin-email'} = $1;

$in{'dt_alg'} =~ /(\b[A-Za-z0-9]+\b)/ || 
	&error($text{'dt_conf_ealg'});
$nv{'algorithm'} = $1;

$in{'dt_ksklen'} =~ /(\b[0-9]+\b)/ || 
	&error($text{'dt_conf_eksklen'});
$nv{'ksklength'} = $1;

$in{'dt_zsklen'} =~ /(\b[0-9]+\b)/ || 
	&error($text{'dt_conf_ezsklen'});
$nv{'zsklength'} = $1;

$in{'dt_nsec3'} =~ /(\b(yes|no)\b)/i || 
	&error($text{'dt_conf_ensec3'});
$nv{'usensec3'} = $1;

$in{'dt_endtime'} =~ /(\+?[0-9]+)/ || 
	&error($text{'dt_conf_eendtime'});
$nv{'endtime'} = $1;

$in{'dt_ksklife'} =~ /(\b[0-9]+\b)/  || 
	&error($text{'dt_conf_eksklife'});
$nv{'ksklife'} = $1;

$in{'dt_zsklife'} =~ /(\b[0-9]+\b)/  || 
	&error($text{'dt_conf_ezsklife'});
$nv{'zsklife'} = $1;

$in{'period'} =~ /^[1-9]\d*$/ || &error($text{'dnssec_eperiod'});
$in{'period'} < 30 || &error($text{'dnssec_eperiod30'});

&save_dnssectools_directive($conf, \%nv);

&lock_file($module_config_file);
$config{'dnssec_period'} = $in{'period'};
&save_module_config();
&unlock_file($module_config_file);

&webmin_log("dnssectools");
&redirect("");
