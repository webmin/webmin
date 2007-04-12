#!/usr/local/bin/perl
# edit_access.cgi 
# Display a form to edit a general access mapping table
# by Roberto Tecchio, 2005 (www.tecchio.net)

require './postfix-lib.pl';

$access{'smtpd'} || &error($text{'smtpd_ecannot'});
&ReadParse();
&ui_print_header(undef, $in{'title'}, "");

if (&get_current_value($in{'name'}) eq "")
{
    print ($text{'no_map'}."<br><br>");
}
else
{
    &generate_map_edit($in{'name'}, $text{'map_click'}." ".
		       "<font size=\"-1\">".&hlink("$text{'help_map_format'}", "access")."</font>\n<br>\n", 1,
		       $text{'mapping_client'}, $text{'header_value'});
}

&ui_print_footer("smtpd.cgi", $text{'smtpd_title'}, "index.cgi", $text{'index_title'});
