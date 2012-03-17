#!/usr/local/bin/perl
# save_sync.cgi
# Save unix-samba synchronisation options

require './samba-lib.pl';
&ReadParse();
# check acls

&error_setup("$text{'eacl_aviol'}ask_epass.cgi");
&error("$text{'eacl_np'} $text{'eacl_pmsync'}")
        unless $access{'maint_sync'};
# save
$in{'gid_def'} || $in{'gid'} =~ /^\S+$/ || &error($text{'esync_egid'});
&lock_file($module_config_file);
foreach $s ("add", "change", "delete", "delete_profile", "change_profile") {
	if ($in{$s}) { $config{"sync_$s"} = 1; }
	else { delete($config{"sync_$s"}); }
	}
$config{'sync_gid'} = $in{'gid_def'} ? undef : $in{'gid'};
&save_module_config();
&unlock_file($module_config_file);
&webmin_log("sync");
&redirect("");

