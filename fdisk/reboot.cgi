#!/usr/local/bin/perl
# reboot.cgi
# Reboot the system after changing partitions

require './fdisk-lib.pl';
&ui_print_header(undef, $text{'reboot_title'}, "");
print &ui_subheading($text{'reboot_msg'});
&ui_print_footer("", $text{'index_return'});
system("reboot");

