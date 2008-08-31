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
# Edit one category of canonical maps

require './postfix-lib.pl';
&ReadParse();

&ui_print_header(undef, $text{'canonical_edit_title'}, "", "canonical");


my $first_line = $text{'map_click'}." ".
                 &hlink($text{'help_map_format'}, "canonical");

if ($in{'which1'})
{ 
    &generate_map_edit("canonical_maps", $first_line);
}
elsif ($in{'which2'})
{ 
    &generate_map_edit("recipient_canonical_maps", $first_line);
}
elsif ($in{'which3'})
{ 
    &generate_map_edit("sender_canonical_maps", $first_line);
}
else 
{ 
    &error($text{'internal_error'}); 
}

&ui_print_footer("", $text{'index_return'});

