#!/usr/local/bin/perl
# reboot.cgi
# Reboot the system immediately..

require './init-lib.pl';
&ReadParse();
$access{'reboot'} || &error($text{'reboot_ecannot'});
&ui_print_header(undef, $text{'reboot_title'}, "");
print "<p>\n";
$ttcmd = "<tt>$config{'reboot_command'}</tt>";
if ($in{'confirm'}) {
	print "<font size=+1>",&text('reboot_exec', $ttcmd),"</font><p>\n";
	&reboot_system();
	&webmin_log("reboot");
	}
else {
	print "<font size=+1>",&text('reboot_rusure', $ttcmd),"</font>\n";
	print "<center><form action=reboot.cgi>\n";
	print "<input type=submit value=\"$text{'reboot_ok'}\" name=confirm>\n";
	print "</form></center>\n";
	}
&ui_print_footer("", $text{'index_return'});

