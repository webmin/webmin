#!/usr/local/bin/perl

require './postfix-lib.pl';

$access{'bcc'} || &error($text{'bcc_ecannot'});
&ui_print_header(undef, $text{'bcc_title'}, "", "bcc");
&ReadParse();

# Start of BCC form
print &ui_form_start("save_opts_bcc.cgi");
print &ui_table_start($text{'bcc_title'}, "width=100%", 2);

&option_mapfield("sender_bcc_maps", 60);
&option_mapfield("recipient_bcc_maps", 60);

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'opts_save'} ] ]);

# Map contents
print &ui_hr();
print &ui_tabs_start([ [ "sender", $text{'bcc_sender'} ],
		       [ "recipient", $text{'bcc_recipient'} ] ],
		     "mode", $in{'mode'} || 'sender', 1);

# Sender BCC maps
print &ui_tabs_start_tab("mode", "sender");
print $text{'bcc_senderdesc'},"<p>\n";
if (&get_current_value("sender_bcc_maps") eq "")
{
    print $text{'no_map'},"<p>\n";
}
else
{
    &generate_map_edit("sender_bcc_maps", $text{'map_click'}." ".
		       &hlink($text{'help_map_format'}, "virtual"));
}
print &ui_tabs_end_tab("mode", "sender");

# Sender BCC maps
print &ui_tabs_start_tab("mode", "recipient");
print $text{'bcc_recipientdesc'},"<p>\n";
if (&get_current_value("recipient_bcc_maps") eq "")
{
    print $text{'no_map'},"<p>\n";
}
else
{
    &generate_map_edit("recipient_bcc_maps", $text{'map_click'}." ".
		       &hlink($text{'help_map_format'}, "virtual"));
}
print &ui_tabs_end_tab("mode", "recipient");

print &ui_tabs_end(1);

&ui_print_footer("", $text{'index_return'});
