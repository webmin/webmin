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
# Edit an email alias

require './postfix-lib.pl';
&ReadParse();

&ui_print_header(undef, $text{'edit_alias_title'}, "");

my @aliases = &list_postfix_aliases();
$a = $aliases[$in{'num'}] if (!$in{'new'});

$cancmt = &can_map_comments("alias_maps");
&alias_form($a, !$cancmt);

&ui_print_footer("", $text{'index_return'});
