#!/usr/local/bin/perl
#
# postfix-module by Guillaume Cottenceau <gc@mandrakesoft.com>,
# for webmin by Jamie Cameron
# 
# Manages sni for Postfix
#
# << Here are all options seen in Postfix sample-sni.cf >>


require './postfix-lib.pl';
&ReadParse();

$access{'sni'} || &error($text{'sni_ecannot'});
&ui_print_header(undef, $text{'sni_title'}, "", "sni");

# Start of sni form
print &ui_form_start("save_opts_sni.cgi");
print &ui_table_start($text{'sni_title'}, "width=100%", 2);

&option_mapfield("tls_server_sni_maps", 60);

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'opts_save'} ] ]);

# Transport map contents
print &ui_hr();
if (&get_current_value("tls_server_sni_maps") eq "")
{
    print $text{'no_map'},"<p>\n";
}
else
{
    &generate_map_edit("tls_server_sni_maps", $text{'map_click'}." ".
		       &hlink($text{'help_map_format'}, "sni"), 1,
		       $text{'sni_dom'}, $text{'sni_certs'});
}

&ui_print_footer("", $text{'index_return'});
