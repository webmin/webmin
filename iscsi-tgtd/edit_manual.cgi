#!/usr/local/bin/perl
# Show a form to edit a config file

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './iscsi-tgtd-lib.pl';
our (%text, %config, %in);
&ReadParse();
my $file = $in{'file'} || $config{'config_file'};

&ui_print_header(undef, $text{'manual_title'}, "");

# Config file selector
my $conf = &get_tgtd_config();
my @files = &unique($config{'config_file'},
	     	    (map { $_->{'file'} } @$conf));
print &ui_form_start("edit_manual.cgi");
print "<b>$text{'manual_file'}</b> ",
      &ui_select("file", $file, \@files),"\n",
      &ui_submit($text{'manual_ok'}),"<br>\n";
print &ui_form_end();
print &ui_hr();

# File editor
print "<b>",&text('manual_desc', "<tt>$file</tt>"),"</b><p>\n";
print &ui_form_start("save_manual.cgi", "form-data");
print &ui_hidden("file", $file);
print &ui_table_start(undef, undef, 2);
print &ui_table_row(undef,
	&ui_textarea("data", &read_file_contents($file),
		     20, 80));
print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});
