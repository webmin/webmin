#!/usr/local/bin/perl
# Actually execute a backup

require './bacula-backup-lib.pl';
&ReadParse();
&error_setup($text{'mount_err'});

# Validate inputs
$in{'slot_def'} || $in{'slot'} =~ /^[1-9][0-9]*$/ ||
	&error($text{'mount_eslot'});

&ui_print_unbuffered_header(undef,  $text{'mount_title'}, "");
$mode = $in{'mount'} ? "mount" : "unmount";

print "<b>",&text($mode.'_run', "<tt>$in{'storage'}</tt>"),"</b>\n";
print "<pre>";
$h = &open_console();
&console_cmd($h, "messages");

# Run the command
$out = &console_cmd($h, "$mode storage=$in{'storage'}".
			($in{'slot_def'} ? "" : " slot=$in{'slot'}"));
print $out;

print "</pre>";
if ($out =~ /\sOK\s/i) {
	# Worked
	print "<b>",$text{$mode.'_done'},"</b><p>\n";
	}
else {
	# Something went wrong
	print "<b>",$text{$mode.'_failed'},"</b><p>\n";
	}

&close_console($h);
&webmin_log($mode, $in{'storage'});

&ui_print_footer("mount_form.cgi", $text{'mount_return'});


