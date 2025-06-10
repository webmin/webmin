#!/usr/local/bin/perl
# manual_form.cgi
# Display the .procmailrc file

require './procmail-lib.pl';
&ui_print_header(undef, $text{'manual_title'}, "");

print &text('manual_desc', "<tt>$procmailrc</tt>"),"<p>\n";
print &ui_form_start("manual_save.cgi", "form-data");
print &ui_table_start(undef, undef, 2);
$data = &read_file_contents($procmailrc);
print &ui_table_row(undef, &ui_textarea("data", $data, 20, 80), 2);
print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});


