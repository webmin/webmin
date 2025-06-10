#!/usr/local/bin/perl
# edit_winbind.cgi
# Show form for binding to a domain

require './samba-lib.pl';

$access{'winbind'} || &error($text{'winbind_ecannot'});
&ui_print_header(undef, $text{'winbind_title'}, "");

print $text{'winbind_msg'}, "<p>\n";

print &ui_form_start("save_winbind.cgi", "post");
print &ui_table_start($text{'winbind_header'}, "width=100%", 2);

print &ui_table_row($text{'winbind_user'},
		    &ui_user_textbox("user", "Administrator"));

print &ui_table_row($text{'winbind_pass'},
		    &ui_password("pass", undef, 20));

print &ui_table_row($text{'winbind_dom'},
		    &ui_opt_textbox("dom", undef, 20,
				    $text{'winbind_default'}));

print &ui_table_end();
print &ui_form_end([ [ 'save', $text{'winbind_save'} ] ], "100%");

&ui_print_footer("", $text{'index_sharelist'});

