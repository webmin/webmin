#!/usr/local/bin/perl
# Save iscsi options

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './iscsi-client-lib.pl';
our (%text, %config, %in);
&ReadParse();
&lock_file($config{'config_file'});
my $conf = &get_iscsi_config();
&error_setup($text{'iscsi_err'});

# Start sessions at boot?
&save_directive($conf, "node.startup",
		$in{'startup'} ? 'automatic' : 'manual');

# Login re-try limit
$in{'retry_def'} || $in{'retry'} =~ /^[1-9]\d*/ ||
	&error($text{'iscsi_eretry'});
&save_directive($conf, "node.session.initial_login_retry_max",
		$in{'retry_def'} ? undef : $in{'retry'});

# Max commands in session queue
$in{'cmds_def'} || $in{'cmds'} =~ /^[1-9]\d*/ ||
	&error($text{'iscsi_ecmds'});
&save_directive($conf, "node.session.cmds_max",
		$in{'cmds_def'} ? undef : $in{'cmds'});

# Device queue depth
$in{'queue_def'} || $in{'queue'} =~ /^[1-9]\d*/ ||
	&error($text{'iscsi_equeue'});
&save_directive($conf, "node.session.queue_depth",
		$in{'queue_def'} ? undef : $in{'queue'});

&flush_file_lines($config{'targets_file'});
&unlock_file($config{'config_file'});
&webmin_log("iscsi");
&redirect("");

