#!/usr/local/bin/perl
# Delete a zone, after asking for confirmation

use strict;
use warnings;
require './firewalld-lib.pl';
our (%text, %in);
&ReadParse();
&error_setup($text{'delzone_err'});

# Get the zone
my @zones = &list_firewalld_zones();
my ($zone) = grep { $_->{'name'} eq $in{'zone'} } @zones;
$zone || &error($text{'port_ezone'});
$zone->{'default'} && &error($text{'delzone_edefault'});

if ($in{'confirm'}) {
	# Just do it
	my $err = &delete_firewalld_zone($zone);
	&error($err) if ($err);
	&webmin_log("delete", "zone", $zone->{'name'});
	&redirect("index.cgi");
	}
else {
	# Ask first
	&ui_print_header(undef, $text{'delzone_title'}, "");

	print &ui_confirmation_form("delete_zone.cgi",
		&text('delzone_rusure', "<tt>$zone->{'name'}</tt>",
		      scalar(@{$zone->{'ports'}}),
		      scalar(@{$zone->{'services'}})),
		[ [ 'zone', $zone->{'name'} ] ],
		[ [ 'confirm', $text{'delete'} ] ],
		);

	&ui_print_footer("index.cgi?zone=".&urlize($in{'zone'}),
			 $text{'index_return'});
	}

