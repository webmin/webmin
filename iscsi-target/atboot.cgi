#!/usr/local/bin/perl
# Change if the iscsi server is started at boot or not

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './iscsi-target-lib.pl';
&foreign_require("init");
our (%text, %config, %in);
&ReadParse();
&error_setup($text{'atboot_err'});

# On Debian, a flag needs to be set in /etc/default/iscsitarget
if ($in{'boot'}) {
	&lock_file($config{'opts_file'});
	my %env;
	&read_env_file($config{'opts_file'}, \%env);
	if (lc($env{'ISCSITARGET_ENABLE'}) eq 'false') {
		$env{'ISCSITARGET_ENABLE'} = 'true';
		&write_env_file($config{'opts_file'}, \%env);
		}
	&unlock_file($config{'opts_file'});
	}

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
