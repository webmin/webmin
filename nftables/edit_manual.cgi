#!/usr/bin/perl
# edit_manual.cgi
# Show a page for manually editing the saved nftables rules file

require './nftables-lib.pl';    ## no critic
use strict;
use warnings;
our (%in, %text);
ReadParse();
assert_manual_acl();

ui_print_header(undef, $text{'index_edit_manual'}, "");

my @files = unique(get_nftables_config_files());
@files || error($text{'manual_enofile'});
my $file = $in{'file'} || $files[0];
indexof($file, @files) >= 0 || error($text{'manual_efile'});

print ui_form_start("edit_manual.cgi");
print "<b>$text{'manual_editsel'}</b>\n";
print ui_select("file", $file, \@files), "\n";
print ui_submit($text{'manual_ok'});
print ui_form_end();

my $data = "";
if (-r $file) {
	lock_file($file);
	$data = read_file_contents($file);
	unlock_file($file);
	}

print ui_form_start("save_manual.cgi", "form-data");
print ui_hidden("file", $file);
print ui_table_start(undef, undef, 2);
print ui_table_row(undef, ui_textarea("data", $data, 24, 100), 2);
print ui_table_end();
print ui_form_end([["save", $text{'save'}]]);

ui_print_footer("index.cgi", $text{'index_return'});
