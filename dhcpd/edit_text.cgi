#!/usr/bin/perl
# $Id: edit_text.cgi,v 1.2 2005/04/16 14:30:21 jfranken Exp $
# File added 2005-04-15 by Johannes Franken <jfranken@jfranken.de>
# Distributed under the terms of the GNU General Public License, v2 or later
#
# * Display form to manually edit dhcpd.conf file (pass to save_text.cgi)

require './dhcpd-lib.pl';
&ReadParse();
$access{'noconfig'} && &error($text{'text_ecannot'});
$conf = &get_config();
&ui_print_header($text{'text_editor'}, $text{'text_title'}, "");

open(FILE, $config{'dhcpd_conf'});
while(<FILE>) {
	push(@lines, &html_escape($_));
	}
close(FILE);

if (!$access{'ro'}) {
	print &text('text_desc', "<tt>$file</tt>"),"<p>\n";
	}

print "<form action=save_text.cgi method=post enctype=multipart/form-data>\n";
print "<textarea name=text rows=20 cols=80>",
	join("", @lines),"</textarea><p>\n";
print "<input type=submit value=\"$text{'save'}\"> ",
      "<input type=reset value=\"$text{'text_undo'}\">\n"
	if (!$access{'ro'});
print "</form>\n";

&ui_print_footer("",$text{'text_return'});
