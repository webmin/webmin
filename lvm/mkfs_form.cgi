#!/usr/local/bin/perl
# mkfs_form.cgi
# Display a form for creating a filesystem on a logical volume

require './lvm-lib.pl';
&ReadParse();
&ui_print_header(undef, $text{'mkfs_title'}, "");
&foreign_require("fdisk", "fdisk-lib.pl");

print "<b>",&text('mkfs_desc', "<tt>$in{'fs'}</tt>",
	&foreign_call("fdisk", "fstype_name", $in{'fs'}),
	"<tt>$in{'dev'}</tt>"),"</b><br>\n";

print "<form action=mkfs.cgi>\n";
print "<input type=hidden name=dev value='$in{'dev'}'>\n";
print "<input type=hidden name=fs value='$in{'fs'}'>\n";
print "<table border width=100%>\n";
print "<tr $tb><td><b>$text{'mkfs_header'}</b></td> </tr>\n";
print "<tr $cb><td><table width=100%>\n";
&foreign_call("fdisk", "mkfs_options", $in{'fs'});
print "</table></td></tr></table>\n";
print "<input type=submit value='$text{'create'}'></form>\n";

&ui_print_footer("", $text{'index_return'});

