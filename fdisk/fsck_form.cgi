#!/usr/local/bin/perl
# fsck_form.cgi
# Ask questions before running fsck on a filesystem

require './fdisk-lib.pl';
&ReadParse();
&can_edit_disk($in{'dev'}) || &error($text{'fsck_ecannot'});
&ui_print_header(undef, $text{'fsck_title'}, "");

@stat = &device_status($in{dev});
print &text('fsck_desc1', &fstype_name($stat[1]), "<tt>$in{dev}</tt>",
	    "<tt>$stat[0]</tt>"),"<p>\n";
$cmd = &fsck_command($stat[1], $in{dev});
print &text('fsck_desc2', "<tt>$cmd</tt>", "<tt>fsck</tt>"),"<p>\n";

print "<form action=fsck.cgi>\n";
print "<input type=hidden name=cmd value=\"$cmd\">\n";
print "<input type=hidden name=dev value=\"$in{'dev'}\">\n";
print "<input type=hidden name=type value=\"$in{'type'}\">\n";
print "<center><input type=submit value=\"$text{'fsck_repair'}\"></center>\n";
print "</form>\n";

&ui_print_footer("", $text{'index_return'});

