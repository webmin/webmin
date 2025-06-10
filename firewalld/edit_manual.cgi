#!/usr/local/bin/perl
# Show a page for manually editing FirewallD config files

require './firewalld-lib.pl';
&ui_print_header(undef, $text{'manual_title'}, "");
&ReadParse();
my @files = &unique(&get_config_files());
my $file = $in{'file'} || $files[0];
&indexof($file, @files) >= 0 || &error($text{'manual_efile'});

# Show the file selector
print &ui_form_start("edit_manual.cgi");
print "<b>$text{'manual_editsel'}</b>\n";
print &ui_select("file", $file, \@files),"\n";
print &ui_submit($text{'manual_ok'});
print &ui_form_end();

# Show the file contents
print &ui_form_start("save_manual.cgi", "form-data");
print &ui_hidden("file", $file);
print &ui_table_start(undef, undef, 2);
$data = &read_file_contents($file);
print &ui_table_row(undef, ui_textarea("data", $data, 20, 80), 2);
print &ui_table_end();
print &ui_form_end([ [ "save", $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});

