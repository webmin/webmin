#!/usr/local/bin/perl
# Save networking options

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './iscsi-target-lib.pl';
our (%text, %in, %config);
&ReadParse();
&error_setup($text{'addr_err'});
&lock_file($config{'opts_file'});
my $opts = &get_iscsi_options();

# Listen on address
delete($opts->{'a'});
delete($opts->{'address'});
if (!$in{'addr_def'}) {
	&check_ipaddress($in{'addr'}) || &error($text{'addr_eaddr'});
	$opts->{'a'} = $in{'addr'};
	}

# Listen on port
delete($opts->{'p'});
delete($opts->{'port'});
if (!$in{'port_def'}) {
	$in{'port'} =~ /^\d+$/ || &error($text{'addr_eport'});
	$opts->{'p'} = $in{'port'};
	}

# Debug level
delete($opts->{'d'});
delete($opts->{'debug'});
if (!$in{'debug_def'}) {
	$in{'debug'} =~ /^\d+$/ || &error($text{'addr_edebug'});
	$opts->{'d'} = $in{'debug'};
	}

&save_iscsi_options($opts);
&unlock_file($config{'opts_file'});
&webmin_log('addr');
&redirect("");
