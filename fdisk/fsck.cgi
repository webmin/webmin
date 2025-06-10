#!/usr/local/bin/perl
# fsck.cgi
# Where the fsck command actually gets run

require './fdisk-lib.pl';
&ReadParse();
&can_edit_disk($in{'dev'}) || &error($text{'fsck_ecannot'});
&ui_print_unbuffered_header(undef, $text{'fsck_title'}, "");

$cmd = &fsck_command($in{'type'}, $in{'dev'});
print "<b>",&text('fsck_exec', "<tt>$cmd</tt>"),"</b>\n";
print "<pre>\n";
&foreign_call("proc", "safe_process_exec_logged",
	      $cmd, 0, 0, STDOUT, undef, 1);
print "</pre>\n";
print "<b>... ",&fsck_error($?/256),"</b><p>\n"; 
&webmin_log("fsck", undef, $in{'dev'}, \%in);

&ui_print_footer("", $text{'index_return'});
