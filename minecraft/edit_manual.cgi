#!/usr/local/bin/perl
# Show a form for manually editing the config file

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './minecraft-lib.pl';
our (%in, %text);

&ui_print_header(undef, $text{'manual_title'}, "");

print &text('manual_desc', &get_minecraft_config_file()),"<p>\n";

print &ui_form_start("save_manual.cgi", "form-data");
print &ui_table_start(undef, undef, 2);
print &ui_table_row(undef,
	&ui_textarea("conf", &read_file_contents(&get_minecraft_config_file()),
		     20, 80));
print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});

