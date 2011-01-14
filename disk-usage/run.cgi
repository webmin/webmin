#!/usr/local/bin/perl
# Build the usage tree now

require './disk-usage-lib.pl';
&ui_print_unbuffered_header(undef, $text{'run_title'}, "");

print $text{'run_doing'},"<br>\n";
$root = &build_root_usage_tree([ split(/\t+/, $config{'dirs'}) ]);
&save_usage_tree($root);
print $text{'run_done'},"<p>\n";

&ui_print_footer("", $text{'index_return'});

