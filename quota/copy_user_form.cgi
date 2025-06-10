#!/usr/local/bin/perl
# copy_user_form.cgi
# Display a form for copying some user's quotas to others

require './quota-lib.pl';
&ReadParse();
$access{'filesys'} eq "*" ||
	&error($text{'cuform_ecannot'});
&can_edit_user($in{'user'}) ||
	&error($text{'cuform_euallow'});
&ui_print_header(undef, $text{'cuform_title'}, "", "copy_user");

print "<b>",&text('cuform_copyto', $in{'user'}),"</b><p>\n";
print &ui_form_start("copy_user.cgi");
print &ui_hidden("user", $in{'user'});
print &ui_radio_table("dest", 1,
	[ [ 0, $text{'cuform_all'} ],
	  [ 1, $text{'cuform_select'}, &ui_textbox("users", undef, 40)." ".
				       &user_chooser_button("users",1) ],
	  [ 2, $text{'cuform_members'}, &ui_textbox("groups", undef, 40)." ".
					&group_chooser_button("groups",1) ],
	]);
print &ui_form_end([ [ undef, $text{'cuform_doit'} ] ]);

&ui_print_footer("user_filesys.cgi?user=$in{'user'}", $text{'cuform_return'});
