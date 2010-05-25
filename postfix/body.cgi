#!/usr/local/bin/perl
#
# postfix-module by Guillaume Cottenceau <gc@mandrakesoft.com>,
# for webmin by Jamie Cameron
# 
# Manages virtuals for Postfix
#
# << Here are all options seen in Postfix sample-virtual.cf >>


require './postfix-lib.pl';

$access{'body'} || &error($text{'body_ecannot'});
&ui_print_header(undef, $text{'body_title'}, "", "body");

# Start of body form
print &ui_form_start("save_opts_body.cgi");
print &ui_table_start($text{'body_title'}, "width=100%", 2);

&option_mapfield("body_checks", 60);

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'opts_save'} ] ]);

# Map contents
print &ui_hr();
if (&get_current_value("body_checks") eq "")
{
    print $text{'no_map'},"<p>\n";
}
else
{
    &generate_map_edit("body_checks", $text{'map_click'}." ".
		       &hlink($text{'help_map_format'}, "body"), 1,
		       $text{'header_name'}, $text{'header_value'});
}

&ui_print_footer("", $text{'index_return'});

