#!/usr/local/bin/perl
# check.cgi
# Check if the firewall is valid

use strict;
use warnings;
our (%text, %config);
require './shorewall-lib.pl';
&ui_print_header(undef, $text{'check_title'}, "");

print "<b>$text{'check_cmd'}</b><br>\n";
print "<pre>";
open(STATUS, "$config{'shorewall'} check 2>&1 |");
while(<STATUS>) {
	print &html_escape($_);
	}
close(STATUS);
print "</pre>\n";
if ($?) {
	print "<b>$text{'check_failed'}</b><p>\n";
	}
else {
	print "<b>$text{'check_ok'}</b><p>\n";
	}

&ui_print_footer("", $text{'index_return'});

