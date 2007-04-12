#!/usr/local/bin/perl
# list_trusts.cgi
# List users trusted by sendmail

require './sendmail-lib.pl';
$access{'trusts'} || &error($text{'trusts_ecannot'});
&ui_print_header(undef, $text{'trusts_title'}, "");

$conf = &get_sendmailcf();
@tlist = &get_file_or_config($conf, "t", "T");

print "<form method=post action=save_trusts.cgi enctype=multipart/form-data>\n";
print "<table cellpadding=5 width=100%><tr><td valign=top nowrap>\n";
print "<b>$text{'trusts_users'}</b><br>\n";
print "<textarea name=tlist rows=15 cols=30>",
	join("\n", @tlist),"</textarea><br>\n";
print "<input type=submit value=\"$text{'save'}\">\n";

print "</td><td valign=top>\n";
print $text{'trusts_desc'},"<p>\n";
print "</td></tr></table>\n";
print "</form>\n";

&ui_print_footer("", $text{'index_return'});


