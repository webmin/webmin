#!/usr/local/bin/perl
# save_subs.cgi
# Save subscription options

require './majordomo-lib.pl';
&ReadParse();
%access = &get_module_acl();
&can_edit_list(\%access, $in{'name'}) || &error($text{'edit_ecannot'});
$list = &get_list($in{'name'}, &get_config());
&lock_file($list->{'config'});
$conf = &get_list_config($list->{'config'});
&save_list_directive($conf, $list->{'config'}, "subscribe_policy",
		     $in{'subscribe_policy'}.$in{'subscribe_policy_c'});
&save_list_directive($conf, $list->{'config'}, "unsubscribe_policy",
		     $in{'unsubscribe_policy'});
&save_choice($conf, $list->{'config'}, "welcome");
&save_choice($conf, $list->{'config'}, "strip");
&save_choice($conf, $list->{'config'}, "announcements");
&save_choice($conf, $list->{'config'}, "administrivia");
&save_opt($conf, $list->{'config'}, "admin_passwd", \&check_pass);
&save_choice($conf, $list->{'config'}, "moderate");
&save_opt($conf, $list->{'config'}, "moderator", \&check_email);
&save_opt($conf, $list->{'config'}, "approve_passwd", \&check_pass);

$in{'owner'} =~ /^\S+$/ || &error($text{'subs_eowner'});
$in{'approval'} =~ /^\S+$/ || &error($text{'subs_eapproval'});
$aliases_files = &get_aliases_file();
&foreign_call($aliases_module, "lock_alias_files", $aliases_files);
@aliases = &foreign_call($aliases_module, "list_aliases", $aliases_files);
foreach $a (@aliases) {
	$listowner = $a if (lc($a->{'name'}) eq lc("$in{'name'}-owner"));
	$ownerlist = $a if (lc($a->{'name'}) eq lc("owner-$in{'name'}"));
	$approval = $a if (lc($a->{'name'}) eq lc("$in{'name'}-approval"));
	}
&foreign_call($aliases_module, 'modify_alias', $listowner,
	      { 'name' => "$in{'name'}-owner",
		'values' => [ $in{'owner'} ],
		'enabled' => 1 }) if ($listowner);
&foreign_call($aliases_module, 'modify_alias', $ownerlist,
	      { 'name' => "owner-$in{'name'}",
		'values' => [ $in{'owner'} ],
		'enabled' => 1 }) if ($ownerlist);
&foreign_call($aliases_module, 'modify_alias', $approval,
	      { 'name' => "$in{'name'}-approval",
		'values' => [ $in{'approval'} ],
		'enabled' => 1 }) if ($approval);
&foreign_call($aliases_module, "unlock_alias_files", $aliases_files);

&flush_file_lines();
&unlock_file($list->{'config'});
&webmin_log("subs", undef, $in{'name'});
&redirect("edit_list.cgi?name=$in{'name'}");

sub check_email
{
return $_[0] =~ /^\S+$/ ? undef : $text{'subs_emoderator'};
}

sub check_pass
{
return $_[0] =~ /^\S+$/ ? undef : $text{'subs_epasswd'};
}
