#!/usr/local/bin/perl
#
# postfix-module by Guillaume Cottenceau <gc@mandrakesoft.com>,
# for webmin by Jamie Cameron
# 
# Manages relocated tables for Postfix
#
# << Here are all options seen in Postfix sample-relocated.cf >>


require './postfix-lib.pl';
&ReadParse();

$access{'relocated'} || &error($text{'relocated_ecannot'});
&ui_print_header(undef, $text{'relocated_title'}, "", "relocated");

# Relocated map form start
print &ui_form_start("save_opts_relocated.cgi");
print &ui_table_start($text{'relocated_title'}, "width=100%", 2);

&option_mapfield("relocated_maps", 60);

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

