#!/usr/local/bin/perl
# restore.cgi
# Restore a backup dump

require './fsdump-lib.pl';
&ReadParse();
&error_setup($text{'restore_err'});
$access{'restore'} || &error($text{'restore_ecannot'});

$cmd = &parse_restore($in{'fs'});

&ui_print_unbuffered_header(undef, $text{'restore_title'}, "");

&create_wrappers();

print "<b>",&text('restore_now', "<tt>$cmd</tt>"),"</b> <p>\n";
print "<pre>";
$rv = &restore_backup($in{'fs'}, $cmd);
print "</pre>\n";
if ($rv) {
	if ($rv =~ /^\d+$/) {
		# Bad exit status
		print "<b>$text{'restore_failed2'}</b><p>\n";
		}
	else {
		# Some error message
		print "<b>",&text('restore_failed', $rv),"</b><p>\n";
		}
	}
elsif (!$in{'test'}) {
	print "<b>$text{'restore_complete'}</b><p>\n";
	}
&webmin_log("restore", undef, $in{'mode'} == 0 ? $in{'file'} :
		      $in{'huser'} ? "$in{'huser'}@$in{'host'}:$in{'hfile'}" :
				     "$in{'huser'}:$in{'hfile'}");

&ui_print_footer("", $text{'index_return'});

