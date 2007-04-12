#!/usr/local/bin/perl
# list_cws.cgi
# List domains for which we accept mail

require './sendmail-lib.pl';
$access{'cws'} || &error($text{'cws_ecannot'});
&ui_print_header(undef, $text{'cws_title'}, "");

$conf = &get_sendmailcf();
@dlist = &get_file_or_config($conf, "w");

print "<form method=post action=save_cws.cgi enctype=multipart/form-data>\n";
print "<table cellpadding=5 width=100%><tr><td valign=top nowrap>\n";
print "<b>$text{'cws_domains'}</b><br>\n";
print "<textarea name=dlist rows=15 cols=65>",
	join("\n", @dlist),"</textarea><br>\n";
print "<input type=submit value=\"$text{'save'}\">\n";

print "</td><td valign=top>\n";
print &text('cws_desc1', "<tt>".&get_system_hostname()."</tt>"),"<p>\n";
print $text{'cws_desc2'},"\n";
print "</td></tr></table>\n";
print "</form>\n";

&ui_print_footer("", $text{'index_return'});


