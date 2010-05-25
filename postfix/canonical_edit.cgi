#!/usr/local/bin/perl
#
# postfix-module by Guillaume Cottenceau <gc@mandrakesoft.com>,
# for webmin by Jamie Cameron
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

