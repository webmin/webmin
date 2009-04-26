#!/usr/local/bin/perl
# list_trusts.cgi
# List users trusted by sendmail

require './sendmail-lib.pl';
$access{'trusts'} || &error($text{'trusts_ecannot'});
&ui_print_header(undef, $text{'trusts_title'}, "");

$conf = &get_sendmailcf();
@tlist = &get_file_or_config($conf, "t", "T");

print $text{'trusts_desc'},"<p>\n";

print &ui_form_start("save_trusts.cgi", "form-data");
print &ui_table_start(undef, undef, 2);
print &ui_table_row(undef,
	&ui_textarea("tlist", join("\n", @tlist), 15, 40).
	&user_chooser_button("tlist", 1));
print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});


