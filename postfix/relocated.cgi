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

# Relocated map form start
print &ui_form_start("save_opts_relocated.cgi");
print &ui_table_start($text{'relocated_title'}, "width=100%", 2);

$none = $text{'opts_none'};
&option_mapfield("relocated_maps", 60, $none);

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'opts_save'} ] ]);

# Map contents
print &ui_hr();
if (&get_current_value("relocated_maps") eq "")
{
    print $text{'no_map'},"<p>\n";
}
else
{
    &generate_map_edit("relocated_maps", $text{'map_click'}." ".
		       &hlink($text{'help_map_format'}, "relocated"));
}

&ui_print_footer("", $text{'index_return'});

