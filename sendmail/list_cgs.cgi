#!/usr/local/bin/perl
# list_cgs.cgi
# List domains for which outgoing address mapping is done

require './sendmail-lib.pl';
$access{'cgs'} || &error($text{'cgs_ecannot'});
&ui_print_header(undef, $text{'cgs_title'}, "");

$conf = &get_sendmailcf();
@dlist = &get_file_or_config($conf, "G");

print &text('cgs_desc', "list_generics.cgi"),"<p>\n";

print &ui_form_start("save_cgs.cgi", "form-data");
print &ui_table_start(undef, undef, 2);
print &ui_table_row(undef,
	&ui_textarea("dlist", join("\n", @dlist), 15, 80), 2);
print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});

