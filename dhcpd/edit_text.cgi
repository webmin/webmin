#!/usr/bin/perl
# $Id: edit_text.cgi,v 1.2 2005/04/16 14:30:21 jfranken Exp $
# File added 2005-04-15 by Johannes Franken <jfranken@jfranken.de>
# Distributed under the terms of the GNU General Public License, v2 or later
#
# * Display form to manually edit dhcpd.conf file (pass to save_text.cgi)

require './dhcpd-lib.pl';
$access{'noconfig'} && &error($text{'text_ecannot'});
$conf = &get_config();
&ui_print_header($text{'text_editor'}, $text{'text_title'}, "");

my $conftext = &read_file_contents($config{'dhcpd_conf'});
if (!$access{'ro'}) {
	print &text('text_desc', "<tt>$file</tt>"),"<p>\n";
	}

print &ui_form_start("save_text.cgi", "form-data");
print &ui_textarea("text", $conftext, 20, 80);
print "<p>";
print &ui_submit($text{'save'})."&nbsp;".&ui_reset($text{'text_undo'});
print &ui_form_end(undef,undef,1);

&ui_print_footer("",$text{'text_return'});
