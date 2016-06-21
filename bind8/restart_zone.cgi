#!/usr/local/bin/perl
# restart_zone.cgi
# Apply changes to one zone only using the ndc command
use strict;
use warnings;
our (%access, %text, %in);

require './bind8-lib.pl';
&ReadParse();
$access{'ro'} && &error($text{'restart_ecannot'});
$access{'apply'} || &error($text{'restart_ecannot'});
my $zone = &get_zone_name_or_error($in{'zone'}, $in{'view'});
&can_edit_zone($zone) || &error($text{'restart_ecannot'});
my $err = &restart_zone($zone->{'name'}, $zone->{'view'});
&error($err) if ($err);
&webmin_log("apply", $zone->{'name'});

my $tv = $zone->{'type'};
if ($in{'return'}) {
	&redirect($ENV{'HTTP_REFERER'});
	}
else {
	&redirect(($tv eq "master" ? "edit_master.cgi" :
		  $tv eq "forward" ? "edit_forward.cgi" : "edit_slave.cgi").
		  "?zone=$in{'zone'}&view=$in{'view'}");
	}

