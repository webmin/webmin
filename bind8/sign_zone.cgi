#!/usr/local/bin/perl
# Sign a master zone

require './bind8-lib.pl';
&error_setup($text{'sign_err'});
&ReadParse();
$zone = &get_zone_name_or_error($in{'zone'}, $in{'view'});
$dom = $zone->{'name'};
&can_edit_zone($zone) ||
	&error($text{'master_ecannot'});

# Do the signing
&lock_file(&make_chroot(&absolute_path($zone->{'file'})));
$err = &sign_dnssec_zone($zone, 1);
&error($err) if ($err);
&unlock_file(&make_chroot(&absolute_path($zone->{'file'})));

# Return to master page
&webmin_log("sign", undef, $dom);
&redirect("edit_master.cgi?zone=$in{'zone'}&view=$in{'view'}");

