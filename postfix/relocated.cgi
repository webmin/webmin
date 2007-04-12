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
# Manages relocated tables for Postfix
#
# << Here are all options seen in Postfix sample-relocated.cf >>


require './postfix-lib.pl';

$access{'relocated'} || &error($text{'relocated_ecannot'});
&ui_print_header(undef, $text{'relocated_title'}, "", "relocated");

# alias general options

print "<form action=save_opts_relocated.cgi>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'relocated_title'}</b></td></tr>\n";
print "<tr $cb> <td><table width=100%>\n";

$none = $text{'opts_none'};

print "<tr>\n";
&option_radios_freefield("relocated_maps", 60, $none);
print "</tr>\n";

print "</table></td></tr></table><p>\n";
print "<input type=submit value=\"$text{'opts_save'}\"></form>\n";
print "<hr>\n";
print "<br>\n";


if (&get_current_value("relocated_maps") eq "")
{
    print ($text{'no_map'}."<br><br>");
}
else
{
    &generate_map_edit("relocated_maps", $text{'map_click'}." ".
		       "<font size=\"-1\">".&hlink("$text{'help_map_format'}", "relocated")."</font>\n<br>\n");
}

&ui_print_footer("", $text{'index_return'});
