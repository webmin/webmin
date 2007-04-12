#!/usr/local/bin/perl
# list_relay.cgi
# List domains to while relaying is allowed

require './sendmail-lib.pl';
$access{'relay'} || &error($text{'relay_ecannot'});
&ui_print_header(undef, $text{'relay_title'}, "");

$conf = &get_sendmailcf();
$ver = &find_type("V", $conf);
if ($ver->{'value'} !~ /^(\d+)/ || $1 < 8) {
	# Only sendmail 8.9 and above supports relay domains (I think)
	print "<b>",$text{'relay_eversion'},"</b> <p>\n";
	&ui_print_footer("", $text{'index_return'});
	exit;
	}

@dlist = &get_file_or_config($conf, "R");

print "<form method=post action=save_relay.cgi enctype=multipart/form-data>\n";
print "<table cellpadding=5 width=100%><tr><td valign=top nowrap>\n";
print "<b>$text{'relay_domains'}</b><br>\n";
print "<textarea name=dlist rows=15 cols=65>",
	join("\n", @dlist),"</textarea><br>\n";
print "<input type=submit value=\"$text{'save'}\">\n";

print "</td><td valign=top>\n";
print &text('relay_desc1', "list_access.cgi"),"<p>\n";
print &text('relay_desc2', "list_mailers.cgi"),"<br>\n";
print "</td></tr></table>\n";
print "</form>\n";

&ui_print_footer("", $text{'index_return'});


