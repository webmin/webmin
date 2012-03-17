#!/usr/local/bin/perl

require './samba-lib.pl';
&ReadParse();
# check acls

&error_setup("$text{'eacl_aviol'}ask_epass.cgi");
&error("$text{'eacl_np'} $text{'eacl_pmusers'}")
        unless $access{'maint_users'} && $access{'view_users'};
# delete		
&lock_file($config{'smb_passwd'});
@list = &list_users();
&delete_user($list[$in{'idx'}]);
&unlock_file($config{'smb_passwd'});
&webmin_log("delete", "euser", $list[$in{'idx'}]->{'name'});
&redirect("edit_epass.cgi");

