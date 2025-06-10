#!/usr/local/bin/perl
# Show a form for editing a mapping file

require './squid-lib.pl';
&ReadParse();
$access{'manual'} || &error($text{'manual_ecannot'});
&ui_print_header(undef, $text{'manual_title'}, "");

# Find all the config files
@files = &get_all_config_files();
$file = $in{'file'} || $files[0];
if (@files > 1) {
	# Show form to select
	print &ui_form_start("edit_manual.cgi");
	print "<b>$text{'manual_file'}</b>","\n";
	print &ui_select("file", $file, [ map { [ $_ ] } @files ]),"\n";
	print &ui_submit($text{'manual_change'});
	print &ui_form_end(),"<p>\n";
	}

# Show the file contents
$data = &read_file_contents($file);
print &ui_form_start("save_manual.cgi", "form-data");
print &ui_hidden("file", $file);
print &text('manual_editing', "<tt>$file</tt>"),"<br>\n";
print &ui_textarea("data", $data, 20, 80);
print &ui_form_end([ [ "save", $text{'save'} ] ] );

&ui_print_footer("", $text{'index_return'});

