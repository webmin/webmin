#!/usr/local/bin/perl
# newfs_form.cgi
# Display a form asking for the parameters of a new filesystem

require './fdisk-lib.pl';
&ReadParse();
&can_edit_disk($in{'dev'}) || &error($text{'mkfs_ecannot'});
&ui_print_header(undef, $text{'mkfs_title'}, "");

print &ui_form_start("mkfs.cgi");
print &ui_hidden("dev", $in{'dev'});
print &ui_hidden("type", $in{'type'});

print &text('mkfs_desc1', "<b>".&fstype_name($in{type})."</b>",
	    "<b><tt>$in{dev}</tt></b>"),"<p>\n";

if ((@stat = &device_status($in{dev})) && $stat[1] ne "swap") {
	print &text('mkfs_desc2', "<tt>$stat[0]</tt>",
		    &fstype_name($in{type})),"<p>\n";
	}

print &ui_table_start($text{'mkfs_options'}, undef, 4);
&mkfs_options($in{type});
print &ui_table_end();
print &ui_form_end([ [ undef, $text{'mkfs_create'} ] ]);

&ui_print_footer("", $text{'index_return'});

