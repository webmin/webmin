#!/usr/local/bin/perl
# list_rcpts.cgi
# Display domains for which we accept mail for relaying or local delivery

require './qmail-lib.pl';
&ui_print_header(undef, $text{'rcpts_title'}, "");

$dlist = &list_control_file("rcpthosts");
$dlist2 = &list_control_file("morercpthosts");

print "<form method=post action=save_rcpts.cgi enctype=multipart/form-data>\n";
print "<table cellpadding=5 width=100%><tr><td valign=top nowrap>\n";
print "<b>$text{'rcpts_domains'}</b><br>\n";

printf "<input type=radio name=rcpts_def value=1 %s> %s &nbsp;&nbsp;&nbsp;\n",
	$dlist ? "" : "checked", $text{'rcpts_all'};
printf "<input type=radio name=rcpts_def value=0 %s> %s<br>\n",
	$dlist ? "checked" : "", $text{'rcpts_sel'};

print "<textarea name=rcpts rows=10 cols=65>",
	&html_escape(join("\n", @$dlist)),"</textarea><br>\n";

print "</td><td valign=top>\n";
print $text{'rcpts_desc'},"\n";

print "</td></tr> <tr> <td valign=top nowrap>\n";
print "<b>$text{'rcpts_domains2'}</b><br>\n";

print "<textarea name=rcpts2 rows=10 cols=65>",
	&html_escape(join("\n", @$dlist2)),"</textarea><br>\n";
print "<input type=submit value=\"$text{'save'}\">\n";

print "</td><td valign=top>\n";
print $text{'rcpts_desc2'},"\n";
print "</td></tr></table>\n";
print "</form>\n";

&ui_print_footer("", $text{'index_return'});


