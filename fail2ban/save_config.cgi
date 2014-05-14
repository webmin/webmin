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

# Update config file
&lock_file($def->{'file'});

&save_directive($def, "loglevel", $in{'loglevel'});

# XXX

&unlock_file($def->{'file'});
&webmin_log("config");
&redirect("");
