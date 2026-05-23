#!/usr/local/bin/perl
# Edit Kea files as raw text.

use strict;
use warnings;
require './kea-dhcp-lib.pl';
&ReadParse();
our (%in, %text);
&error_setup($text{'eacl_aviol'});
&kea_assert_acl('manual');

my @files = &kea_manual_edit_files();
&error($text{'edit_enofile'}) if (!@files);
my $info = &kea_manual_edit_file($in{'file'}) || $files[0];
my $file = $info->{'file'};
&error($text{'save_efile'}) if (!$file);

# The manual editor is intentionally constrained to known Kea config files and
# Control Agent password files discovered by the library.
my $data = "";
if (-r $file) {
	&lock_file($file);
	$data = &read_file_contents($file);
	&unlock_file($file);
	}

&ui_print_header(undef, $text{'index_edit_manual'}, "", undef, 1, 1);

# Keep file selection and file contents as separate forms, matching nftables.
print &ui_form_start("edit_text.cgi");
print &ui_tag('b', &html_escape($text{'edit_select'})),"\n";
print &ui_select("file", $file, [ map { $_->{'file'} } @files ]),"\n";
print &ui_submit($text{'edit_ok'});
print &ui_form_end();

print &ui_form_start("save_text.cgi", "form-data");
print &ui_hidden("file", $file);
print &ui_table_start(undef, undef, 2);
print &ui_table_row(undef, &ui_textarea("data", $data, 30, 120), 2);
print &ui_table_end();
print &ui_form_end([ [ "save", $text{'save'} ] ]);
&ui_print_footer("index.cgi", $text{'index_return'});
