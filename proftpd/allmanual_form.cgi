#!/usr/local/bin/perl
# allmanual_form.cgi
# Display a text box for manually editing directives from one of the files

require './proftpd-lib.pl';
&ReadParse();
&ui_print_header(undef, $text{'manual_configs'}, "",
	undef, undef, undef, undef, &restart_button());

$conf = &get_config();
@files = &unique(map { $_->{'file'} } @$conf);
$in{'file'} = $files[0] if (!$in{'file'});
&indexof($in{'file'}, @files) >= 0 || &error($text{'manual_efile'});

# File selector
print &ui_form_start("allmanual_form.cgi");
print &ui_submit($text{'manual_file'}),"\n";
print &ui_select("file", $in{'file'}, \@files);
print &ui_form_end();

# File editor
print &ui_form_start("allmanual_save.cgi", "form-data");
print &ui_hidden("file", $in{'file'});
print &ui_table_start(undef, undef, 2);
print &ui_table_row(undef,
	&ui_textarea("data", &read_file_contents($in{'file'}), 20, 80), 2);
print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});

