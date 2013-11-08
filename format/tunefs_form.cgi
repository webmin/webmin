#!/usr/local/bin/perl
# tunefs_form.cgi
# Display a form for entering filesystem tuning options

require './format-lib.pl';
$access{'view'} && &error($text{'ecannot'});
&ReadParse();
&can_edit_disk($in{'dev'}) || &error($text{'tunefs_ecannot'});
&ui_print_header(undef, $text{'tunefs_title'}, "");

@stat = &device_status($in{dev});
$fs = &filesystem_type($in{dev});
print "<form action=tunefs.cgi>\n";
print "<input type=hidden name=dev value=\"$in{dev}\">\n";
print &text('tunefs_desc', &fstype_name($fs), "<tt>$in{'dev'}</tt>"),"<p>\n";

print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'tunefs_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";
&opt_input("tunefs_a", "", 1);
&opt_input("tunefs_d", "ms", 0);
&opt_input("tunefs_e", "", 1);
&opt_input("tunefs_m", "%", 0);
print "<tr> <td align=right><b>$text{'tunefs_opt'}</b></td>\n";
print "<td><select name=tunefs_o>\n";
print "<option value=''>$text{'default'}</option>\n";
print "<option value=space>$text{'tunefs_space'}</option>\n";
print "<option value=time>$text{'tunefs_time'}</option>\n";
print "</select></td>\n";
print "</table></td></tr></table><br>\n";

print "<div align=right>\n";
print "<input type=submit value=\"$text{'tunefs_tune'}\"></form>\n";
print "</div>\n";

&ui_print_footer("", $text{'index_return'});

