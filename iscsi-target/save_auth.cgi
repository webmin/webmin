#!/usr/local/bin/perl
# Save global authentication options

use strict;
use warnings;
require './iscsi-target-lib.pl';
our (%text, %in, %config);
&ReadParse();
&error_setup($text{'auth_err'});
&lock_file($config{'config_file'});
my $pconf = &get_iscsi_config_parent();
my $conf = $pconf->{'members'};

# Validate incoming user(s)
my @iusers;
if (!$in{"iuser_def"}) {
	for(my $i=0; defined($in{"uname_$i"}); $i++) {
		next if (!$in{"uname_$i"});
		$in{"uname_$i"} =~ /^\S+$/ ||
			&error(&text('target_eiuser', $i+1));
		$in{"upass_$i"} =~ /^\S+$/ ||
			&error(&text('target_eipass', $i+1));
		push(@iusers, $in{"uname_$i"}." ".$in{"upass_$i"});
		}
	@iusers || &error($text{'target_eiusernone'});
	}
&save_directive($conf, $pconf, "IncomingUser", \@iusers);

# Validate outgoing user
if ($in{"ouser_def"}) {
	&save_directive($conf, $pconf, "OutgoingUser", [ ]);
	}
else {
	$in{"ouser"} =~ /^\S+$/ || &error($text{'target_eouser'});
	$in{"opass"} =~ /^\S+$/ || &error($text{'target_eopass'});
	&save_directive($conf, $pconf, "OutgoingUser",
		[ $in{"ouser"}." ".$in{"opass"} ]);
	}

&flush_file_lines($config{'config_file'});
&unlock_file($config{'config_file'});
&webmin_log('auth');
&redirect("");
