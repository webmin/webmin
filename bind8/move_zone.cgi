#!/usr/local/bin/perl
# move_zone.cgi
# Move a zone to a different view

require './bind8-lib.pl';
&ReadParse();
$pconf = &get_config_parent();
$conf = $pconf->{'members'};
$nconf = $conf->[$in{'newview'}];
if ($in{'view'} ne '') {
	$view = $conf->[$in{'view'}];
	$conf = $view->{'members'};
	}
$zconf = $conf->[$in{'index'}];
&can_edit_zone($zconf, $view) || &error($text{'master_ecannot'});
$in{'view'} ne $in{'newview'} || &error($text{'master_emove'});
&can_edit_view($nconf) || &error($text{'master_eviewcannot'});

# Delete from the view
&lock_file(&make_chroot($zconf->{'file'}));
&save_directive($pconf, [ $zconf ], [ ], 0);
&flush_file_lines();
&unlock_file(&make_chroot($zconf->{'file'}));

# Create in new view
&lock_file(&make_chroot($nconf->{'file'}));
&save_directive($nconf, undef, [ $zconf ], 1);
&flush_file_lines();
&unlock_file(&make_chroot($nconf->{'file'}));
&webmin_log("move", undef, $zconf->{'value'}, \%in);

&redirect("");

