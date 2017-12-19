#!/usr/local/bin/perl
# reboot.cgi
# Reboot the system immediately..

require './init-lib.pl';
&ReadParse();
$access{'reboot'} || &error($text{'reboot_ecannot'});
&ui_print_header(undef, $text{'reboot_title'}, "");

$ttcmd = "<tt>".&html_escape($config{'reboot_command'})."</tt>";
if ($in{'confirm'}) {
	print &ui_subheading(&text('reboot_exec', $ttcmd));
	&reboot_system();
	&webmin_log("reboot");
	}
else {
	print &ui_confirmation_form(
		"reboot.cgi",
		&text('reboot_rusure', $ttcmd),
		undef,
		[ [ "confirm", $text{'reboot_ok'} ] ]);
	}
&ui_print_footer("", $text{'index_return'});

