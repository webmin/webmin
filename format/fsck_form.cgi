#!/usr/local/bin/perl
# fsck_form.cgi
# Display a form asking for fsck options

require './format-lib.pl';
$access{'view'} && &error($text{'ecannot'});
&ReadParse();
&can_edit_disk($in{'dev'}) || &error($text{'fsck_ecannot'});
&ui_print_header(undef, $text{'fsck_title'}, "");

$fs = &filesystem_type($in{'dev'});
print "<form action=fsck.cgi>\n";
print "<input type=hidden name=dev value=\"$in{dev}\">\n";
print &text('fsck_desc', &fstype_name($fs), "<tt>$in{'dev'}</tt>"),"<p>\n";

print "<input type=radio name=mode value=\"-m\">\n";
print "$text{'fsck_mode0'}<br>\n";

print "<input type=radio name=mode value=\"-n\">\n";
print "$text{'fsck_mode1'}<br>\n";

print "<input type=radio name=mode value=\"-y\" checked>\n";
print "$text{'fsck_mode2'}<br><p>\n";

print "<div align=center><input type=submit ",
      "value=\"$text{'fsck_repair'}\"></div>\n";
print "</form>\n";

&ui_print_footer("", $text{'index_return'});

