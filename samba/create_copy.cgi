#!/usr/local/bin/perl
# create_copy.cgi
# Display a form for creating a new copy

require './samba-lib.pl';

# check acls

&error_setup("$text{'eacl_aviol'}ask_epass.cgi");
&error("$text{'eacl_np'} $text{'eacl_pcopy'}") unless $access{'copy'};
 
&ui_print_header(undef, $text{'create_title'}, "");

print $text{'create_msg'},"<p>\n";

print &ui_form_start("save_copy.cgi", "post");
print &ui_table_start(undef, undef, 2);

print &ui_table_row($text{'create_from'},
	&ui_select("copy", undef, [ grep { $_ ne "global" } &list_shares() ]));

print &ui_table_row($text{'create_name'},
	&ui_textbox("name", undef, 20));

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'create'} ] ]);

&ui_print_footer("", $text{'index_sharelist'});

