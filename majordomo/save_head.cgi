#!/usr/local/bin/perl
# save_head.cgi
# Save headers and footers

require './majordomo-lib.pl';
&ReadParse();
%access = &get_module_acl();
&can_edit_list(\%access, $in{'name'}) || &error($text{'edit_ecannot'});
$list = &get_list($in{'name'}, &get_config());
&lock_file($list->{'config'});
$conf = &get_list_config($list->{'config'});
&save_multi($conf, $list->{'config'}, "message_fronter");
&save_multi($conf, $list->{'config'}, "message_footer");
&save_multi($conf, $list->{'config'}, "message_headers");
&flush_file_lines();
&unlock_file($list->{'config'});
&webmin_log("head", undef, $in{'name'}, \%in);
&redirect("edit_list.cgi?name=$in{'name'}");

