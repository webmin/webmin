#!/usr/local/bin/perl

require './samba-lib.pl';
&ReadParse();
# check acls
%access = &get_module_acl();
&error_setup("<blink><font color=red>$text{'eacl_aviol'}</font></blink>");
&error("$text{'eacl_np'} $text{'eacl_pmusers'}")
        unless $access{'maint_users'} && $access{'view_users'};
# delete		
&lock_file($config{'smb_passwd'});
@list = &list_users();
&delete_user($list[$in{'idx'}]);
&unlock_file($config{'smb_passwd'});
&webmin_log("delete", "euser", $list[$in{'idx'}]->{'name'});
&redirect("edit_epass.cgi");

