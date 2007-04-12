#!/usr/local/bin/perl
# save_access.cgi
# Save access control options

require './majordomo-lib.pl';
&ReadParse();
%access = &get_module_acl();
&can_edit_list(\%access, $in{'name'}) || &error($text{'edit_ecannot'});
$list = &get_list($in{'name'}, &get_config());
&lock_file($list->{'config'});
$conf = &get_list_config($list->{'config'});
&save_choice($conf, $list->{'config'}, "get_access");
&save_choice($conf, $list->{'config'}, "index_access");
&save_choice($conf, $list->{'config'}, "info_access");
&save_choice($conf, $list->{'config'}, "intro_access");
&save_choice($conf, $list->{'config'}, "which_access");
&save_choice($conf, $list->{'config'}, "who_access");
$in{'adv'} =~ s/\r//g;
if ($in{'adv_mode'} == 0) {
	$adv = $noadv = "";
	}
elsif ($in{'adv_mode'} == 1) {
	$adv = $in{'adv'};
	$noadv = "";
	}
else {
	$adv = "";
	$noadv = $in{'adv'};
	}
&save_list_directive($conf, $list->{'config'}, "advertise", $adv, 1);
&save_list_directive($conf, $list->{'config'}, "noadvertise", $noadv, 1);
&save_list_directive($conf, $list->{'config'}, "restrict_post",
		     $in{'res_mode'} == 0 ? "" :
		     $in{'res_mode'} == 1 ? $in{'name'} :
					    $in{'res'});
&save_multi($conf, $list->{'config'}, "taboo_body");
&save_multi($conf, $list->{'config'}, "taboo_headers");
&flush_file_lines();
&unlock_file($list->{'config'});
&webmin_log("access", undef, $in{'name'}, \%in);
&redirect("edit_list.cgi?name=$in{'name'}");

