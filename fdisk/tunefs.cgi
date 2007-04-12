#!/usr/local/bin/perl
# tunefs.cgi
# Do the tuning of a filesystem

require './fdisk-lib.pl';
&ReadParse();
&can_edit_disk($in{'dev'}) || &error($text{'tunefs_ecannot'});
&error_setup($text{'tunefs_err'});
$cmd = &tunefs_parse($in{type}, $in{dev});
&ui_print_unbuffered_header(undef, $text{'tunefs_title'}, "");

print "<b>",&text('tunefs_exec', "<tt>$cmd</tt>"),"</b>\n";
print "<pre>\n";
&foreign_call("proc", "safe_process_exec_logged",
	      $cmd, 0, 0, STDOUT, undef, 1);
print "</pre>\n";
if ($?) { print "<b>$text{'tunefs_failed'}</b><p>\n"; }
else { print "<b>$text{'tunefs_ok'}</b><p>\n"; }
&webmin_log("tunefs", undef, $in{'dev'}, \%in);

&ui_print_footer("", $text{'index_return'});
