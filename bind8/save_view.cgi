#!/usr/local/bin/perl
# save_view.cgi
# Update an existing view

require './bind8-lib.pl';
&ReadParse();
&error_setup($text{'view_err'});
$pconf = &get_config_parent();
$conf = $pconf->{'members'};
$view = $conf->[$in{'index'}];
$access{'views'} || &error($text{'view_ecannot'});
&can_edit_view($view) || &error($text{'view_ecannot'});
$access{'ro'} && &error($text{'view_ecannot'});

# Save the view
&lock_file(&make_chroot($view->{'file'}));
&save_addr_match("match-clients", $view, 1);
&save_choice("recursion", $view, 1);
&flush_file_lines();
&unlock_file(&make_chroot($view->{'file'}));
&webmin_log("view", undef, $view->{'value'}, \%in);
&redirect("");

