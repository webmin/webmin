#!/usr/local/bin/perl
# status.cgi
# Show the status

require './shorewall-lib.pl';
&ui_print_header(undef, $text{'status_title'}, "");
print "<font size=-1><pre>";
open(STATUS, "$config{'shorewall'} status 2>&1 |");
while(<STATUS>) {
	print &html_escape($_);
	}
close(STATUS);
print "</pre></font>\n";
&ui_print_footer("", $text{'index_return'});

