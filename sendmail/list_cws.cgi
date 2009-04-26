#!/usr/local/bin/perl
# list_cws.cgi
# List domains for which we accept mail

require './sendmail-lib.pl';
$access{'cws'} || &error($text{'cws_ecannot'});
&ui_print_header(undef, $text{'cws_title'}, "");

$conf = &get_sendmailcf();
@dlist = &get_file_or_config($conf, "w");

# Explanation
print &text('cws_desc1', "<tt>".&get_system_hostname()."</tt>"),"<p>\n";
print $text{'cws_desc2'},"<p>\n";

# Local domains field
print &ui_form_start("save_cws.cgi", "form-data");
print &ui_table_start(undef, undef, 2);
print &ui_table_row(undef, ui_textarea("dlist", join("\n", @dlist), 15, 80), 2);
print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});


