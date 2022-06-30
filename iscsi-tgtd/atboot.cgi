#!/usr/local/bin/perl
# Change if the iscsi server is started at boot or not

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './iscsi-tgtd-lib.pl';
&foreign_require("init");
our (%text, %config, %in);
&ReadParse();
&error_setup($text{'atboot_err'});

&setup_tgtd_init();
my $old = &init::action_status($config{'init_name'});
if ($old != 2 && $in{'boot'}) {
	# Enable at boot
	$old == 1 || &error(&text('atboot_einit',
				  "<tt>$config{'init_name'}</tt>"));
	&init::enable_at_boot($config{'init_name'});
	&webmin_log("atboot");
	}
elsif ($old == 2 && !$in{'boot'}) {
	# Disable at boot
	&init::disable_at_boot($config{'init_name'});
	&webmin_log("delboot");
	}
&redirect("");
