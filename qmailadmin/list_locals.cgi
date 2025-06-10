#!/usr/local/bin/perl
# list_locals.cgi
# Display domains for which we accept mail for local delivery

require './qmail-lib.pl';
&ui_print_header(undef, $text{'locals_title'}, "");

$dlist = &list_control_file("locals");
$me = &get_control_file("me");

print "<form method=post action=save_locals.cgi enctype=multipart/form-data>\n";
print "<table cellpadding=5 width=100%><tr><td valign=top nowrap>\n";
print "<b>$text{'locals_domains'}</b><br>\n";

printf "<input type=radio name=locals_def value=1 %s> %s &nbsp;&nbsp;&nbsp;\n",
	$dlist ? "" : "checked", &text('locals_only', "<tt>$me</tt>");
printf "<input type=radio name=locals_def value=0 %s> %s<br>\n",
	$dlist ? "checked" : "", $text{'locals_sel'};

print "<textarea name=locals rows=15 cols=65>",
	&html_escape(join("\n", @$dlist)),"</textarea><br>\n";
print "<input type=submit value=\"$text{'save'}\">\n";

print "</td><td valign=top>\n";
print $text{'locals_desc'},"\n";
print "</td></tr></table>\n";
print "</form>\n";

&ui_print_footer("", $text{'index_return'});


