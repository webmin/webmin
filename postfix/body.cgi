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
# Manages virtuals for Postfix
#
# << Here are all options seen in Postfix sample-virtual.cf >>


require './postfix-lib.pl';

$access{'body'} || &error($text{'body_ecannot'});
&ui_print_header(undef, $text{'body_title'}, "", "body");


# alias general options

print "<form action=save_opts_body.cgi>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'body_title'}</b></td></tr>\n";
print "<tr $cb> <td><table width=100%>\n";

$none = $text{'opts_none'};

print "<tr>\n";
&option_radios_freefield("body_checks", 60, $none);
print "</tr>\n";

print "</table></td></tr></table><p>\n";
print "<input type=submit value=\"$text{'opts_save'}\"></form>\n";
print "<hr>\n";
print "<br>\n";


if (&get_current_value("body_checks") eq "")
{
    print ($text{'no_map'}."<br><br>");
}
else
{
    &generate_map_edit("body_checks", $text{'map_click'}." ".
		       "<font size=\"-1\">".&hlink("$text{'help_map_format'}", "body")."</font>\n<br>\n", 1,
		       $text{'header_name'}, $text{'header_value'});
}

&ui_print_footer("", $text{'index_return'});

