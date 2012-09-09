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
	if (!-r $config{'opts_file'}) {
		my $fh = "OPTS";
		&open_tempfile($fh, ">$config{'opts_file'}");
		&close_tempfile($fh);
		}
	&init::enable_at_boot($config{'init_name'},
		"Start or stop the iSCSI server",
		"source $config{'opts_file'} ; $config{'iscsi_server'} -f $config{'targets_file'} \$NETBSD_ISCSI_OPTS",
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
