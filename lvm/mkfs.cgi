#!/usr/local/bin/perl
# mkfs.cgi
# Create a new filesystem on a logical volume

require './lvm-lib.pl';
&foreign_require("proc");

&ReadParse();
&error_setup($text{'mkfs_err'});
$cmd = &fdisk::mkfs_parse($in{'fs'}, $in{'dev'});

&ui_print_unbuffered_header(undef, $text{'mkfs_title'}, "");
print &text('mkfs_exec', "<tt>$cmd</tt>"),"<p>\n";
print "<pre>\n";
&proc::safe_process_exec_logged($cmd, 0, 0, STDOUT, undef, 1);
print "</pre>\n";

if ($?) { print "<b>$text{'mkfs_failed'}</b> <p>\n"; }
else { print "$text{'mkfs_ok'} <p>\n"; }
$config{'lasttype_'.$in{'dev'}} = $in{'fs'};
&save_module_config();
&webmin_log("mkfs", "lv", $in{'dev'}, \%in);

&ui_print_footer("index.cgi?mode=lvs", $text{'index_return3'},
		 "edit_lv.cgi?vg=$in{'vg'}&lv=$in{'lv'}", $text{'lv_return'});

