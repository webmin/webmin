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
# Manages transport for Postfix
#
# << Here are all options seen in Postfix sample-transport.cf >>


require './postfix-lib.pl';

$access{'transport'} || &error($text{'transport_ecannot'});
&ui_print_header(undef, $text{'transport_title'}, "", "transport");

# Start of transport form
print &ui_form_start("save_opts_transport.cgi");
print &ui_table_start($text{'transport_title'}, "width=100%", 2);

$none = $text{'opts_none'};
&option_mapfield("transport_maps", 60, $none);

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'opts_save'} ] ]);

# Transport map contents
print &ui_hr();
if (&get_current_value("transport_maps") eq "")
{
    print $text{'no_map'},"<p>\n";
}
else
{
    &generate_map_edit("transport_maps", $text{'map_click'}." ".
		       &hlink($text{'help_map_format'}, "transport"));
}

&ui_print_footer("", $text{'index_return'});
