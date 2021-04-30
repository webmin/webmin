#!/usr/local/bin/perl
#
# postfix-module by Guillaume Cottenceau <gc@mandrakesoft.com>,
# for webmin by Jamie Cameron
# 
# Manages transport for Postfix
#
# << Here are all options seen in Postfix sample-transport.cf >>


require './postfix-lib.pl';
&ReadParse();

$access{'transport'} || &error($text{'transport_ecannot'});
&ui_print_header(undef, $text{'transport_title'}, "", "transport");

# Start of transport form
print &ui_form_start("save_opts_transport.cgi");
print &ui_table_start($text{'transport_title'}, "width=100%", 2);

&option_mapfield("transport_maps", 60);

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
