#!/usr/local/bin/perl
# Allow manual editing of all config files

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './fail2ban-lib.pl';
our (%in, %text);
&ReadParse();

&ui_print_header(undef, $text{'manual_title'}, "");

# Show file selector
my @files = &list_all_config_files();
$in{'file'} ||= $files[0];
&indexof($in{'file'}, @files) >= 0 || &error($text{'manual_efile'});
print &ui_form_start("edit_manual.cgi");
print "<b>$text{'manual_desc'}</b>\n";
print &ui_select("file", $in{'file'}, \@files, 1, 0, 0, 0,
		 "onchange='form.submit()'");
print &ui_submit($text{'manual_ok'});
print &ui_form_end();
print "<p>\n";

# Show editing form
my $data = &read_file_contents($in{'file'});
print &ui_form_start("save_manual.cgi", "form-data");
print &ui_hidden("file", $in{'file'});
print &ui_table_start("<tt>".&html_escape($in{'file'})."</tt>", undef, 2);
print &ui_table_row(undef,
	&ui_textarea("manual", $data, 40, 80), 2);
print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});
