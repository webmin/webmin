#!/usr/local/bin/perl
# newfs_form.cgi
# Display a form asking for the parameters of a new filesystem

require './fdisk-lib.pl';
&ReadParse();
&can_edit_disk($in{'dev'}) || &error($text{'mkfs_ecannot'});
&ui_print_header(undef, $text{'mkfs_title'}, "");

print "<form action=mkfs.cgi>\n";
print "<input type=hidden name=dev value=\"$in{dev}\">\n";
print "<input type=hidden name=type value=\"$in{type}\">\n";

print &text('mkfs_desc1', "<b>".&fstype_name($in{type})."</b>",
	    "<b><tt>$in{dev}</tt></b>"),"<p>\n";

if ((@stat = &device_status($in{dev})) && $stat[1] ne "swap") {
	print &text('mkfs_desc2', "<tt>$stat[0]</tt>",
		    &fstype_name($in{type})),"<p>\n";
	}

print "<table border>\n";
print "<tr $tb><td><b>$text{'mkfs_options'}</b></td> </tr>\n";
print "<tr $cb><td><table cellpadding=5>\n";
&mkfs_options($in{type});
print "</table></td></tr></table>\n";

print "<input type=submit value=\"$text{'mkfs_create'}\"></form>\n";

&ui_print_footer("", $text{'index_return'});

