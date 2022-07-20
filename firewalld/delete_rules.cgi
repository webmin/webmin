#!/usr/local/bin/perl
# Delete multiple ports or services

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './firewalld-lib.pl';
our (%in, %text);
&error_setup($text{'delete_err'});
&ReadParse();
my @d = split(/\0/, $in{'d'});
@d || &error($text{'delete_enone'});

my @zones = &list_firewalld_zones();
my ($zone) = grep { $_->{'name'} eq $in{'zone'} } @zones;
$zone || &error($text{'port_ezone'});

foreach my $d (@d) {
	my @w = split(/\//, $d);
	my $err;
	if ($w[0] eq "port") {
		$err = &delete_firewalld_port($zone, $w[1], $w[2]);
		}
	elsif ($w[0] eq "service") {
		$err = &delete_firewalld_service($zone, $w[1]);
		}
	elsif ($w[0] eq "forward") {
		$err = &delete_firewalld_forward($zone, @w[1..4]);
		}
	else {
		next;
		}
	&error(&text('delete_edel', $d, $err)) if ($err);
	}
&webmin_log("delete", "rules", scalar(@d));
&redirect("index.cgi?zone=".&urlize($zone->{'name'}));
