#!/usr/local/bin/perl
# edit_ftpusers.cgi
# Lists users to be denied access

require './proftpd-lib.pl';
&ui_print_header(undef, $text{'ftpusers_title'}, "",
	undef, undef, undef, undef, &restart_button());

print &text('ftpusers_desc', "<tt>$config{'ftpusers'}</tt>"),"<p>\n";
print &ui_form_start("save_ftpusers.cgi", "post");
print &ui_table_start(undef, undef, 2);
print &ui_table_row(undef,
	&ui_textarea("users", &read_file_contents($config{'ftpusers'}), 10, 80),
	2);
print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});

