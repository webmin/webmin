#!/usr/local/bin/perl
# save_master.cgi
# Save changes to master zone options in named.conf

require './bind8-lib.pl';
&ReadParse();
$conf = &get_config();
if ($in{'view'} ne '') {
	$view = $conf->[$in{'view'}];
	$conf = $view->{'members'};
	$indent = 2;
	}
else {
	$indent = 1;
	}
$zconf = $conf->[$in{'index'}];
&lock_file(&make_chroot($zconf->{'file'}));
&error_setup($text{'master_err'});
&can_edit_zone($zconf, $view) ||
	&error($text{'master_ecannot'});
$access{'ro'} && &error($text{'master_ero'});
$access{'opts'} || &error($text{'master_eoptscannot'});

&save_choice("check-names", $zconf, $indent);
&save_choice("notify", $zconf, $indent);
&save_address("allow-update", $zconf, $indent);
&save_address("allow-transfer", $zconf, $indent);
&save_address("allow-query", $zconf, $indent);
&save_address("also-notify", $zconf, $indent);
&flush_file_lines();
&unlock_file(&make_chroot($zconf->{'file'}));
&webmin_log("opts", undef, $zconf->{'value'}, \%in);
&redirect("edit_master.cgi?index=$in{'index'}&view=$in{'view'}");

