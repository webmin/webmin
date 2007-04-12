#!/usr/local/bin/perl
# list_ipnodes.cgi
# List ipnodes from /etc/ipnodes

require './net-lib.pl';
$access{'ipnodes'} || &error($text{'ipnodes_ecannot'});
&ui_print_header(undef, $text{'ipnodes_title'}, "");

print "<a href=\"edit_ipnode.cgi?new=1\">$text{'ipnodes_add'}</a><br>\n"
	if ($access{'ipnodes'} == 2);
print "<table border cellpadding=3>\n";
print "<tr $tb> <td><b>$text{'ipnodes_ip'}</b></td> ",
      "<td><b>$text{'ipnodes_ipnode'}</b></td> </tr>\n";
foreach $h (&list_ipnodes()) {
	print "<tr $cb>\n";
	if ($access{'ipnodes'} == 2) {
		print "<td><a href=\"edit_ipnode.cgi?idx=$h->{'index'}\">",
		      &html_escape($h->{'address'}),"</a></td>\n";
		}
	else {
		print "<td>",&html_escape($h->{'address'}),"</td>\n";
		}
	print "<td>",join(" , ", map { &html_escape($_) }
					   @{$h->{'ipnodes'}}),"</td> </tr>\n";
	}
print "</table>\n";
print "<a href=\"edit_ipnode.cgi?new=1\">$text{'ipnodes_add'}</a>\n"
	if ($access{'ipnodes'} == 2);
print "<p>\n";

&ui_print_footer("", $text{'index_return'});

