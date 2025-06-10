#!/usr/local/bin/perl
# freeze_zone.cgi
# Apply changes to one zone only using the ndc command
use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%access, %text, %in);

require './bind8-lib.pl';
&ReadParse();
$access{'ro'} && &error($text{'restart_ecannot'});
$access{'apply'} || &error($text{'restart_ecannot'});
my $zone = &get_zone_name_or_error($in{'zone'}, $in{'view'});
my ($dom, $out);
if ($zone->{'view'}) {
	# Reload a zone in a view
	$dom = $zone->{'name'};
	&can_edit_zone($zone) || &error($text{'restart_ecannot'});
	$out = &try_cmd("freeze '$dom' IN '$zone->{'view'}'");
	}
else {
	# Just reload one top-level zone
	$dom = $zone->{'name'};
	&can_edit_zone($zone) || &error($text{'restart_ecannot'});
	$out = &try_cmd("freeze '$dom' 2>&1 </dev/null");
	}
if ($? || $out =~ /failed|not found|error/i) {
	&error(&text('restart_endc', "<tt>$out</tt>"));
	}
&webmin_log("freeze", $dom);
&redirect(&redirect_url($zone->{'type'}, $in{'zone'}, $in{'view'}));

