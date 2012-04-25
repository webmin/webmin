#!/usr/local/bin/perl
# ask_epass.cgi
# Display a form asking for password conversion options

require './samba-lib.pl';
# check acls

&error_setup($text{'eacl_aviol'});
&error("$text{'eacl_np'} $text{'eacl_pmpass'}")
        unless $access{'maint_makepass'};
# display
&ui_print_header(undef, $text{'convert_title'}, "");

&check_user_enabled($text{'convert_cannot'});

print &text('convert_msg', 'conf_pass.cgi'),"\n";
print "$text{'convert_ncdesc'}<p>\n";

print &ui_form_start("make_epass.cgi", "post");
print &ui_table_start(undef, undef, 2);

print &ui_table_row($text{'convert_who'},
	&ui_radio_table("who", 1,
		[ [ 0, $text{'convert_who0'},
		    &ui_textbox("include_list", undef, 40)." ".
		      user_chooser_button("include_list", 1) ],
		  [ 1, $text{'convert_who1'},
		    &ui_textbox("skip_list", $config{'dont_convert'}, 40)." ".
		      &user_chooser_button("skip_list", 1) ],
		]));

print &ui_table_row($text{'convert_update'},
	&ui_yesno_radio("update", 1));

print &ui_table_row($text{'convert_add'},
	&ui_yesno_radio("add", 1));

print &ui_table_row($text{'convert_delete'},
	&ui_yesno_radio("delete", 0));

print &ui_table_row($text{'convert_newuser'},
	&ui_radio_table("newmode", 0,
		[ [ 0, $text{'convert_nopasswd'} ],
		  [ 1, $text{'convert_lock'} ],
		  [ 2, $text{'convert_passwd'},
		    &ui_password("newpass", undef, 20) ] ]));

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'convert_convert'} ] ]);

&ui_print_footer("", $text{'index_sharelist'});

