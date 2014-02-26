#!/usr/local/bin/perl
# Save the list of per-function cache manager passwords

use strict;
use warnings;
our (%text, %in, %access, $squid_version, %config);
require './squid-lib.pl';
&error_setup($text{'cachemgr_err'});
$access{'cachemgr'} || &error($text{'cachemgr_ecannot'});
&ReadParse();

# Validate and store inputs
&lock_file($config{'squid_conf'});
my $conf = &get_config();

if ($in{'cachemgr_def'}) {
	# Clear them all
	&save_directive($conf, "cachemgr_passwd", [ ]);
	}
else {
	# Build up list and save
	my @rv;
	for(my $i=0; defined(my $pmode = $in{"pass_def_$i"}); $i++) {
		my $pass = $pmode || $in{"pass_$i"};
		my @actions;
		if ($in{"all_$i"}) {
			@actions = ( "all" );
			}
		else {
			@actions = ( split(/\0/, $in{"action_$i"}),
				     split(/\s+/, $in{"others_$i"}) );
			}
		if ($pass && @actions) {
			push(@rv, { 'name' => 'cachemgr_passwd',
				    'values' => [ $pass, @actions ] });
			}
		}

	@rv || &error($text{'cachemgr_enone'});
	&save_directive($conf, "cachemgr_passwd", \@rv);
	}

# All done
&flush_file_lines();
&unlock_file($config{'squid_conf'});
&webmin_log("cachemgr");
&redirect("");


