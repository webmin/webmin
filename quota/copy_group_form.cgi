#!/usr/local/bin/perl
# copy_group_form.cgi
# Display a form for copying some group's quotas to others

require './quota-lib.pl';
&ReadParse();
$access{'filesys'} eq "*" ||
	&error($text{'cgform_ecannot'});
&can_edit_group($in{'group'}) ||
	&error($text{'cgform_egroup'});
&ui_print_header(undef, $text{'cgform_title'}, "", "copy_group");

print "<b>",&text('cgform_copyto', $in{'group'}),"</b><p>\n";
print &ui_form_start("copy_group.cgi");
print &ui_hidden("group", $in{'group'});

print &ui_radio_table("dest", 1,
	[ [ 0, $text{'cgform_all'} ],
	  [ 1, $text{'cgform_select'}, &ui_textbox("groups", undef, 40)." ".
				       &group_chooser_button("groups", 1) ],
	  [ 2, $text{'cgform_contain'}, &ui_textbox("users", undef, 40)." ".
					&user_chooser_button("users", 1) ],
	]);

print &ui_form_end([ [ undef, $text{'cgform_doit'} ] ]);

&ui_print_footer("group_filesys.cgi?group=$in{'group'}",
		 $text{'cgform_return'});

