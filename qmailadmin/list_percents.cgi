#!/usr/local/bin/perl
# list_percents.cgi
# Display domains for which % addresses are accepted

require './qmail-lib.pl';
&ui_print_header(undef, $text{'percents_title'}, "");

$percents = &list_control_file("percenthack");

print "<form method=post action=save_percents.cgi ",
      "enctype=multipart/form-data>\n";
print "<table cellpadding=5 width=100%><tr><td valign=top nowrap>\n";
print "<b>$text{'percents_domains'}</b><br>\n";

print "<textarea name=percents rows=15 cols=65>",
	&html_escape(join("\n", @$percents)),"</textarea><br>\n";
print "<input type=submit value=\"$text{'save'}\">\n";

print "</td><td valign=top>\n";
print $text{'percents_desc'},"\n";
print "</td></tr></table>\n";
print "</form>\n";

&ui_print_footer("", $text{'index_return'});


