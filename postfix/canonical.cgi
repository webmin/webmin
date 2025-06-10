#!/usr/local/bin/perl
#
# postfix-module by Guillaume Cottenceau <gc@mandrakesoft.com>,
# for webmin by Jamie Cameron
# 
# Manages canonicals for Postfix
#
# << Here are all options seen in Postfix sample-canonical.cf >>


require './postfix-lib.pl';

$access{'canonical'} || &error($text{'canonical_ecannot'});
&ui_print_header(undef, $text{'canonical_title'}, "", "canonical");

# Start of canonical maps form
print &ui_form_start("save_opts_canonical.cgi");
print &ui_table_start($text{'canonical_title'}, "width=100%", 2);

&option_mapfield("canonical_maps", 60);

&option_mapfield("recipient_canonical_maps", 60);

&option_mapfield("sender_canonical_maps", 60);

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'opts_save'} ] ]);

# Buttons to edit the three map types
print &ui_hr();

print &ui_form_start("canonical_edit.cgi");
print "$text{'edit_canonical_maps_general'}<p>\n";
print &ui_submit($text{'edit_canonical_maps'}, "which1");
print &ui_submit($text{'edit_recipient_canonical_maps'}, "which2");
print &ui_submit($text{'edit_sender_canonical_maps'}, "which3");
print &ui_form_end();

&ui_print_footer("", $text{'index_return'});
