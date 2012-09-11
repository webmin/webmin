#!/usr/local/bin/perl
# Show a form to edit the config file

use strict;
use warnings;
require './iscsi-server-lib.pl';
our (%text, %config);

&ui_print_header(undef, $text{'manual_title'}, "");

print "<b>",&text('manual_desc',
		  "<tt>$config{'targets_file'}</tt>"),"</b><p>\n";
print &ui_form_start("save_manual.cgi", "form-data");
print &ui_table_start(undef, undef, 2);
print &ui_table_row(undef,
	&ui_textarea("data", &read_file_contents($config{'targets_file'}),
		     20, 80));
print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});
