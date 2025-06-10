#!/usr/local/bin/perl
# Save global timeout options

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './iscsi-target-lib.pl';
our (%text, %in, %config);
&ReadParse();
&error_setup($text{'timeout_err'});
&lock_file($config{'config_file'});
my $pconf = &get_iscsi_config_parent();
my $conf = $pconf->{'members'};

# Time between pings
$in{'nopi_def'} || $in{'nopi'} =~ /^\d+$/ || &error($text{'conn_enopi'});
&save_directive($conf, $pconf, "NOPInterval",
		$in{'nopi_def'} ? [ ] : [ $in{'nopi'} ]);

# Time to respond to ping before disconnecting
$in{'nopt_def'} || $in{'nopt'} =~ /^\d+$/ || &error($text{'conn_enopi'});
&save_directive($conf, $pconf, "NOPTimeout",
		$in{'nopt_def'} ? [ ] : [ $in{'nopt'} ]);

&flush_file_lines($config{'config_file'});
&unlock_file($config{'config_file'});
&webmin_log('timeout');
&redirect("");
