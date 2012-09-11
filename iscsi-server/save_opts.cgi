#!/usr/local/bin/perl
# Show a form for editing command-line options

use strict;
use warnings;
require './iscsi-server-lib.pl';
our (%text, %config, %in);
&ReadParse();
&error_setup($text{'opts_err'});

&lock_file(&get_iscsi_options_file());
my $opts = &get_iscsi_options();

# IPv4 enabled?
if ($in{'ip4'}) {
	$opts->{'4'} = '';
	}
else {
	delete($opts->{'4'});
	}

# IPv6 enabled?
if ($in{'ip6'}) {
	$opts->{'6'} = '';
	}
else {
	delete($opts->{'6'});
	}

# Hostname
if ($in{'name_def'}) {
	delete($opts->{'t'});
	}
else {
	$in{'name'} =~ /^[A-Za-z0-9\.\_\-]+$/ ||
		&error($text{'opts_ename'});
	$opts->{'t'} = $in{'name'};
	}

# Port number
if ($in{'port_def'}) {
	delete($opts->{'p'});
	}
else {
	$in{'port'} =~ /^\d+$/ || $in{'port'} > 0 && $in{'port'} < 65536 ||
		&error($text{'opts_eport'});
	$opts->{'p'} = $in{'port'};
	}

# Port number
if ($in{'sess_def'}) {
	delete($opts->{'s'});
	}
else {
	$in{'sess'} =~ /^\d+$/ || $in{'sess'} > 0 ||
		&error($text{'opts_esess'});
	$opts->{'s'} = $in{'sess'};
	}

&save_iscsi_options($opts);
&unlock_file(&get_iscsi_options_file());
&webmin_log("opts");
&redirect("");

