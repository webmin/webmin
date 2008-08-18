#!/usr/local/bin/perl
# Show a page for manually editing host keys
# Only displays keys for now

require './sshd-lib.pl';
&ReadParse();
&ui_print_header(undef, $text{'keys_title'}, "");

# Work out and show the files
@files = &get_mlvalues($config{'sshd_config'}, "HostKey");
foreach $key (@files) {
	 $key = $key . ".pub";
	 }
	
$in{'file'} ||= $files[0];
&indexof($in{'file'}, @files) >= 0 || &error($text{'keys_none'});
print &ui_form_start("edit_keys.cgi");
print "<b>Key filename</b>\n";
print &ui_select("file", $in{'file'},
		 [ map { [ $_ ] } @files ]),"\n";
print &ui_submit('View');
print &ui_form_end();

# Show the file contents
print &ui_form_start("save_manual.cgi", "form-data");
print &ui_hidden("file", $in{'file'}),"\n";
$data = &read_file_contents($in{'file'});
print &ui_textarea("data", $data, 20, 80),"\n";

&ui_print_footer("", $text{'index_sharelist'});

