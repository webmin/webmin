#!/usr/local/bin/perl
#
# postfix-module by Guillaume Cottenceau <gc@mandrakesoft.com>,
# for webmin by Jamie Cameron
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
