#!/usr/local/bin/perl
# Show a page for manually editing allowed GRUB 2 files.

use strict;
use warnings;
require './grub2-lib.pl';    ## no critic

our (%in, %text);

&ReadParse();
&error_setup($text{'manual_err'});
&grub2_assert_acl('manual');

# The manual editor is restricted to discovered GRUB-related files only.
my @files = &grub2_manual_files();
@files || &error($text{'manual_enofile'});
my @paths = map { $_->{'file'} } @files;
my $file = $in{'file'} || $paths[0];
&grub2_manual_file($file) || &error($text{'manual_efile'});

&ui_print_header(undef, $text{'manual_title'}, "");

print &ui_form_start("edit_manual.cgi");
print &ui_tag('b', &html_escape($text{'manual_select'})),"\n";
print &ui_select("file", $file, \@paths),"\n";
print &ui_submit($text{'manual_ok'});
print &ui_form_end();

# Lock while reading so the text shown matches the file validation target.
my $data = "";
if (-r $file) {
	&lock_file($file);
	$data = &read_file_contents($file);
	&unlock_file($file);
	}

print &ui_form_start("save_manual.cgi", "form-data");
print &ui_hidden("file", $file);
print &ui_table_start(undef, undef, 2);
print &ui_table_row(undef, &ui_textarea("data", $data, 24, 100), 2);
print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("index.cgi", $text{'index_return'});
