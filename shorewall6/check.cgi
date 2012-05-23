#!/usr/bin/perl
# check.cgi
# Check if the firewall is valid

require './shorewall6-lib.pl';
&ui_print_header(undef, $text{'check_title'}, "");
print "<b>$text{'check_cmd'}</b><br>\n";
print "<font size=-1><pre>";
open(STATUS, "$config{'shorewall6'} check 2>&1 |");
while(<STATUS>) {
	print &html_escape($_);
	}
close(STATUS);
print "</pre></font>\n";
if ($?) {
	print "<b>$text{'check_failed'}</b><p>\n";
	}
else {
	print "<b>$text{'check_ok'}</b><p>\n";
	}
&ui_print_footer("", $text{'index_return'});

