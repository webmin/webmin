#!/usr/local/bin/perl
# mkfs_form.cgi
# Display a form for creating a filesystem on a logical volume

require './lvm-lib.pl';
&ReadParse();
&ui_print_header(undef, $text{'mkfs_title'}, "");

print "<b>",&text('mkfs_desc', "<tt>$in{'fs'}</tt>",
	&fdisk::fstype_name($in{'fs'}),
	"<tt>$in{'dev'}</tt>"),"</b><br>\n";

print &ui_form_start("mkfs.cgi");
print &ui_hidden("dev", $in{'dev'});
print &ui_hidden("fs", $in{'fs'});
print &ui_hidden("lv", $in{'lv'});
print &ui_hidden("vg", $in{'vg'});
print &ui_table_start($text{'mkfs_header'}, undef, 4);
&fdisk::mkfs_options($in{'fs'});
print &ui_table_end();
print &ui_form_end([ [ undef, $text{'create'} ] ]);

&ui_print_footer("index.cgi?mode=lvs", $text{'index_return3'});

