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

print &ui_form_start("fsck.cgi");
print &ui_hidden("dev", $in{'dev'});
print &ui_hidden("type", $stat[1]);
print &ui_form_end([ [ undef, $text{'fsck_repair'} ] ]);

&ui_print_footer("", $text{'index_return'});

