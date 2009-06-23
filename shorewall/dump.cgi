#!/usr/local/bin/perl
# dump.cgi
# Show a shorewall dump

require './shorewall-lib.pl';
&ui_print_header(undef, $text{'dump_title'}, "");
print "<font size=-1><pre>";
open(DUMP, "$config{'shorewall'} dump 2>&1 |");
while(<DUMP>) {
	print &html_escape($_);
	}
close(DUMP);
print "</pre></font>\n";
&ui_print_footer("", $text{'index_return'});

