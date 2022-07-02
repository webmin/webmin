#!/usr/local/bin/perl
# Show a page for manually editing named.conf
use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
# Globals
our (%access, %text, %in);

require './bind8-lib.pl';
$access{'defaults'} || &error($text{'manual_ecannot'});
&ReadParse();
&ui_print_header(undef, $text{'manual_title'}, "",
		 undef, undef, undef, undef, &restart_links());

# Work out and show the files
my $conf = &get_config();
my @files = &get_all_config_files($conf);
$in{'file'} ||= $files[0];
&indexof($in{'file'}, @files) >= 0 || &error($text{'manual_efile'});
print &ui_form_start("conf_manual.cgi");
print "<b>$text{'manual_file'}</b>\n";
print &ui_select("file", $in{'file'},
		 [ map { [ $_ ] } @files ]),"\n";
print &ui_submit($text{'manual_ok'});
print &ui_form_end();

# Show the file contents
print &ui_form_start("save_manual.cgi", "form-data");
print &ui_hidden("file", $in{'file'}),"\n";
print &ui_table_start(undef, "width=100%", 2);
my $data = &read_file_contents(&make_chroot($in{'file'}));
print &ui_table_row(undef,
	&ui_textarea("data", $data, 20, 80, undef, 0, "style='width:100%'"), 2);
print &ui_table_end();
print &ui_form_end([ [ "save", $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});

