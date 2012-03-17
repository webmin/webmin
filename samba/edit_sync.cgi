#!/usr/local/bin/perl
# edit_sync.cgi
# Allow the user to edit auto updating of Samba accounts by useradmin

require './samba-lib.pl';
# check acls

&error_setup("$text{'eacl_aviol'}ask_epass.cgi");
&error("$text{'eacl_np'} $text{'eacl_pmsync'}")
        unless $access{'maint_sync'};
# display
&ui_print_header(undef, $text{'esync_title'}, "");

&check_user_enabled($text{'esync_cannot'});

print $text{'esync_msg'}, "<p>\n";

print "<form action=save_sync.cgi>\n";
printf "<input type=checkbox name=add value=1 %s>\n",
	$config{'sync_add'} ? "checked" : "";
print "$text{'esync_add'}<p>\n";

printf "<input type=checkbox name=change value=1 %s>\n",
	$config{'sync_change'} ? "checked" : "";
print "$text{'esync_chg'}<p>\n";

printf "<input type=checkbox name=delete value=1 %s>\n",
	$config{'sync_delete'} ? "checked" : "";
print "$text{'esync_del'}<p>\n";

printf "<input type=checkbox name=delete_profile value=1 %s>\n",
	$config{'sync_delete_profile'} ? "checked" : "";
print "$text{'esync_del_profile'}<p>\n";

printf "<input type=checkbox name=change_profile value=1 %s>\n",
	$config{'sync_change_profile'} ? "checked" : "";
print "$text{'esync_chg_profile'}<p>\n";

print "$text{'esync_gid'}\n",
      &ui_opt_textbox("gid", $config{'sync_gid'}, 10, $text{'default'}),"<p>\n";

print "<input type=submit value=\"", $text{'esync_apply'}, "\"></form>\n";

&ui_print_footer("", $text{'index_sharelist'});

