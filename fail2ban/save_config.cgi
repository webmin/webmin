#!/usr/local/bin/perl
# Save global config options

use strict;
use warnings;
require './fail2ban-lib.pl';
our (%in, %text, %config);
&ReadParse();
&error_setup($text{'config_err'});

my $conf = &get_config();
my ($def) = grep { $_->{'name'} eq 'Definition' } @$conf;
$def || &error($text{'config_edef'});

# Validate inputs
if ($in{'logtarget_def'} eq 'file') {
	$in{'logtarget'} =~ /^\/\S+$/ || &error($text{'config_elogtarget'});
	}
if (!$in{'socket_def'}) {
	$in{'socket'} =~ /^\/\S+$/ || &error($text{'config_esocket'});
	}

# Update config file
&lock_all_config_files();

&save_directive("loglevel", $in{'loglevel'}, $def);
&save_directive("logtarget",
	$in{'logtarget_def'} eq '' ? undef :
	$in{'logtarget_def'} eq 'file' ? $in{'logtarget'} :
					 $in{'logtarget_def'}, $def);
&save_directive("socket", $in{'socket_def'} ? undef : $in{'socket'}, $def);

&unlock_all_config_files();
&webmin_log("config");
&redirect("");
