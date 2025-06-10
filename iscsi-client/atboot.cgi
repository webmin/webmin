#!/usr/local/bin/perl
# Change if the iscsi client is started at boot or not

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './iscsi-client-lib.pl';
&foreign_require("init");
our (%text, %config, %in);
&ReadParse();
&error_setup($text{'atboot_err'});

my @inits = split(/\s+/, $config{'init_name'});

if ($in{'boot'}) {
	# Enable at boot
	foreach my $i (@inits) {
		my $old = &init::action_status($i);
		$old || &error(&text('atboot_einit', $i));
		&init::enable_at_boot($i);
		}
	&webmin_log("atboot");
	}
else {
	# Disable at boot
	foreach my $i (@inits) {
		&init::disable_at_boot($i);
		}
	&webmin_log("delboot");
	}
&redirect("");
