#!/usr/local/bin/perl
# save_delegation.cgi
# Save changes to delegation zone options in named.conf

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
&error_setup($text{'delegation_err'});
&can_edit_zone($zconf, $view) ||
	&error($text{'delegation_ecannot'});
$access{'ro'} && &error($text{'master_ero'});

&flush_file_lines();
&unlock_file(&make_chroot($zconf->{'file'}));
&webmin_log("opts", undef, $zconf->{'value'}, \%in);
&redirect("");

