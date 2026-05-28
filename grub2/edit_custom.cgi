#!/usr/local/bin/perl
# Show a form for adding or editing a custom GRUB 2 menu entry.

use strict;
use warnings;
require './grub2-lib.pl';    ## no critic

our (%in, %text);

&ReadParse();
&error_setup($text{'custom_err'});
&grub2_assert_acl('manual');

my $is_new = !defined($in{'idx'}) || $in{'idx'} eq '';
my ($title, $id, $body) =
	("", "", "echo 'Custom entry not configured'\ntrue\n");
# Existing entries are looked up by parsed custom-entry index, not line number.
if (!$is_new) {
	$in{'idx'} =~ /^\d+\z/ || &error($text{'custom_eentry'});
	my $entry = &grub2_custom_entry_by_index($in{'idx'});
	&error($text{'custom_eentry'}) if (!$entry);
	$title = $entry->{'title'} || "";
	$id = $entry->{'id'} || "";
	$body = &grub2_custom_entry_body($entry);
	}

&ui_print_header(undef, $is_new ? $text{'custom_title_new'} :
		 $text{'custom_title_edit'}, "");

print &ui_form_start("save_custom.cgi", "post");
print &ui_hidden("idx", $in{'idx'}) if (!$is_new);
print &ui_table_start($text{'custom_header'}, "width=100%", 2);
print &ui_table_row(&hlink($text{'custom_entry_title'}, "custom_title"),
		    &ui_textbox("title", $title, 60));
print &ui_table_row(&hlink($text{'custom_entry_id'}, "custom_id"),
		    &ui_textbox("id", $id, 60).
		    &ui_tag('div', &ui_note($text{'custom_id_note'}, 0)));
print &ui_table_hr();
# The body is stored as GRUB script text inside a generated menuentry wrapper.
print &ui_table_row(&hlink($text{'custom_entry_body'}, "custom_body"),
		    &ui_textarea("body", $body, 16, 100), 2);
print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("index.cgi?mode=custom", $text{'index_return'});
