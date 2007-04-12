#!/usr/local/bin/perl
# Show a page for manually editing smb.conf

require './samba-lib.pl';
&ReadParse();
&ui_print_header(undef, $text{'manual_title'}, "");

# Show the file contents
print &text('manual_desc', "<tt>$config{'smb_conf'}</tt>"),"<p>\n";
print &ui_form_start("save_manual.cgi", "form-data");
$data = &read_file_contents($config{'smb_conf'});
print &ui_textarea("data", $data, 20, 80),"\n";
print &ui_form_end([ [ "save", $text{'save'} ] ]);

&ui_print_footer("", $text{'index_sharelist'});

