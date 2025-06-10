#!/usr/local/bin/perl
#
# postfix-module by Guillaume Cottenceau <gc@mandrakesoft.com>,
# for webmin by Jamie Cameron
# 
# Manages sender_dependent_default_transport_maps for Postfix


require './postfix-lib.pl';

$access{'dependent'} || &error($text{'dependent_ecannot'});
&ui_print_header(undef, $text{'dependent_title'}, "", "dependent");

# Start of transport form
print &ui_form_start("save_opts_dependent.cgi");
print &ui_table_start($text{'dependent_title'}, "width=100%", 2);

&option_mapfield("sender_dependent_default_transport_maps", 60);

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'opts_save'} ] ]);

# Transport map contents
print &ui_hr();
if (&get_current_value("sender_dependent_default_transport_maps") eq "")
{
    print $text{'no_map'},"<p>\n";
}
else
{
    &generate_map_edit("sender_dependent_default_transport_maps",
		       $text{'map_click'}." ".
		       &hlink($text{'help_map_format'}, "dependent"));
}

&ui_print_footer("", $text{'index_return'});
