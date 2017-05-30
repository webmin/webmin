#!/usr/local/bin/perl
# save_subs.cgi
# Save subscription options

require './majordomo-lib.pl';
&ReadParse();
%access = &get_module_acl();
&can_edit_list(\%access, $in{'name'}) || &error($text{'edit_ecannot'});
$conf = &get_config();
$ldir = &perl_var_replace(&find_value("listdir", $conf), $conf);
$list = &get_list($in{'name'},$conf);
&lock_file($list->{'config'});
$lconf = &get_list_config($list->{'config'});
&save_list_directive($lconf, $list->{'config'}, "subscribe_policy",
		     $in{'subscribe_policy'}.$in{'subscribe_policy_c'});
&save_list_directive($lconf, $list->{'config'}, "unsubscribe_policy",
		     $in{'unsubscribe_policy'});
&save_choice($lconf, $list->{'config'}, "welcome");
&save_choice($lconf, $list->{'config'}, "strip");
&save_choice($lconf, $list->{'config'}, "announcements");
&save_choice($lconf, $list->{'config'}, "administrivia");
&save_opt($lconf, $list->{'config'}, "admin_passwd", \&check_pass);
&save_choice($lconf, $list->{'config'}, "moderate");
&save_opt($lconf, $list->{'config'}, "moderator", \&check_email);
&save_opt($lconf, $list->{'config'}, "approve_passwd", \&check_pass);

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

local $aliasowner=&set_alias_owner($in{'owner'}, $ldir);
&foreign_call($aliases_module, 'modify_alias', $listowner,
	      { 'name' => "$in{'name'}-owner",
		'values' => [ $aliasowner ],
		'enabled' => 1 }) if ($listowner);
&foreign_call($aliases_module, 'modify_alias', $ownerlist,
	      { 'name' => "owner-$in{'name'}",
		'values' => [ $aliasowner ],
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
