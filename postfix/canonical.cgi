#!/usr/local/bin/perl
#
# postfix-module by Guillaume Cottenceau <gc@mandrakesoft.com>,
# for webmin by Jamie Cameron
#
# Copyright (c) 2000 by Mandrakesoft
#
# Permission to use, copy, modify, and distribute this software and its
# documentation under the terms of the GNU General Public License is hereby 
# granted. No representations are made about the suitability of this software 
# for any purpose. It is provided "as is" without express or implied warranty.
# See the GNU General Public License for more details.
#
# 
# Manages canonicals for Postfix
#
# << Here are all options seen in Postfix sample-canonical.cf >>


require './postfix-lib.pl';

$access{'canonical'} || &error($text{'canonical_ecannot'});
&ui_print_header(undef, $text{'canonical_title'}, "", "canonical");



# alias general options

print "<form action=save_opts_canonical.cgi>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'canonical_title'}</b></td></tr>\n";
print "<tr $cb> <td><table width=100%>\n";

$none = $text{'opts_none'};

print "<tr>\n";
&option_mapfield("canonical_maps", 60, $none);
print "</tr>\n";

print "<tr>\n";
&option_mapfield("recipient_canonical_maps", 60, $none);
print "</tr>\n";

print "<tr>\n";
&option_mapfield("sender_canonical_maps", 60, $none);
print "</tr>\n";



print "</table></td></tr></table><p>\n";
print "<input type=submit value=\"$text{'opts_save'}\"></form>\n";
print "<hr>\n";

print "<br>\n";

print "<table cellpadding=5 width=100%><tr><td>\n";
print "<form action=canonical_edit.cgi>\n";
print "$text{'edit_canonical_maps_general'}:</td></tr><tr><td>\n";
print "<input type=submit name=which1 value=\"$text{'edit_canonical_maps'}\">\n";
print "<input type=submit name=which2 value=\"$text{'edit_recipient_canonical_maps'}\">\n";
print "<input type=submit name=which3 value=\"$text{'edit_sender_canonical_maps'}\">\n";
print "</td></tr></table></form>\n";



&ui_print_footer("", $text{'index_return'});
