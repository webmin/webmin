#!/usr/local/bin/perl
# save_forward.cgi
# Save changes to forward zone options in named.conf

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
&error_setup($text{'fwd_err'});
&can_edit_zone($zconf, $view) ||
	&error($text{'fwd_ecannot'});
$access{'ro'} && &error($text{'master_ero'});

&save_forwarders("forwarders", $zconf, $indent);
&save_choice("check-names", $zconf, $indent);
&save_choice("forward", $zconf, $indent);
&flush_file_lines();
&unlock_file(&make_chroot($zconf->{'file'}));
&webmin_log("opts", undef, $zconf->{'value'}, \%in);
&redirect("");

