#!/usr/local/bin/perl
# Show the manual edit form

require './cron-lib.pl';
&ReadParse();
&ui_print_header(undef, $text{'manual_title'}, "");
$access{'mode'} == 0 || &error($text{'manual_ecannot'});

# File selection form
my @files = &list_cron_files();
$file = $in{'file'} || $files[0];
print &ui_form_start("edit_manual.cgi");
print "<b>$text{'manual_edit'}</b> ",
      &ui_select("file", $file, [ @files ])," ",
      &ui_submit($text{'manual_ok'});
print &ui_hidden("search", $in{'search'});
print &ui_form_end();

if ($file) {
	&indexof($file, @files) >= 0 || &error($text{'manual_efile'});
	print &ui_form_start("save_manual.cgi", "form-data");
	print &text('manual_editing',
		    "<tt>".&html_escape($file)."</tt>"),"<br>\n";
	print &ui_textarea("data", &read_file_contents($file), 20, 80);
	print &ui_hidden("search", $in{'search'});
	print &ui_hidden("file", $file);
	print &ui_form_end([ [ undef, $text{'save'} ] ]);
	}

&ui_print_footer("index.cgi?search=".&urlize($in{'search'}),
		 $text{'index_return'});
