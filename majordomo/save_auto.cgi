#!/usr/local/bin/perl
# save_auto.cgi
# Update automatic sync options

require './majordomo-lib.pl';
&ReadParse();
%access = &get_module_acl();
&can_edit_list(\%access, $in{'name'}) || &error($text{'edit_ecannot'});
&lock_file("$module_config_directory/config");
if ($in{'sync'}) {
	$config{"sync_$in{'name'}"} = 1;
	}
else {
	delete($config{"sync_$in{'name'}"});
	}
$config{"shost_$in{'name'}"} = $in{'shost'};
&write_file("$module_config_directory/config", \%config);
&unlock_file("$module_config_directory/config");
&webmin_log("auto", undef, $in{'name'});
&redirect("edit_list.cgi?name=$in{'name'}");

