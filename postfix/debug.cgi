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
# A form for controling debugging features.
#
# << Here are all options seen in Postfix sample-debug.cf >>

require './postfix-lib.pl';


$access{'debug'} || &error($text{'debug_ecannot'});
&ui_print_header(undef, $text{'debug_title'}, "");

$default = $text{'opts_default'};
$none = $text{'opts_none'};
$no_ = $text{'opts_no'};

print "<form action=save_opts.cgi>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'debug_title'}</b></td></tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr>\n";
&option_freefield("debug_peer_list", 65);
print "</tr>\n";

print "<tr>\n";
&option_freefield("debug_peer_level", 15);
print "</tr>\n";

print "</table></td></tr></table><p>\n";
print "<input type=submit value=\"$text{'opts_save'}\"></form>\n";
print "<hr>\n";
print "<font size=\"-1\"> <p>", &text('debug_version', postfix_module_version()),
      "</p></font>\n";
&ui_print_footer("", $text{'index_return'});

