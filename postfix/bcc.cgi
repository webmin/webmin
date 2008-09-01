#!/usr/local/bin/perl

require './postfix-lib.pl';

$access{'bcc'} || &error($text{'bcc_ecannot'});
&ui_print_header(undef, $text{'bcc_title'}, "", "bcc");
&ReadParse();

# alias general options

print "<form action=save_opts_bcc.cgi>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'bcc_title'}</b></td></tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr>\n";
&option_mapfield("sender_bcc_maps", 60);
print "</tr>\n";
print "<tr>\n";
&option_mapfield("recipient_bcc_maps", 60);
print "</tr>\n";

print "</table></td></tr></table><p>\n";
print "<input type=submit value=\"$text{'opts_save'}\"></form>\n";
print "<p>\n";
print &ui_hr();

print &ui_tabs_start([ [ "sender", $text{'bcc_sender'} ],
		       [ "recipient", $text{'bcc_recipient'} ] ],
		     "mode", $in{'mode'} || 'sender', 1);

# Sender BCC maps
print &ui_tabs_start_tab("mode", "sender");
print $text{'bcc_senderdesc'},"<p>\n";
if (&get_current_value("sender_bcc_maps") eq "")
{
    print ($text{'no_map'}."<br><br>");
}
else
{
    &generate_map_edit("sender_bcc_maps", $text{'map_click'}." ".
		       "<font size=\"-1\">".&hlink("$text{'help_map_format'}", "virtual")."</font>\n<br>\n");
}
print &ui_tabs_end_tab("mode", "sender");

# Sender BCC maps
print &ui_tabs_start_tab("mode", "recipient");
print $text{'bcc_recipientdesc'},"<p>\n";
if (&get_current_value("recipient_bcc_maps") eq "")
{
    print ($text{'no_map'}."<br><br>");
}
else
{
    &generate_map_edit("recipient_bcc_maps", $text{'map_click'}." ".
		       "<font size=\"-1\">".&hlink("$text{'help_map_format'}", "virtual")."</font>\n<br>\n");
}
print &ui_tabs_end_tab("mode", "recipient");

print &ui_tabs_end(1);

&ui_print_footer("", $text{'index_return'});
