#!/usr/local/bin/perl
# list_cgs.cgi
# List domains for which outgoing address mapping is done

require './sendmail-lib.pl';
$access{'cgs'} || &error($text{'cgs_ecannot'});
&ui_print_header(undef, $text{'cgs_title'}, "");

$conf = &get_sendmailcf();
@dlist = &get_file_or_config($conf, "G");

print "<form method=post action=save_cgs.cgi enctype=multipart/form-data>\n";
print "<table cellpadding=5 width=100%><tr><td valign=top nowrap>\n";
print "<b>$text{'cgs_header'}</b><br>\n";
print "<textarea name=dlist rows=15 cols=65>",
	join("\n", @dlist),"</textarea><br>\n";
print "<input type=submit value=\"$text{'save'}\">\n";

print "</td><td valign=top>\n";
print &text('cgs_desc', "list_generics.cgi"),"<p>\n";
print "</td></tr></table>\n";
print "</form>\n";

&ui_print_footer("", $text{'index_return'});

