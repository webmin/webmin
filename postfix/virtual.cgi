#!/usr/local/bin/perl
#
# postfix-module by Guillaume Cottenceau <gc@mandrakesoft.com>,
# for webmin by Jamie Cameron
# 
# Manages virtuals for Postfix
#
# << Here are all options seen in Postfix sample-virtual.cf >>


require './postfix-lib.pl';
&ReadParse();

$access{'virtual'} || &error($text{'virtual_ecannot'});
&ui_print_header(undef, $text{'virtual_title'}, "", "virtual");


# alias general options
print &ui_form_start("save_opts_virtual.cgi");
print &ui_table_start($text{'virtual_title'}, "width=100%", 2);

&option_mapfield($virtual_maps, 60);

if (&compare_version_numbers($postfix_version, 2) >= 0) {
	&option_radios_freefield("virtual_alias_domains", 40,
				 $text{'virtual_same'});
	}

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'opts_save'} ] ]);

# Current map contents
print &ui_hr();
if (&get_real_value($virtual_maps) eq "")
{
    print ($text{'no_map'}."<br><br>");
}
else
{
    &generate_map_edit($virtual_maps, $text{'map_click'}." ".
		       &hlink($text{'help_map_format'}, "virtual"));
}

&ui_print_footer("", $text{'index_return'});
