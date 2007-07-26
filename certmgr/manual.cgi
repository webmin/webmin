#!/usr/local/bin/perl
# Show a page for manually editing openssl.conf

require './certmgr-lib.pl';
do '../ui-lib.pl';
&ReadParse();
&ui_print_header(undef, $text{'manual_title'}, "");

# Show the file contents
print &text('manual_desc', "<tt>$config{'ssl_cnf_file'}</tt>"),"<p>\n";
print &ui_form_start("save_manual.cgi", "form-data");
$data = &read_file_contents($config{'ssl_cnf_file'});
print &ui_textarea("data", $data, 20, 80),"\n";
print &ui_form_end([ [ "save", $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});

