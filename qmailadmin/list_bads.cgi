#!/usr/local/bin/perl
# list_bads.cgi
# Display domains and addresses which are rejected

require './qmail-lib.pl';
&ui_print_header(undef, $text{'bads_title'}, "");

$bads = &list_control_file("badmailfrom");

print "<form method=post action=save_bads.cgi enctype=multipart/form-data>\n";
print "<table cellpadding=5 width=100%><tr><td valign=top nowrap>\n";
print "<b>$text{'bads_addresses'}</b><br>\n";

print "<textarea name=bads rows=15 cols=65>",
	&html_escape(join("\n", @$bads)),"</textarea><br>\n";
print "<input type=submit value=\"$text{'save'}\">\n";

print "</td><td valign=top>\n";
print $text{'bads_desc'},"\n";
print "</td></tr></table>\n";
print "</form>\n";

&ui_print_footer("", $text{'index_return'});


