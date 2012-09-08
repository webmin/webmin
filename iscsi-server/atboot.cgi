#!/usr/local/bin/perl
# Change if the iscsi server is started at boot or not

use strict;
use warnings;
require './iscsi-server-lib.pl';
&foreign_require("init");
our (%text, %config, %in);
&ReadParse();
&error_setup($text{'atboot_err'});

my $old = &init::action_status($config{'init_name'});
if ($old != 2 && $in{'boot'}) {
	# Enable at boot
	&init::enable_at_boot($config{'init_name'},
		"Start or stop the iSCSI server",
		"$config{'iscsi_server'} -f $config{'targets_file'}",
		"kill `cat $config{'pid_file'}`",
		undef,
		{ 'fork' => 1 },
		);
	&webmin_log("atboot");
	}
elsif ($old == 2 && !$in{'boot'}) {
	# Disable at boot
	&init::disable_at_boot($config{'init_name'});
	&webmin_log("delboot");
	}
&redirect("");
