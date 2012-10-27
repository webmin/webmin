#!/usr/local/bin/perl
# move_zone.cgi
# Move a zone to a different view

require './bind8-lib.pl';
&ReadParse();

$zone = &get_zone_name_or_error($in{'zone'}, $in{'view'});
$z = &zone_to_config($zone);
$zconf = $z->{'members'};
$dom = $zone->{'name'};
&can_edit_zone($zone) ||
	&error($text{'master_ecannot'});

# Get the object for the new view
$pconf = &get_config_parent();
$conf = $pconf->{'members'};
$nconf = $conf->[$in{'newview'}];

# If the zone is in a view currently, get it too
$oldpconf = $zone->{'viewindex'} ? $conf->[$zone->{'viewindex'}] : $pconf;

$in{'view'} eq $in{'newview'} && &error($text{'master_emove'});
&can_edit_view($nconf) || &error($text{'master_eviewcannot'});

# Delete from the old view (or top level)
&lock_file(&make_chroot($z->{'file'}));
&save_directive($oldpconf, [ $z ], [ ], 0);
&flush_file_lines();
&unlock_file(&make_chroot($z->{'file'}));

# Create in new view
delete($z->{'file'});	# May not be valid anymore after move
&lock_file(&make_chroot($nconf->{'file'}));
&save_directive($nconf, undef, [ $z ], 1);
&flush_file_lines();
&unlock_file(&make_chroot($nconf->{'file'}));
&webmin_log("move", undef, $dom, \%in);

&redirect("");

