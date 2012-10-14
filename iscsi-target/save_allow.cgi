#!/usr/local/bin/perl
# Save or delete an allowed target and IP list

use strict;
use warnings;
require './iscsi-target-lib.pl';
our (%text, %in);
&ReadParse();
&error_setup($text{'allow_err'});

# Get the allow
&lock_file(&get_allow_file($in{'mode'}));
my $allow = &get_allow_config($in{'mode'});
if (!$in{'new'}) {
	$a = $allow->[$in{'idx'}];
	$a || &error($text{'allow_egone'});
	}
else {
	$a = { 'mode' => $in{'mode'} };
	}

if ($in{'delete'}) {
	# Just delete
	&delete_allow($a);
	}
else {
	# Validate and store inputs
	$a->{'name'} = $in{'name'};
	if ($in{'addrs_def'}) {
		$a->{'addrs'} = [ 'ALL' ];
		}
	else {
		my @addrs = split(/\s+/, $in{'addrs'});
		foreach my $addr (@addrs) {
			&check_ipaddress($addr) ||
			  ($addr =~ /^\[(.*)\]$/ && &check_ip6address("$1")) ||
			  ($addr =~ /^(\S+)\/\d+/ && &check_ipaddress("$1")) ||
				&error(&text('allow_eaddr', $addr));
			}
		@addrs || &error($text{'allow_eaddrs'});
		$a->{'addrs'} = \@addrs;
		}

	# Save the object
	if ($in{'new'}) {
		&create_allow($a);
		}
	else {
		&modify_allow($a);
		}
	}

&lock_file(&get_allow_file($in{'mode'}));
&webmin_log($in{'new'} ? 'create' : $in{'delete'} ? 'delete' : 'modify',
	    $in{'mode'}, $a->{'name'});
&redirect("list_allow.cgi?mode=$in{'mode'}");

