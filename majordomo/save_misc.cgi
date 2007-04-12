#!/usr/local/bin/perl
# save_misc.cgi
# Save miscellaneous options

require './majordomo-lib.pl';
&ReadParse();
%access = &get_module_acl();
&can_edit_list(\%access, $in{'name'}) || &error($text{'edit_ecannot'});
$list = &get_list($in{'name'}, &get_config());
&lock_file($list->{'config'});
$conf = &get_list_config($list->{'config'});
&save_choice($conf, $list->{'config'}, "mungedomain");
&save_choice($conf, $list->{'config'}, "debug");
&save_choice($conf, $list->{'config'}, "date_info");
&save_choice($conf, $list->{'config'}, "date_intro");
&flush_file_lines();
&unlock_file($list->{'config'});
&webmin_log("misc", undef, $in{'name'}, \%in);
&redirect("edit_list.cgi?name=$in{'name'}");

