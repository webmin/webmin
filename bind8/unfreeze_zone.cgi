#!/usr/local/bin/perl
# unfreeze_zone.cgi
# Apply changes to one zone only using the ndc command

require './bind8-lib.pl';
&ReadParse();
$access{'ro'} && &error($text{'restart_ecannot'});
$access{'apply'} || &error($text{'restart_ecannot'});
$zone = &get_zone_name($in{'index'}, $in{'view'});
if ($zone->{'view'}) {
	# Reload a zone in a view
	$dom = $zone->{'name'};
	&can_edit_zone($zone) || &error($text{'restart_ecannot'});
	$out = &try_cmd("thaw '$dom' IN '$zone->{'view'}'");
	}
else {
	# Just reload one top-level zone
	$dom = $zone->{'name'};
	&can_edit_zone($zone) || &error($text{'restart_ecannot'});
	$out = &try_cmd("thaw '$dom' 2>&1 </dev/null");
	}
if ($? || $out =~ /failed|not found|error/i) {
	&error(&text('restart_endc', "<tt>$out</tt>"));
	}
&webmin_log("thaw", $dom);

$tv = $zone->{'type'};
&redirect(($tv eq "master" ? "edit_master.cgi" :
	  $tv eq "forward" ? "edit_forward.cgi" : "edit_slave.cgi").
	  "?index=$in{'index'}&view=$in{'view'}");

