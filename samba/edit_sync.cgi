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

print &ui_form_start("save_sync.cgi", "post");
print &ui_table_start(undef, undef, 2);

print &ui_table_row($text{'esync_add'},
	&ui_yesno_radio("add", $config{'sync_add'}));

print &ui_table_row($text{'esync_chg'},
	&ui_yesno_radio("change", $config{'sync_change'}));

print &ui_table_row($text{'esync_del'},
	&ui_yesno_radio("delete", $config{'sync_delete'}));

print &ui_table_row($text{'esync_del_profile'},
	&ui_yesno_radio("delete_profile", $config{'sync_delete_profile'}));

print &ui_table_row($text{'esync_chg_profile'},
	&ui_yesno_radio("change_profile", $config{'sync_change_profile'}));

print &ui_table_row($text{'esync_gid'},
	&ui_opt_textbox("gid", $config{'sync_gid'}, 10, $text{'default'}));

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'esync_apply'} ] ]);

&ui_print_footer("", $text{'index_sharelist'});

