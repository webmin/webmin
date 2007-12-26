#!/usr/local/bin/perl

require './postfix-lib.pl';

$access{'bcc'} || &error($text{'bcc_ecannot'});
&ui_print_header(undef, $text{'bcc_title'}, "", "bcc");


# alias general options

print "<form action=save_opts_bcc.cgi>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'bcc_title'}</b></td></tr>\n";
print "<tr $cb> <td><table width=100%>\n";

$none = $text{'opts_none'};

print "<tr>\n";
&option_mapfield("sender_bcc_maps", 60, $none);
print "</tr>\n";

print "</table></td></tr></table><p>\n";
print "<input type=submit value=\"$text{'opts_save'}\"></form>\n";
print "<hr>\n";
print "<br>\n";


if (&get_current_value("sender_bcc_maps") eq "")
{
    print ($text{'no_map'}."<br><br>");
}
else
{
    &generate_map_edit("sender_bcc_maps", $text{'map_click'}." ".
		       "<font size=\"-1\">".&hlink("$text{'help_map_format'}", "virtual")."</font>\n<br>\n");
}

&ui_print_footer("", $text{'index_return'});
