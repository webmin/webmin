#!/usr/local/bin/perl
# Save global connection related options

use strict;
use warnings;
require './iscsi-target-lib.pl';
our (%text, %in, %config);
&ReadParse();
&error_setup($text{'conn_err'});
&lock_file($config{'config_file'});
my $pconf = &get_iscsi_config_parent();
my $conf = $pconf->{'members'};

# Max sessions per target
$in{'sessions_def'} || $in{'sessions'} =~ /^\d+$/ ||
	&error($text{'conn_esessions'});
&save_directive($conf, $pconf, "MaxSessions",
		$in{'sessions_def'} ? [ ] : [ $in{'sessions'} ]);

# Allow initiator to send data with command?
&save_directive($conf, $pconf, "InitialR2T",
		[ $in{'initial'} ? "Yes" : "No" ]);

# Allow initiator to send data immediately?
&save_directive($conf, $pconf, "ImmediateData",
		[ $in{'immediate'} ? "Yes" : "No" ]);

# Various data lengths
foreach my $fv ([ "MaxRecvDataSegmentLength", "maxrecv" ],
		[ "MaxXmitDataSegmentLength", "maxxmit" ],
		[ "MaxBurstLength", "maxburst" ],
		[ "FirstBurstLength", "firstburst" ]) {
	if ($in{$fv->[1]."_def"}) {
		&save_directive($conf, $pconf, $fv->[0], [ ]);
		}
	else {
		$in{$fv->[1]} =~ /^\d+$/ || &error($text{'conn_e'.$fv->[1]});
		&save_directive($conf, $pconf, $fv->[0], [ $in{$fv->[1]} ]);
		}
	}

&flush_file_lines($config{'config_file'});
&unlock_file($config{'config_file'});
&webmin_log('conn');
&redirect("");
