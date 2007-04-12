#!/usr/local/bin/perl
# tunefs_form.cgi
# Display a form asking for filesystem tuning parameters

require './fdisk-lib.pl';
&can_edit_disk($in{'dev'}) || &error($text{'tunefs_ecannot'});
&ui_print_header(undef, $text{'tunefs_title'}, "");
&ReadParse();

print "<form action=tunefs.cgi>\n";
print "<input type=hidden name=dev value=\"$in{dev}\">\n";
print "<input type=hidden name=type value=\"$in{type}\">\n";

@stat = &device_status($in{dev});
print &text('tunefs_desc', &fstype_name($in{type}), "<tt>$in{dev}</tt>",
	    "<tt>$stat[1]</tt>"),"<p>\n";

print "<table border>\n";
print "<tr $tb><td><b>$text{'tunefs_params'}</b></td> </tr>\n";
print "<tr $cb><td><table cellpadding=5>\n";
&tunefs_options($in{type});
print "</table></td></tr></table><br>\n";

print "<input type=submit value=\"$text{'tunefs_tune'}\"></form>\n";

&ui_print_footer("", $text{'index_return'});

