#!/usr/local/bin/perl
# mkfs.cgi
# Where the new filesystem actually gets created.

require './fdisk-lib.pl';
&foreign_require("proc", "proc-lib.pl");

&ReadParse();
&can_edit_disk($in{'dev'}) || &error($text{'mkfs_ecannot'});
&error_setup($text{'mkfs_err'});
$cmd = &mkfs_parse($in{type}, $in{dev});

&ui_print_unbuffered_header(undef, $text{'mkfs_title'}, "");
$label = &get_label($in{'dev'});

print &text('mkfs_exec', "<tt>$cmd</tt>"),"<p>\n";
print "<pre>\n";
&foreign_call("proc", "safe_process_exec_logged",
	      $cmd, 0, 0, STDOUT, undef, 1, 1);
print "</pre>\n";

if ($?) { print "<b>$text{'mkfs_failed'}</b> <p>\n"; }
else { print "$text{'mkfs_ok'} <p>\n"; }
if ($label) {
	&set_label($in{'dev'}, $label, $in{'type'});
	}
&webmin_log("mkfs", undef, $in{'dev'}, \%in);

&ui_print_footer("", $text{'index_return'});
