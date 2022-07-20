#!/usr/local/bin/perl
# Save rich and direct rules

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './firewalld-lib.pl';
our (%in, %text);
&error_setup($text{'delete_err'});
&ReadParse();
my @rules = split(/\0/, $in{'rules'});
@rules || &error($text{'delete_enone'});

my @zones = &list_firewalld_zones();
my ($zone) = grep { $_->{'name'} eq $in{'zone'} } @zones;
$zone || &error($text{'port_ezone'});

if ($in{'remove'}) {
	foreach my $rule (@rules) {
		my $rrfunc = \&{"remove_" . ($rule =~ /^(ipv4|ipv6|eb)/ ? 'direct' : 'rich') . "_rule"};
	    my $rmerr  = &$rrfunc($rule, $zone);
	    &error(&text('delete_edel', $rule, $rmerr)) if ($rmerr);
		}
	}

&webmin_log("save", "rules", scalar(@rules));
&redirect("list_rules.cgi?zone=".&urlize($zone->{'name'}));
