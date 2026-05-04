#!/usr/local/bin/perl
# Show a form to edit all config files

use strict;
use warnings;
require './nginx-lib.pl';
&ReadParse();
our (%text, %in, %access);
$access{'global'} || &error($text{'index_eglobal'});

&ui_print_header(undef, $text{'manual_title'}, "");

my @files = &get_all_config_files();
$in{'file'} ||= $files[0];
&indexof($in{'file'}, @files) >= 0 || &error($text{'manual_efile'});

# Show file selector
print &ui_form_start("edit_manual.cgi");
print "<b>$text{'manual_file'}</b>\n";
print &ui_select("file", $in{'file'}, \@files, 1, 0, 0, 0,
		 "onChange='form.submit()'");
print &ui_submit($text{'manual_ok'});
print &ui_form_end();

# Show current file
print &ui_form_start("save_manual.cgi", "form-data");
print &ui_hidden("file", $in{'file'});
print &ui_table_start(undef, "width=100%", 2);

print &ui_table_row(undef,
	&ui_textarea("data", &read_file_contents($in{'file'}), 25, 80,
		     undef, 0, "style='width:100%'"), 2);

print &ui_table_row(undef,
	&ui_checkbox("test", 1, $text{'manual_test'}, 1));

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});

